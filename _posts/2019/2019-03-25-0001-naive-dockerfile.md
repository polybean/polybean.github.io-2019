---
title: "[0001]编写第一份Dockerfile"
tags: ["Docker"]
album: 构建Docker镜像
---

在容器技术普及的今天，我们经常需要为自己编写的应用程序构建 Docker 镜像。今天我们基于一个 Spring Boot 的 Hello World 工程，编写`Dockerfile`，构建第一个 Docker 镜像。

访问[Spring Initializr](https://start.spring.io/)，选择 Reactive Web 作为唯一依赖，生成 Spring Boot 工程。大家可以在与集豆博客[配套的示例代码仓库](https://github.com/polybean/polybean)中找到本文对应的样例工程（位于目录`0001-naive-dockerfile`中）。

![Create Spring Boot Project]({{site.baseurl}}/assets/images/0001/spring-initializr.png)

为了在访问路径`/`时，获得`Hello World!`响应，我们需要编写如下的`HomeController`：

```java
@RestController
@RequestMapping
public class HomeController {
    @GetMapping
    public ResponseEntity<Mono<String>> index() {
        return ResponseEntity.ok(Mono.just("Hello World!"));
    }
}
```

为这个简单的 Spring Boot 程序的构建 Docker 镜像，编写如下的`Dockerfile`：

```dockerfile
FROM openjdk:8u191-jdk-alpine3.9
WORKDIR /app
COPY .mvn/ .mvn/
COPY src/ src/
COPY mvnw .
COPY pom.xml .
RUN ./mvnw clean package
CMD java -jar target/demo-0.0.1-SNAPSHOT.jar
```

使用`docker build`命令构建镜像：

```bash
# path = 0001-naive-dockerfile
$ docker build . -t demo:0.0.1-SNAPSHOT
```

构建完成后，可以用`docker images`命令查看：

```bash
$ docker images | grep demo
```

![demo-image]({{site.baseurl}}/assets/images/0001/demo-image.png)

通过`docker run`命令启动`demo`镜像的容器：

```
$ docker run --rm -d -p 8080:8080 demo:0.0.1-SNAPSHOT
```

使用`curl`命令访问 URL`http://localhost:8080/`，如预期的获得`Hello World!`响应。

![demo-image]({{site.baseurl}}/assets/images/0001/curl-index.png)

至此，我们已经成功的完成了第一个镜像的构建。但是，这份`Dockerfile`存在以下几个显而易见的问题：

1. 无法复用本地`$HOME/.m2`目录已下载的依赖包，每次修改源代码后，构建镜像时，都需要重新下载该 Spring Boot 工程的所有依赖包，极为耗时；
2. 镜像文件过大（191MB），有很大的优化空间；
3. 镜像版本（`demo:0.0.1-SNAPSHOT`）为硬编码。

在后续文章中，我们将逐一解决这三个问题。
