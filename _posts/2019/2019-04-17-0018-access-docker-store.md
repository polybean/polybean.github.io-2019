---
title: 0018 - 在macOS中访问Docker的数据目录（/var/lib/docker）
tags: ["Docker"]
---

我们知道 Docker 将数据的保存在目录`/var/lib/docker`中，如果我们尝试在 macOS 系统中检查这个目录，我们发现这个目录并不存在：

```bash
$ ll -d /var/lib/docker
ls: /var/lib/docker: No such file or directory
```

某些情况下，我们需要检查`/var/lib/docker`深入了解 Docker 的运行机制，怎样在访问到`/var/lib/docker`？介绍两种方法：

1. 运行帮助容器，挂载目录
2. 通过`screen`命令直接进入容器

第一种方案，运行帮助容器：

```bash
$ docker run --rm -it -v /:/vm-root alpine:edge sh
```

其中挂载选项`-v /:/vm-root`指定了将 DOCKER_HOST 的`/`目录挂载至容器的`/vm-root`目录，而后，我们在容器命令行中访问`/vm-root/var/lib/docker`即可查看 Docker 的数据目录。这种方法会有额外的镜像（`alpine:edge`）下载和存储开销。更为直接的方法是直接进入 hyperkit 虚拟机：

```bash
$ screen ~/Library/Containers/com.docker.docker/Data/vms/0/tty
```

通过组合键`Ctrl-A k`退出虚拟机命令行界面。
