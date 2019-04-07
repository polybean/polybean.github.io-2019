---
title: "0002 - [构建Docker镜像]改进第一份Dockerfile"
tags: ["Docker", "Spring Boot"]
album: 构建Docker镜像
---

在[第一份 Dockerfile](/2019/03/25/0001-naive-dockerfile.html)的基础上，我们对这个用 Spring Boot 编写的`demo`工程的镜像构建过程进行改进。

目标：

1. 利用 Maven 本地仓库，加速镜像构建
2. 镜像瘦身

本文对应的示例代码可以在[集豆示例代码仓库](https://github.com/polybean/polybean)的`0002-improve-naive-dockerfile`目录中找到。

<!--more-->

实际情况中，我们经常会对源代码进行改动，重新构建镜像。比如，如果我们将访问 `demo` 服务首页的问候语从`Hello World!`改为`Goodbye World!`：

```java
@RestController
@RequestMapping
public class HomeController {
    @GetMapping
    public ResponseEntity<Mono<String>> index() {
        return ResponseEntity.ok(Mono.just("Goodbye World!"));
    }
}
```

再次构建镜像时，我们会发现`demo`工程的所有依赖包都被重新下载了一遍。如果每次修改代码构建镜像，都要重复这样耗时的过程，无疑是不能令人接受的。

`demo`工程的所有依赖包很可能在我们使用 IDE（如 IntelliJ IDEA）进行开发时，已经被下载到我们的本地 Maven 仓库（默认路径为`$HOME/.m2/repository`），在构建镜像时如果能复用这些已经下载的依赖包，将极大的加快镜像构建的速度。

制作一个由 Spring Boot 服务的镜像，本质是将`mvnw clean package`生成的 jar 包（位于工程目录的`target`目录）置于镜像中，并指定镜像的启动命令（`java -jar target/demo-0.0.1-SNAPSHOT.jar`）。

构建工程得到 jar 的过程可以通过运行一个容器（称其为构建容器）的方式获得：

```bash
# path = 0002-improve-naive-dockerfile/demo
$ docker run --rm \
  -v $HOME/.m2:/root/.m2:rw \
  -v $PWD:/app:rw \
  -w "/app" \
  openjdk:8u191-jdk-alpine3.9 \
  sh -c "./mvnw clean package"
```

下图展示了通过构建容器构建`demo`服务的过程：

![build-container](/assets/images/2019/0002/build-container.png)

在获得通过构建容器构建好的 jar 包之后，通过这份更新后的`Dockerfile`构建镜像：

```dockerfile
FROM openjdk:8u191-jre-alpine3.9
WORKDIR /app
COPY target/demo-0.0.1-SNAPSHOT.jar /app/
CMD java -jar demo-0.0.1-SNAPSHOT.jar
```

需要注意的是，由于已经无需在该镜像构建过程中生成`demo`服务的 jar 包，可以将基线镜像由 JDK（`openjdk:8u191-jdk-alpine3.9`）替换为 JRE（`openjdk:8u191-jre-alpine3.9`）。

运行镜像构建命令：

```bash
# path = 0002-improve-naive-dockerfile/demo
$ docker build . -t demo:0.0.1-SNAPSHOT
```

由于使用 Maven 本地镜像的缘故，构建速度得到极大提升；而且因为使用了构建镜像，`demo`服务的依赖包并不存在于镜像中，`demo`服务的镜像大小由 191MB，降至 103MB。

![shrinked-image-size](/assets/images/2019/0002/shrinked-image-size.png)

最终，我们将构建过程整合成一个 Bash 脚本`build-images.sh`：

```bash
#!/bin/bash

set -e

base=$(realpath "$(dirname -- $0)/..")
echo $base
docker run --rm \
  -v $HOME/.m2:/root/.m2:rw \
  -v $base:/app:rw \
  -w "/app" \
  openjdk:8u191-jdk-alpine3.9 \
  sh -c "$base/mvnw clean package"

docker build $base -t demo:0.0.1-SNAPSHOT
```

我们也可以将启动`demo`服务的操作进行脚本化。创建`start-service.sh`：

```bash
#!/bin/bash

docker run \
  -d \
  --rm \
  -p 8080:8080 \
  demo:0.0.1-SNAPSHOT
```

依次运行以下命令进行简单测试：

```bash
# path = 0002-improve-naive-dockerfile/demo
$ ./scripts/build-image.sh
$ ./scripts/start-service.sh
$ curl localhost:8080
```

`demo`服务正常运行。至此，更新后的镜像构建过程运行更加高效，生成的镜像更为精简。目标达成。
