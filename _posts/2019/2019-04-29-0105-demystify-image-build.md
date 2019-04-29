---
title: "0105 - [构建Docker镜像]揭秘Docker镜像构建过程"
tags: ["Docker"]
album: 构建Docker镜像
---

当执行`docker build`命令后，总觉得发生了一些不可描述的事情。本文将尝试描述这些“不可描述的事情”，揭秘 Docker 镜像构建的过程。

首先给出结论：**Docker 引擎会针对 Dockerfile 中的每个指令生成一个镜像层，每个镜像层对应 Union Filesystem （联合文件系统）中的零个或一个文件层，其中某些文件层的生成是通过运行容器执行构建指令完成的。Docker 将这些镜像层串接起来，形成最终的镜像。**

本文的实验环境：

1. 新装 Linux 系统（DigitalOcean Ubuntu 18.04）
2. 新装 Docker，未拉取任何 Docker Hub 中的镜像，未构建任何本地镜像
3. 使用[编写第一份 Dockerfile](/2019/03/25/naive-dockerfile)的`Dockerfile`

我们首先来验证“其中某些层次的生成是通过运行容器，执行构建指令来完成的”。在命令行输入以下命令，监控是否 Docker 容器运行（每 0.5 秒刷新`docker container ls`命令的输出）：

```bash
$ watch -n 0.5 docker container ls
```

执行镜像构建命令：

```bash
$ docker build . -t demo:0.0.1-SNAPSHOT
```

同时注意观察 watch 命令的输出。间隔 0.5 秒会遗漏一些容器的运行，但是可以捕获到执行`./mvnw clean package`命令的容器：

![](/assets/images/2019/0105/captured-container.png)

我们也可以从`docker build`命令的输出中证实这一点：

```
Sending build context to Docker daemon  88.58kB
Step 1/8 : FROM openjdk:8u191-jdk-alpine3.9
8u191-jdk-alpine3.9: Pulling from library/openjdk
8e402f1a9c57: Pull complete
4866c822999c: Pull complete
a5e04b7d13ab: Pull complete
Digest: sha256:d2e2716147d1f7fe73b1a9f72a9cff7a7aa92d32eb8de4fffbfddc596e004984
Status: Downloaded newer image for openjdk:8u191-jdk-alpine3.9
 ---> e9ea51023687
Step 2/8 : WORKDIR /app
 ---> Running in fdf049b8b89e
Removing intermediate container fdf049b8b89e
 ---> da73e91d318e
Step 3/8 : COPY .mvn/ .mvn/
 ---> daa219334810
Step 4/8 : COPY src/ src/
 ---> a49046a4cae2
Step 5/8 : COPY mvnw .
 ---> 7efba7f7ba43
Step 6/8 : COPY pom.xml .
 ---> 563054cc2e77
Step 7/8 : RUN ./mvnw -q clean package
 ---> Running in 2f81af692681
...
Removing intermediate container 2f81af692681
 ---> 0e59400ea086
Step 8/8 : CMD java -jar target/demo-0.0.1-SNAPSHOT.jar
 ---> Running in 2549b267776c
Removing intermediate container 2549b267776c
 ---> f449633eddfd
Successfully built f449633eddfd
Successfully tagged demo:0.0.1-SNAPSHOT
```

<!--more-->

注意日志中的`Removing intermediate container ...`字样，从中可以看到有三个文件层的生成是运行容器的结果，而我们所捕获的是其中的一个（容器 ID 为 2f81af692681）。

需要运行容器的原因是：该文件层的改动必须要通过运行 bash 命令来完成，如：

- `Step 2/8 : WORKDIR /app`：构建过程执行到该指令时，如果当前的文件系统中并不存在`/app`目录，就需要运行 bash 命令创建`/app`目录
- `Step 7/8 : RUN ./mvnw clean package`：`RUN`指令一定通过运行 bash 命令来完成
- `Step 8/8 : CMD java -jar target/demo-0.0.1-SNAPSHOT.jar`：有可能需要运行 bash 命令

而不需要通过运行容器生成的镜像层大都因为，生成该层的内容是来自于系统或构建上下文（Build Context）的静态物料，如：

- `Step 1/8 : FROM openjdk:8u191-jdk-alpine3.9`：基础镜像`openjdk:8u191-jdk-alpine3.9`已经位于 DOCKER_ROOT（`/var/lib/docker`）中
- `Step 3/8 : COPY .mvn/ .mvn/`：`.mvn`目录是构建上下文中的静态物料，不需要通过运行 bash 命令生成
- `Step 4/8 : COPY src/ src/`：`src`目录是构建上下文中的静态物料，不需要通过运行 bash 命令生成
- `Step 5/8 : COPY mvnw .`：`mvnw`目录是构建上下文中的静态物料，不需要通过运行 bash 命令生成
- `Step 6/8 : COPY pom.xml .`：`pom.xml`文件是构建上下文中的静态物料，不需要通过运行 bash 命令生成

