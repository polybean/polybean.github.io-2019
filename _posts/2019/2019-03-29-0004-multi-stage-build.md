---
title: "0004 - [构建Docker镜像]使用 multi-stage 构建Docker镜像"
tags: ["Docker", "Spring Boot"]
album: 构建Docker镜像
---

在[“改进第一份 Dockerfile”](/2019/03/26/0002-improve-naive-dockerfile.html)这篇文章中，我们使用了构建容器，构建`demo`工程的 jar 包，分阶段的完成了`demo`服务的镜像制作，有效的降低了镜像的大小。

也许有人会质疑，为什么需要构建容器，完全可以在不启动构建容器的情况下，在主机用使用命令：

```bash
$ ./mvnw clean package
```

完成 jar 包的构建，再使用命令

```bash
$ docker build . -t demo:0.0.1-SNAPSHOT
```

同样可以完成`demo`服务的镜像制作。

<!--more-->

确实可以这样做。不过在我看来，使用构建容器的好处在于：

1. 将所用命令行操作汇集到一个脚本中`build-image.sh`，一个命令即可完成镜像构建，而不需要分步执行多条命令（如果我们考虑到需要去除镜像名和版本的硬编码，至少需要分步执行 4 条命令）；
2. 用于发布的镜像构建，一般在 CI/CD（Continuous Integration/Continuous Delivery，持续集成/持续交付）服务器上完成，不同的服务可能需要依赖不同的 Java 版本（Java 8/9/10/11/12），如果在 CI/CD 服务器构建镜像时根据镜像使用的 Java 版本进行 JDK 环境的切换，将会带来额外的复杂度。使用构建镜像，我们只需要指定构建镜像基于的 JDK 版本，而不必对 CI/CD 主机的 JDK 环境进行任何变更——事实上 CI/CD 服务器甚至都可以不必安装 JDK/JRE。

使用`docker run`命令运行的构建镜像所完成的分阶段镜像构建功能，也可以使用 Docker 17.05 版本支持的 multi-stage 构建功能完成。使用 multi-stage 构建，可以免除我们编写额外脚本运行构建镜像的工作，而把分阶段镜像构建的过程包含在一份`Dockerfile`中。

这份文件包含多阶段构建步骤的`Dockerfile`是：

```dockerfile
# 第一阶段，执行原先由构建容器完成的工作——构建 demo 服务的 jar 包
FROM openjdk:8u191-jdk-alpine3.9 as builder
WORKDIR /builder
COPY . /builder
RUN ./mvnw clean package

# 第二阶段，包含第一阶段构建的 jar 包，并指定镜像的启动为容器时执行的命令
FROM openjdk:8u191-jre-alpine3.9
ARG jar_file
WORKDIR /app
COPY --from=builder /builder/target/$jar_file /app/
ENV jar_file=$jar_file
CMD java -jar $jar_file
```

第二阶段使用的 jar 包，由从当前工程目录的`taret`子目录获取变为从第一阶段的构建输出获得，这就是`COPY`指令`--from`参数的作用

```dockerfile
COPY --from=builder /builder/target/$jar_file /app/
```

在去除构建容器后，可以将`build-image.sh`脚本简化为：

```bash
#!/bin/bash

set -e

base=$(realpath "$(dirname -- $0)/..")
name=$($base/mvnw help:evaluate -Dexpression=project.name -q -DforceStdout)
version=$($base/mvnw help:evaluate -Dexpression=project.version -q -DforceStdout)
DOCKER_BUILDKIT=1 docker build $base -t $name:$version --build-arg jar_file=$name-$version.jar
```

尝试调用`build-image.sh`命令，可以正常完成`demo`镜像的构建，但是功能出现了回退，构建镜像时将再次下载这个 Spring Boot 工程的完整依赖——这是我们使用构建容器时极力避免的情况。如果我们希望保留 multi-stage 构建的特性（整合的`Dockerfile`），并且解决镜像构建因为需要下载完整依赖包而导致的镜像构建速度过慢的问题，我们需要更新 Docker Engine 至 18.09 版本，并使用该版本的提供的 buildkit 组件。Buildkit 允许我们指定镜像构建时可以缓存的内容，从而加速后续镜像构建的速度。

使用 buildkit 加速镜像构建，分为两个步骤：

1. 启用 buildkit
2. 指定缓存

启用 buildkit 需要在`build-image.sh`中设置启动 buildkit 的环境变量`DOCKER_BUILDKIT`：

```bash
$ DOCKER_BUILDKIT=1 docker build ...
```

并且在`Dockerfile`首行添加`Dockerfile`语法指令：

```dockerfile
# syntax = docker/dockerfile:1.0.0-experimental
```

完成之后即可在`Dockerfile`中指定缓存：

```dockerfile
RUN --mount=target=/root/.m2,type=cache \
  ./mvnw clean package
```

运行`build-image.sh`，切换至 buildkit 之后的首次镜像构建（尚不存在缓存）仍然需要下载完整的依赖包，在我本机测试，因受限于中国移动的网速，该过程耗时 535.6 秒（近十分钟）：

![buildkit-first-build](/assets/images/2019/0004/buildkit-first-build.png)

而因为完成第一次构建之后，由于缓存层的存在，第二次构建时，不必下载完整依赖，该过程仅耗时 6.4 秒：

![buildkit-second-build](/assets/images/2019/0004/buildkit-second-build.png)

检查镜像大小：

![image-size](/assets/images/2019/0004/image-size.png)

仍然维持在 103M。至此，已经成功完成 multi-stage 镜像构建的改造。

本文对应的示例代码可以在[集豆示例代码仓库](https://github.com/polybean/polybean)的`0004-multi-stage-build`目录中找到。
