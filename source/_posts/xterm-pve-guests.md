---
title: 为PVE虚拟机启用XTerm登录
date: 2022-07-22 20:00:00
updated: 2022-07-23 14:21:13
tags: []
categories: 奇技淫巧
---

我们在PVE中新建虚拟机后，在web界面默认的连接方式是novnc，无法进行复制粘贴等操作。但是如果我们新建的是LXD容器，默认的登陆方法是通过`XTerm.js`，可以进行复制粘贴等操作。本文将主要介绍如何为PVE虚拟机启用XTerm登录。

<!--more-->

![vnc](vnc.png)

进入PVE的web管理界面，选中需要操作的虚拟机，添加串行端口`serial0`。

![serial](serial.png)

重启虚拟机，执行

```bash
vim /etc/default/grub
```

将`GRUB_CMDLINE_LINUX=""`改为

```bash
GRUB_CMDLINE_LINUX="quiet console=tty0 console=ttyS0,115200"
```

如果是Debian系的，如Ubuntu，Debian，执行

```bash
update-grub
```

如果是Redhat系的，如RHEL，CentOS，执行

```bash
grub2-mkconfig --output=/boot/grub2/grub.cfg
```

![xtermjs](xtermjs.png)

重启，在“控制台”菜单选择“xterm.js”。

![tty](tty.png)

XTerm已经可以通过`ttyS0`正常登录了。

