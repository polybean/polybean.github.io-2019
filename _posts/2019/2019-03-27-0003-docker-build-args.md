---
title: "0003 - [构建Docker镜像]使用构建参数（Build Args）去除镜像构建过程中的硬编码"
tags: ["Docker", "Spring Boot"]
album: 构建Docker镜像
---

在[上一篇文章中](/2019/03/26/0002-improve-naive-dockerfile.html)，通过使用构建容器，提升了镜像构建的速度，并有效的缩减了镜像的大小。但是构建过程中使用的脚本存在硬编码的情况。比如在`build-images.sh`中，镜像的构建命令：

```bash
docker build $base -t demo:0.0.1-SNAPSHOT
```

镜像的名字（`demo`）和镜像的版本（`0.0.1-SNAPSHOT`）都是硬编码。另外，在`Dockerfile`中 jar 包的名字也存在硬编码的情况：

```dockerfile
FROM openjdk:8u191-jre-alpine3.9
WORKDIR /app
COPY target/demo-0.0.1-SNAPSHOT.jar /app/
CMD java -jar demo-0.0.1-SNAPSHOT.jar
```

今天我们的目标就是去除所有这些硬编码，从而得到**适用于任何一个 Spring Boot 工程的 Docker 镜像构建工具**。

<!--more-->

本文对应的示例代码可以在[集豆示例代码仓库](https://github.com/polybean/polybean)的`0003-docker-build-args`目录中找到。

本文介绍的去除硬编码的方案基于：

1. [Maven Help Plugin](http://maven.apache.org/plugins/maven-help-plugin/)：提供了在命令行获取 maven 工程名和版本的能力
2. `docker build`命令的`--build-args`参数：提供了从`docker build`命令行向`Dockerfile`传递参数的能力

按照[Maven Help Plugin 官方文档](http://maven.apache.org/plugins/maven-help-plugin/plugin-info.html)的指引，在 Spring Boot 工程的`pom.xml`中添加`maven-help-plugin`作为构建插件依赖：

```xml
<project>
  ...
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-help-plugin</artifactId>
        <version>3.1.1</version>
      </plugin>
      ...
    </plugins>
  </build>
  ...
</project>
```

刷新工程，即可看到 Maven Help Plugin 提供的若干`help`命令：

![maven-help-plugin](/assets/images/0003/maven-help-plugin.png)

获取工程名的命令为：

```bash
# path = 0003-docker-build-args/demo
$ ./mvnw help:evaluate -Dexpression=project.name -q -DforceStdout
```

获取工程版本号的命令为：

```bash
# path = 0003-docker-build-args/demo
$ ./mvnw help:evaluate -Dexpression=project.version -q -DforceStdout
```

运行结果如下：

![project-name-and-version](/assets/images/0003/project-name-and-version.png)

把这一成果集成到`build-images.sh`中：

```bash
#!/bin/bash

set -e

base=$(realpath "$(dirname -- $0)/..")
name=$($base/mvnw help:evaluate -Dexpression=project.name -q -DforceStdout)
version=$($base/mvnw help:evaluate -Dexpression=project.version -q -DforceStdout)

docker run --rm \
  -v $HOME/.m2:/root/.m2:rw \
  -v $base:/app:rw \
  -w "/app" \
  openjdk:8u191-jdk-alpine3.9 \
  sh -c "./mvnw clean package"

docker build $base -t $name:$version --build-arg jar_file=$name-$version.jar
```

需要注意的是`docker build`命令的`--build-arg`参数，我们定义了名为`jar_file`的镜像构建参数，从而可以在`Dockerfile`中对其进行引用：

```dockerfile
FROM openjdk:8u191-jre-alpine3.9
ARG jar_file
WORKDIR /app
COPY target/$jar_file /app/
ENV jar_file=$jar_file
CMD java -jar $jar_file
```

特别需要指出的是`ENV`指令的重要性，如果省去`ENV`指令，将`Dockerfile`简化为：

```dockerfile
FROM openjdk:8u191-jre-alpine3.9
ARG jar_file
WORKDIR /app
COPY target/$jar_file /app/
CMD java -jar $jar_file
```

将无法成功启动该镜像的容器。原因详见[理解 Docker 镜像的构建过程](#)。

同样的，可以将`start-service.sh`更新为：

```bash
#!/bin/bash

set -e

base=$(realpath "$(dirname -- $0)/..")
name=$($base/mvnw help:evaluate -Dexpression=project.name -q -DforceStdout)
version=$($base/mvnw help:evaluate -Dexpression=project.version -q -DforceStdout)

docker run \
  -d \
  --rm \
  -p 8080:8080 \
  $name:$version
```

至此，我们成功地去除了构建镜像与启动服务过程中存在的硬编码。依次执行以下命令验证`demo`服务可以正常运行：

```bash
# path = 0002-improve-naive-dockerfile/demo
$ ./scripts/build-image.sh
$ ./scripts/start-service.sh
$ curl localhost:8080
```

目标达成。
