---
title: 在 Docker 中产生 Core Dump 文件
date: 2020-01-12 17:14:00
updated: 2020-03-08 09:35:22
tags: []
categories: Linux
---
首先简单补充一下 Core Dump 文件可以做什么吧。

当我们程序崩溃的时候，除了看到 Segmentation Fault 之类的错误信息以外，很有可能在后面还有一句 (core dumped)。以前看到这些字眼都觉得很烦，因为程序崩溃了。但是后来，今年暑假学习的时候，看到学长的操作才恍然大悟，看到 (core dumped) 应该感到高兴才对，因为他把程序崩溃时的运行时信息完完全全地记了下来，包括他的整个内存、所有线程、堆栈信息、寄存器等等……这样一来就给找到 bug 提供了一条很好的线索。

<!--more-->

# 产生和使用 Core Dump 文件

在 Ubuntu 14.04 中，要使得程序崩溃时产生 Core Dump 文件，首先要在 Shell 中执行
```bash
ulimit -c unlimited
```
然后再去执行我们的程序。这是因为，默认的 ulimit 限制了 Core Dump 文件的大小最大为0，也就是不产生，这里我们改成不限制就行了。
之后，如果程序崩溃了，会在当前目录产生一个叫做 core 的文件。我们可以把它载入到 GDB 里面，比方说我们的程序是 ./a.out，那么我们执行
```bash
gdb ./a.out core
```
然后我们就能在 GDB 里面看到崩溃时的样子啦！
值得注意的是，core 文件不会被覆盖，所以在使用完当前的 core 文件后，记得要把它删掉，否则就看不到下次产生的 Core Dump 了。

## 在程序中指定产生 Core Dump 文件

在写程序的时候，我们可能会希望在一些严重错误发生的时候终止程序运行。除了打日志和 exit() 以外，我们还可以选择使用 abort()。当执行 abort() 的时候，程序直接退出，不执行清扫，并且会产生 Core Dump 文件（如果 ulimit 允许的话）。

### 在 Docker 中产生 Core Dump 文件

因为现在家用GPU的虚拟化还没有什么合理的方案，所以我们在开发的时候就把 nvidia-docker 作为虚拟机来用了……后来我发现了一个问题，就是我在 Docker 里面无论如何也无法产生 Core Dump 文件。几经波折，最后终于找到了合理的方法。
首先是，我们要在宿主机上执行
```bash
echo '/tmp/core.%t.%e.%p' | sudo tee /proc/sys/kernel/core_pattern
```
这是因为系统在产生 Core Dump 文件的时候是根据 /proc/sys/kernel/core_pattern 的设定。而默认的设定是 |/usr/share/apport/apport %p %s %c %P，也就是用管道传给 apport。然而 Docker 里面的系统不一定有装 apport，并且 /proc 又是直接挂到 Docker 里面的，所以我们就得改成放到固定的位置去，也就是 /tmp。
另外，在 docker run 的时候要加上以下参数
```bash
docker run ${IMAGE} --ulimit core=-1 --security-opt seccomp=unconfined
```
前者就是把 Core Dump 文件的大小设置为无限制，后者是为了开放 ptrace 系列高权限的系统调用，这样我们才可以在 Docker 里面使用 GDB。

# Reference

- https://github.com/docker/docker/issues/12515#issuecomment-100624686
- https://github.com/docker/docker/issues/11740#issuecomment-86041679
- https://github.com/docker/docker/issues/11740#issuecomment-222924994
