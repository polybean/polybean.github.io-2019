---
title: 0006 - [构建Docker镜像]Maven Docker 插件
tags: ["Docker", "Spring Boot"]
album: 构建Docker镜像
---

如果我们使用 Maven 构建 Spring Boot 工程的话，可以使用 Maven 的 Docker 插件来构建该 Spring Boot 服务的镜像。

使用 Maven Docker 插件构建 Docker 镜像带来的便利是：不用编写构建脚本以及`Dockerfile`就可以构建镜像。对于`demo`工程，我们可以构建出与[使用 multi-stage 构建 Docker 镜像](/2019/03/29/0004-multi-stage-build)完全相同的`demo`服务镜像。

<!--more-->

本文对应的示例代码可以在[集豆示例代码仓库](https://github.com/polybean/polybean)的`0006-maven-docker-plugin`目录中找到。

使用 Maven Docker 插件构建服务镜像的过程如下：

首先，在`pom.xml`中声明对该插件的依赖，并对构建镜像的参数进行配置：

```xml
...
<build>
  <plugins>
    ...
    <plugin>
      <groupId>com.spotify</groupId>
      <artifactId>docker-maven-plugin</artifactId>
      <version>1.2.0</version>
      <configuration>
        <baseImage>openjdk:8u191-jre-alpine3.9</baseImage>
        <imageName>${project.name}</imageName>
        <imageTags>
          <imageTag>${project.version}</imageTag>
        </imageTags>
        <entryPoint>["java", "-jar", "/${project.build.finalName}.jar"]</entryPoint>
        <resources>
          <resource>
            <targetPath>/</targetPath>
            <directory>${project.build.directory}</directory>
            <include>${project.build.finalName}.jar</include>
          </resource>
        </resources>
      </configuration>
    </plugin>
  </plugins>
</build>
```

关于配置参数，需要注意：

- 指定`baseImage`时，不建议使用[该插件官方文档](https://github.com/spotify/docker-maven-plugin)使用的`java`作为基础镜像。如果使用`java`作为基础镜像，则构建出的`demo`服务镜像有 600+MB；
- `imageName`和`imageTag`的作用与[使用构建参数（Build Args）去除镜像构建过程中的硬编码](2019/03/27/0003-docker-build-args)一文中使用的构建脚本`build-image.sh`的`name`和`version`作用一样，都是去除镜像名和镜像标签的硬编码；
- `entryPoint`对应`Dockerfile`的`ENTRYPOINT`指令，与[使用构建参数（Build Args）去除镜像构建过程中的硬编码](2019/03/27/0003-docker-build-args)一文中`Dockerfile`的`CMD`指令作用相同，都是用来指定镜像的启动命令，关于`ENTRYPOINT`和`CMD`指令的差别，详见[Dockerfile: `ENTRYPOINT` vs `CMD`](#)一文。

完成 Maven Docker 插件的配置后，通过以下命令构建`demo`服务镜像：

```bash
# path=demo
$ ./mvnw clean package docker:build
```

可以通过`docker images`命令查看构建得到的`demo`镜像的大小：

```bash
$ docker images | grep demo
```

该镜像大小与[使用 multi-stage 构建 Docker 镜像](/2019/03/29/0004-multi-stage-build)通过编写`Dockerfile`构建得到的镜像大小完全一致——都为 103MB。

![image-size](/assets/images/2019/0006/image-size.png)

使用 Maven Docker 插件构建镜像的过程也是一个 multi stage build 过程，第一阶段通过`./mvnw package`命令构建`demo`服务的 jar 包；第二阶段将`demo`服务的 jar 包置于由`baseImg`指定的基础镜像中。