再来理解“Dockerfile 中的每个指令生成一个镜像层，每个镜像层对应 Union Filesystem （联合文件系统）中的零个或一个文件层”，并尝试找到每一个文件层的内容。

我们先通过运行`docker image history`命令，得到这些**镜像层**：

```bash
$ docker image history demo:0.0.1-SNAPSHOT
```

![](/assets/images/2019/0105/image-history.png)

在`IMAGE`一列，打印了这些**镜像层**的 ID，可以在`/var/lib/docker/image/overlay2/imagedb/content/sha256`中找到它们：

![](/assets/images/2019/0105/image-layers.png)

每一个文件都是 JSON 文件，我们可以通过`jq`更容器的阅读每一个**镜像层**的内容。以`f449633eddfd10ddd34d18a8bdd51986692907da0b7de0d4cc0954ed5a11062b`为例：

```bash
$ cat f449633eddfd10ddd34d18a8bdd51986692907da0b7de0d4cc0954ed5a11062b | jq
```

注意镜像信息中的`rootfs`信息：

![](/assets/images/2019/0105/layer-rootfs.png)

`diff_ids`数组中的每个元素对应一个文件层的 ID，如果我们按照镜像层的创建顺序，罗列每一个镜像层对应的`diff_ids`数组内容：

```
1/8 e9ea51023687 => "diff_ids": [
  "sha256:bcf2f368fe234217249e00ad9d762d8f1a3156d60c442ed92079fa5b120634a1",
  "sha256:344fb4b275b72fa2f835af4a315fa3c10e6b14086126adc01471eaa57659f7a5",
  "sha256:714e1dd7c2e4561ac781f38261a4985a3e6e9f5aa84b8b1640d73510d1471e61"
]

2/8 da73e91d318e => "diff_ids": [
  "sha256:bcf2f368fe234217249e00ad9d762d8f1a3156d60c442ed92079fa5b120634a1",
  "sha256:344fb4b275b72fa2f835af4a315fa3c10e6b14086126adc01471eaa57659f7a5",
  "sha256:714e1dd7c2e4561ac781f38261a4985a3e6e9f5aa84b8b1640d73510d1471e61",
  "sha256:73cc4ca70569729881723b51827482252d3de2455246e9718916dbf34cdc3396"
]

3/8 daa219334810 => "diff_ids": [
  "sha256:bcf2f368fe234217249e00ad9d762d8f1a3156d60c442ed92079fa5b120634a1",
  "sha256:344fb4b275b72fa2f835af4a315fa3c10e6b14086126adc01471eaa57659f7a5",
  "sha256:714e1dd7c2e4561ac781f38261a4985a3e6e9f5aa84b8b1640d73510d1471e61",
  "sha256:73cc4ca70569729881723b51827482252d3de2455246e9718916dbf34cdc3396",
  "sha256:405d01f12bf51905578b983aa838c9facaa7ced43f83bea8db62dcd176879137"
]

4/8 a49046a4cae2 => "diff_ids": [
  "sha256:bcf2f368fe234217249e00ad9d762d8f1a3156d60c442ed92079fa5b120634a1",
  "sha256:344fb4b275b72fa2f835af4a315fa3c10e6b14086126adc01471eaa57659f7a5",
  "sha256:714e1dd7c2e4561ac781f38261a4985a3e6e9f5aa84b8b1640d73510d1471e61",
  "sha256:73cc4ca70569729881723b51827482252d3de2455246e9718916dbf34cdc3396",
  "sha256:405d01f12bf51905578b983aa838c9facaa7ced43f83bea8db62dcd176879137",
  "sha256:998e5e84fd28dce52dcd235f740e25ce6163f48b45c0d051c967d0eaaab0528b"
]

5/8 7efba7f7ba43 => "diff_ids": [
  "sha256:bcf2f368fe234217249e00ad9d762d8f1a3156d60c442ed92079fa5b120634a1",
  "sha256:344fb4b275b72fa2f835af4a315fa3c10e6b14086126adc01471eaa57659f7a5",
  "sha256:714e1dd7c2e4561ac781f38261a4985a3e6e9f5aa84b8b1640d73510d1471e61",
  "sha256:73cc4ca70569729881723b51827482252d3de2455246e9718916dbf34cdc3396",
  "sha256:405d01f12bf51905578b983aa838c9facaa7ced43f83bea8db62dcd176879137",
  "sha256:998e5e84fd28dce52dcd235f740e25ce6163f48b45c0d051c967d0eaaab0528b",
  "sha256:dd20c4e9ce424aa164db0b29b72ab921d45c9775eaa6e06bf98997ce9e1090ae"
]

6/8 563054cc2e77 => "diff_ids": [
  "sha256:bcf2f368fe234217249e00ad9d762d8f1a3156d60c442ed92079fa5b120634a1",
  "sha256:344fb4b275b72fa2f835af4a315fa3c10e6b14086126adc01471eaa57659f7a5",
  "sha256:714e1dd7c2e4561ac781f38261a4985a3e6e9f5aa84b8b1640d73510d1471e61",
  "sha256:73cc4ca70569729881723b51827482252d3de2455246e9718916dbf34cdc3396",
  "sha256:405d01f12bf51905578b983aa838c9facaa7ced43f83bea8db62dcd176879137",
  "sha256:998e5e84fd28dce52dcd235f740e25ce6163f48b45c0d051c967d0eaaab0528b",
  "sha256:dd20c4e9ce424aa164db0b29b72ab921d45c9775eaa6e06bf98997ce9e1090ae",
  "sha256:af3923323b3ffaf1cd4e127a319e5ea65bc949cb6d7191e777c6186194a83637"
]

7/8 0e59400ea086 => "diff_ids": [
  "sha256:bcf2f368fe234217249e00ad9d762d8f1a3156d60c442ed92079fa5b120634a1",
  "sha256:344fb4b275b72fa2f835af4a315fa3c10e6b14086126adc01471eaa57659f7a5",
  "sha256:714e1dd7c2e4561ac781f38261a4985a3e6e9f5aa84b8b1640d73510d1471e61",
  "sha256:73cc4ca70569729881723b51827482252d3de2455246e9718916dbf34cdc3396",
  "sha256:405d01f12bf51905578b983aa838c9facaa7ced43f83bea8db62dcd176879137",
  "sha256:998e5e84fd28dce52dcd235f740e25ce6163f48b45c0d051c967d0eaaab0528b",
  "sha256:dd20c4e9ce424aa164db0b29b72ab921d45c9775eaa6e06bf98997ce9e1090ae",
  "sha256:af3923323b3ffaf1cd4e127a319e5ea65bc949cb6d7191e777c6186194a83637",
  "sha256:6ec1e5b978e373d98abe62ebffef2789584e906f1b1f565db688d782f092f382"
]

8/8 f449633eddfd => "diff_ids": [
  "sha256:bcf2f368fe234217249e00ad9d762d8f1a3156d60c442ed92079fa5b120634a1",
  "sha256:344fb4b275b72fa2f835af4a315fa3c10e6b14086126adc01471eaa57659f7a5",
  "sha256:714e1dd7c2e4561ac781f38261a4985a3e6e9f5aa84b8b1640d73510d1471e61",
  "sha256:73cc4ca70569729881723b51827482252d3de2455246e9718916dbf34cdc3396",
  "sha256:405d01f12bf51905578b983aa838c9facaa7ced43f83bea8db62dcd176879137",
  "sha256:998e5e84fd28dce52dcd235f740e25ce6163f48b45c0d051c967d0eaaab0528b",
  "sha256:dd20c4e9ce424aa164db0b29b72ab921d45c9775eaa6e06bf98997ce9e1090ae",
  "sha256:af3923323b3ffaf1cd4e127a319e5ea65bc949cb6d7191e777c6186194a83637",
  "sha256:6ec1e5b978e373d98abe62ebffef2789584e906f1b1f565db688d782f092f382"
]
```

