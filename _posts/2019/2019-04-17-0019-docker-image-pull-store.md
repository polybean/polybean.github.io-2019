---
title: 0019 - [构建Docker镜像]一张图看懂Docker获取、存储镜像的全过程
tags: ["Docker"]
album: 构建Docker镜像
---

本文展示了执行`docker pull alpine:edge`命令后，获取、存储`alpine:edge`镜像过程的图解。直接上图，不赘述：

![](/assets/images/2019/0019/docker-image-pull-and-store.png)

[示例代码仓库](https://github.com/polybean/polybean)中`0019-image-manifest`目录中包含两个目录，是本文的素材支撑，这两个目录的内容为：

- `01-clean-state`：安装 Docker 后，未拉取/构建任何镜像时的`/var/lib/docker`目录的内容
- `02-pull-alpine`：执行`docker pull alpine:edge`之后`/var/lib/docker`目录的内容

两者比较的结果（`02-pull-alpine`比`01-clean-state`新增的内容）为上图中紫色的目录/文件。

本文要点：

- 拉取镜像时会根据当前环境的 CPU 体系架构和操作系统类型从 Image Registry 中获取对应的镜像
- 可以通过`docker version`命令信息的 Server 信息获知当前环境的 CPU 体系架构和操作系统类型
- 可以通过`docker manifest inspect`命令查看镜像支持的所有 CPU 体系架构和操作系统类型
- 为了能够执行`docker manifest`命令，需要在`$HOME/.docker/config.json`文件中打开 Docker 命令行客户端的`experimental`开关
- 一个`diff`即为 overlay 文件系统中的一层
- 镜像的一个 manifest 主要包含配置信息和 rootfs 两大关键信息
