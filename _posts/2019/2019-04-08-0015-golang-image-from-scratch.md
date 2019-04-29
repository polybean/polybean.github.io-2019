---
title: 0015 - [构建Docker镜像]Golang：白手起家（FROM scratch）构建镜像
tags: ["Docker", "Golang"]
album: 构建Docker镜像
---

如果我们分析之前编写的 Dockerfile，会发现无论是 Spring Boot 应用还是 Node.js 应用，都需要指定基础镜像——由`Dockerfile`中的`FROM`指令所指定。基础镜像的主要作用是指定容器的运行时环境，比如 Spring Boot 服务需要 JRE 作为运行时环境，所以我们在构建 Spring Boot 应用镜像时指定的基础镜像为：

```dockerfile
FROM openjdk:8u191-jre-alpine3.9
```

Node.js 服务需要 Node.js 作为运行时环境，所以在构建 Node.js 应用镜像时指定的基础镜像为：

```dockerfile
FROM node:8.15.1-alpine
```

基础镜像对于应用镜像的大小有决定性作用，也直接决定了对应的服务的部署效率，通过查看对应的基础镜像大小，可以看到：

![](/assets/images/2019/0015/jdk-node-image-size.png)

JRE 基础镜像为 85MB，加上 Spring Boot 框架的依赖之后，即便我们构建一个最简单的 Hello World 示例服务，其镜像大小最终在 103MB；Node.js 示例服务的情况稍好，基础镜像大小在 66MB 左右，示例服务的代码经由 Parcel 打包之后大小可以忽略不计，最终镜像大小在 66MB 左右。

镜像越大，在构建/部署以下环节的效率将会降低：

- 更新基础镜像时（比如从`openjdk:8u191-jre-alpine3.9`更新至`openjdk:8u201-jre-alpine3.9`）
- 应用镜像构建完成，推送至 Image Registry 时
- 部署服务，在部署环境中拉取镜像时

究其根源，都是因为镜像越大，推送/拉取镜像的耗时就越多。

有没有极简的基础镜像以及基于极简基础镜像构建的应用呢？答案是肯定的。

我们先揭晓答案，如果用 Go 语言编写同样的 Hello World 示例服务，完成镜像构建后，其镜像大小为 7.32MB

![](/assets/images/2019/0015/golang-app-image-size.png)

其基础镜像的大小为 0。

<!--more-->

用 Go 编写的 Hello World 服务源代码为：

```go
package main

import (
	"fmt"
	"log"
	"net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintln(w, "Hello, World!")
}

func main() {
	http.HandleFunc("/", handler)
	log.Fatal(http.ListenAndServe(":8888", nil))
}
```

构建使用的`Dockerfile`为

```dockerfile
FROM golang:1.12-alpine AS build
WORKDIR /src/
COPY demo.go /src/
RUN CGO_ENABLED=0 go build -o /bin/demo

FROM scratch
COPY --from=build /bin/demo /bin/demo
ENTRYPOINT ["/bin/demo"]
```

这是一个典型的 multi stage build 使用的 Dockerfile，其中第二阶段（也就是生成最终应用镜像的阶段）的基础镜像为`scratch`，[DockerHub](https://hub.docker.com/_/scratch)对`scratch`镜像的描述为：

> an explicitly empty image, especially for building images "FROM scratch"

也就是说这个镜像什么也没有，是真空。之所以叫`scratch`是因为结合指定基础镜像的`FROM`指定正好构成了英语中的固定短语“from scratch”，含义就是白手起家。并非所有编程语言都可以如此洒脱的白手起家，基本上只有编译型语言可以在构建应用镜像时做到白手起家，而 Python，Java 这样的流行语言在构建其所编写的应用镜像时都需要运行时环境。

构建这个由 Go 语言编写的 demo 服务镜像，执行：

```bash
# path=0015-golang-image-from-scratch
$ docker build . -t demo:0.0.1
```

启动 Go 语言编写的 demo 镜像：

```bash
$ docker run --rm -d -p8888:8888 demo:0.0.1
```

Go 的简洁、高效（尤其是强大的并发能力）都是人们喜爱它的原因，在构建应用镜像时的优势只是 Go 语言诸多优势中的一个缩影。在云原生（Cloud Native）时代，Go 语言正变得越来越流行。我们熟悉的容器引擎 Docker，容器编排平台 Kubernetes，企业级的区块链框架 Hyperledger Fabric 都是用 Go 编写的。当下，如果学习一门新的编程语言，相信 Go 是不错的选择。

本文对应的示例代码可以在[集豆示例代码仓库](https://github.com/polybean/polybean)的`0015-golang-image-from-scratch`目录中找到。