我们发现除第 8 个**镜像层**`f449633eddfd`之外，其他每一个**镜像层**的创建都对应一个**文件层**的创建，而这个新创建的**文件层**就是当前**镜像层**对应的**文件层**，是`diff_ids`数组中的最后一个元素。

对于第 8 个镜像层，我们检查它的镜像内容就会发现`history`信息中已经指明了该镜像层不会创建文件层（`empty_layer: true`）：

```json
{
  ...
  "history": [
    {
      "created": "2019-04-29T10:03:45.517525756Z",
      "created_by": "/bin/sh -c #(nop)  CMD [\"/bin/sh\" \"-c\" \"java -jar target/demo-0.0.1-SNAPSHOT.jar\"]",
      "empty_layer": true
    }
  ]
  ...
}
```

`/var/lib/docker/image/overlay2/layerdb/sha256`目录中存放了这些文件层的元数据，需要注意的是：`/var/lib/docker/image/overlay2/layerdb/sha256`目录下的每个子目录是对应文件层的摘要值，与镜像`diff_ids`数组中对应的文件层 ID 存放于`/var/lib/docker/image/overlay2/layerdb/sha256/XXX/diff`文件中。

![](/assets/images/2019/0105/fs-layers.png)

如果我们要找到`diff_id`为`6ec1e5b978e373d98abe62ebffef2789584e906f1b1f565db688d782f092f382`的文件层，就要找到摘要值 XXX——`/var/lib/docker/image/overlay2/layerdb/sha256/XXX/diff`文件内容为`6ec1e5b978e373d98abe62ebffef2789584e906f1b1f565db688d782f092f382`，XXX=`ac57411a1b9dd2729d7aae5faf6a7e881868ede9ab8ca00df7d4c3e7eee73249`

