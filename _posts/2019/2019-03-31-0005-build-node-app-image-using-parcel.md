---
title: 0005 - [构建Docker镜像]Parcel - 构建Node.js微服务Docker镜像的好帮手
tags: ["Docker", "Node.js"]
album: 构建Docker镜像
---

Node.js 的横空出世使得 JavaScript 的应用场景不再限于前端领域的开发，Node.js 基于事件驱动的编程模型可以提供很好的并发效率，已经成为开发后端服务选型时的重要候选。

本文将展示构建一个 Node.js 服务 Docker 镜像的过程，我们将重温[“使用 multi-stage 构建 Docker 镜像”](/2019/03/29/0004-multi-stage-build)的原则。

应用 multi stage build 的关键就在于找到如同 Maven 之于 Spring Boot 的构建工具。而 JavaScript 具有成熟的生态系统，自然也不会缺乏这样的构建工具。**对于一个 Node.js 服务而言，构建工具的存在的意义是，将应用的依赖与应用本身打包为单一的、缩减的（minify）JavaScript 源文件，而不必将整个`node_modules`添加到镜像中，从而有效的减小了镜像的大小**。

JavaScript 的构建工具从较早的 [Gulp](https://gulpjs.com/) 和 [Grunt](https://gruntjs.com/)，到[Webpack](https://webpack.js.org/)，对构建任务都有非常成熟和完善的支持，尤其是 Webpack，后来者居上，甚至大有独占鳌头的趋势——直到 [Parcel](https://parceljs.org/) 的出现。

Webpack 的强大之处在于，它提供了丰富的 loader 和 plugin，你几乎可以用它们来完成构建过程中的任何任务，相对的，使用 Webpack 的不便之处在于，你必须要编写 JavaScript 代码配置使用到的每一个 loader 和 plugin。Parcel 的便捷之处在于，它甚至不需要任何一行配置代码就可以完成与 Webpack 相同的工作，解决构建过程中绝大多数问题。

<!--more-->

本文对应的示例代码可以在[集豆示例代码仓库](https://github.com/polybean/polybean)的`0005-build-node-app-image-using-parcel`目录中找到。

首先，我们创建 Node.js 版本的`demo`服务，使用`yarn`初始化工程：

![init-project](/assets/images/2019/0005/init-project.png)

在`index.js`中编写 Node.js 版本的 Hello World：

```js
const http = require("http");

const port = "8080";

const app = new http.Server();

app.on("request", (req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.write("Hello World!");
  res.end("\n");
});

app.listen(port, () => {
  console.log(`Server is listening on port ${port}`);
});
```

我们无需在本地安装 Parcel，只需在`package.json`中指定 Parcel 的版本，mutli stage build 的第一阶段将会安装 Parcel 的指定版本：

```json
"devDependencies": {
  "parcel-bundler": "^1.12.3"
}
```

编写 Dockerfile：

```dockerfile
# syntax = docker/dockerfile:1.0.0-experimental
FROM node:8.15.1-alpine as builder
WORKDIR /builder
COPY . /builder
RUN --mount=target=/builder/node_modules,type=cache \
  npm install && npm run build-bundle

FROM node:8.15.1-alpine
WORKDIR /app
COPY --from=builder /builder/dist/index.js /app/
CMD node index.js
```

注意：与[“使用 multi-stage 构建 Docker 镜像”](/2019/03/29/0004-multi-stage-build)相同，此处使用了 buildkit 提供的缓存功能：

Node.js 工程的`package.json`提供了脚本入口，我们可以编写构建工程和构建 Docker 镜像的命令入口：

```json
"scripts": {
  "build-bundle": "parcel build --target=node index.js",
  "build-image": "DOCKER_BUILDKIT=1 docker build . -t $npm_package_name:$npm_package_version",
  "start": "docker run --rm -d -p 8080:8080 $npm_package_name:$npm_package_version"
},
```

其中：

- `build-bundle`命令使用 Parcel 构建 Node.js 工程，将工程源文件及其依赖包打包并做缩减（minify）处理
- `build-image`是构建 Docker 镜像的命令入口，使用到了两个 npm 变量（`npm_package_name`与`npm_package_version`）避免对镜像名和镜像版本的硬编码
- `start`命令用于启动`demo`服务的容器

一切就绪，运行镜像构建命令：

```bash
# path=demo
$ yarn build-image
```

启动`demo`服务

```bash
# path=demo
$ yarn start
```

验证：

```bash
$ curl localhost:8080
```

获得`Hello World!`返回。至此，完成基于 Node.js 的`demo`服务镜像构建。
