---
title: 0017 - Windows和macOS系统中隐匿的Docker虚拟机
tags: ["Docker"]
---

[Docker 官网](https://docs.docker.com/engine/docker-overview/)的 Docker 架构图中，占据 C 位的是`DOCKER_HOST`

![docker-architecture](https://docs.docker.com/engine/images/architecture.svg)

我们今天讨论的主角就是这个占据 C 位的`DOCKER_HOST`。

Docker 推出之时，它的运行依赖 Linux 系统——到现在这句话在大部分情况下仍然成立。所以我们可以认为，如果要体验 Docker，（大多数情况下）我们需要一个 Linux 系统。

在生产或测试环境中，我们一般会选择 Linux 系统安装并运行 Docker。这种情况下，这个 C 位的`DOCKER_HOST`就是生产或测试系统中的 Linux 主机。

在开发环境下，我们通常使用的是 Windows 或 macOS 台式机或笔记本。Windows 系统一直是比较特殊的一个存在，鉴于微软和 Docker 公司的关系不错（其实是在微软拥抱开源与注重云计算战略的推动下），Docker 可以支持原生的 Windows 运行环境而不再依赖 Linux。在 Docker for Windows（Docker Windows 发行版本）中，我们可以在 Windows 和 Linux 的 Docker Daemon 间进行切换：

![](https://docs.docker.com/docker-for-windows/images/docker-menu-switch.png)

如果选择使用 Windows Docker Daemon，C 位的`DOCKER_HOST`就是 Windows 主机。如果使用 Linux Docker Daemon，C 位的`DOCKER_HOST`则是在安装过程中创建的基于 Hyper-V 的 Linux 虚拟机。以下这张图很直观的展示了 Docker for Windows 支持的两种运行模式：

![](/assets/images/2019/0017/docker-for-windows.png)

如果我们使用 macOS，情况就很简单，只要一个 Linux 系统。显然在 macOS 上运行 Linux，我们需要一个 hypervisor。Docker 的 macOS 发行版本选择了[hyperkit](https://github.com/moby/hyperkit)作为 macOS 运行环境的 hypervisor，所以在 macOS 系统中 C 位的`DOCKER_HOST`就是使用 hyperkit 创建的 Linux 虚拟机。