```bash
$ root@vm14:/var/lib/docker/image/overlay2/layerdb/sha256# cat ac57411a1b9dd2729d7aae5faf6a7e881868ede9ab8ca00df7d4c3e7eee73249/diff
sha256:6ec1e5b978e373d98abe62ebffef2789584e906f1b1f565db688d782f092f382
```

找到该文件层后，可查看该层的`cache_id`文件

```bash
$ root@vm14:/var/lib/docker/image/overlay2/layerdb/sha256# cat ac57411a1b9dd2729d7aae5faf6a7e881868ede9ab8ca00df7d4c3e7eee73249/cache-id
1ef7aa5d6358bc31743f02a3dc0e1b411c3d67a893660a48b914d935404f0979
```

`1ef7...`就是揭开文件层面纱的钥匙，它是一个索引，指向了文件层内容存储区域`/var/lib/docker/overlay2`。

![](/assets/images/2019/0105/overlay-content.png)

```bash
root@vm14:/var/lib/docker/overlay2# tree 1ef7aa5d6358bc31743f02a3dc0e1b411c3d67a893660a48b914d935404f0979/
1ef7aa5d6358bc31743f02a3dc0e1b411c3d67a893660a48b914d935404f0979/
├── diff
│   ├── app
│   │   └── target
│   │       ├── classes
│   │       │   ├── application.properties
│   │       │   └── com
│   │       │       └── example
│   │       │           └── demo
│   │       │               ├── DemoApplication.class
│   │       │               └── HomeController.class
│   │       ├── demo-0.0.1-SNAPSHOT.jar
│   │       ├── demo-0.0.1-SNAPSHOT.jar.original
│   │       ├── generated-sources
│   │       │   └── annotations
│   │       ├── generated-test-sources
│   │       │   └── test-annotations
│   │       ├── maven-archiver
│   │       │   └── pom.properties
│   │       ├── maven-status
│   │       │   └── maven-compiler-plugin
│   │       │       ├── compile
│   │       │       │   └── default-compile
│   │       │       │       ├── createdFiles.lst
│   │       │       │       └── inputFiles.lst
│   │       │       └── testCompile
│   │       │           └── default-testCompile
│   │       │               ├── createdFiles.lst
│   │       │               └── inputFiles.lst
│   │       ├── surefire-reports
│   │       │   ├── 2019-04-29T10-02-51_785-jvmRun1.dump
│   │       │   ├── com.example.demo.DemoApplicationTests.txt
│   │       │   └── TEST-com.example.demo.DemoApplicationTests.xml
│   │       └── test-classes
│   │           └── com
│   │               └── example
│   │                   └── demo
│   │                       └── DemoApplicationTests.class
│   ├── root
│   └── tmp
│       ├── hsperfdata_root
│       └── nio-file-upload
├── link
├── lower
└── work
```

终于看到了这一文件层的庐山真面目。

最后我们来理解“Docker 将这些镜像层串接起来，形成最终的镜像”。镜像层串接的依据在`/var/lib/docker/image/overlay2/imagedb/metadata/sha256`目录中：

![](/assets/images/2019/0105/layer-parent.png)

每一个镜像层的`parent`都指向它所基于的镜像层。

总结：

为了找到文件层的内容：

- `docker image ls`找到目标镜像
- `docker image history <image>` 找到该镜像的各个镜像层的 ImageID
- `$DOCKER_ROOT/image/overlay2/imagedb/metadata/sha256/<ImageID>`检查`parent`文件了各个解镜像层之间的串接关系）
- `$DOCKER_ROOT/image/overlay2/imagedb/content/sha256/<ImageID>`是一个 JSON，`rootfs.diff_ids`数组揭示了该镜像层对应的文件层
- `$DOCKER_ROOT/image/overlay2/layerdb/sha256/XXX/diff`文件的内容与镜像层`rootfs.diff_ids`数组相对应
- `$DOCKER_ROOT/image/overlay2/layerdb/sha256/XXX/cache_id`是打开文件层存储区域的索引
- `$DOCKER_ROOT/overlay2/<CACHE-ID>/diff`存放了对应文件层的真实内容
