---
title: 小米路由器 WR30U 刷入 OpenWRT
date: 2025-02-19 17:04:00
updated: 2025-02-23 23:43:00
tags: []
categories: 奇技淫巧
---

WR30U 是小米为中国联通定制的一款家用路由器，采用了联发科 MT7981B SoC，其无线规格支持 802.11ax/ac/n/g/a/b 2x2 MIMO，具有 128MB NAND 闪存以及 256MB DRAM，做工、散热、信号均属于上乘。本文教大家如何给这款路由器刷入 OpenWrt 系统，解锁更多强大功能。

<!--more-->

## 开启 SSH

由于是运营商定制的路由器，小米在固件中内置了一个 elink 服务以提供家庭自动化的相关功能。如果用户使用运营商提供的光猫作为一级网关，该服务会与网关的 32768 端口建立 TCP 连接来将自身注册到网关。

该服务在系统升级时会使用 `wget %s -O /tmp/update.bin` 下载更新固件，但是它不会检查 URL 地址是否有效。因此，如果我们输入 `;reboot;` 作为地址，它将执行我们的命令（在本例中为“reboot”）。

藉由该漏洞，我们可以实现该路由器上的 ACE（任意代码执行）。已经有开发者提供了该漏洞的利用工具：
https://github.com/PatriciaLee3/wr30u_ssh 
只要按照说明即可开启 SSH。

## 备份分区

连接上 SSH 后运行以下命令以备份原厂固件。

```bash
nanddump -f /tmp/tmp/BL2.bin /dev/mtd1
nanddump -f /tmp/tmp/Nvram.bin /dev/mtd2
nanddump -f /tmp/tmp/Bdata.bin /dev/mtd3
nanddump -f /tmp/tmp/Factory.bin /dev/mtd4
nanddump -f /tmp/tmp/FIP.bin /dev/mtd5
nanddump -f /tmp/tmp/ubi.bin /dev/mtd8
nanddump -f /tmp/tmp/KF.bin /dev/mtd12
```

然后用 scp 保存到一个安全的地方。

## 设定 U-Boot 参数并刷入临时镜像

> 以下文件名均省略前缀，并默认你会用 scp 上传到路由器的 `/tmp/tmp` 目录。

小米的路由器采用双分区布局，分别保存在 nand 的`ubi`和`ubi1`分区中，类似 Android 的 A/B 分区。运行命令`cat /proc/cmdline`查看当前的内核命令行就可以确认当前是从哪个分区启动。我们的目的是要把  OpenWRT  的安装镜像写入另一个分区，并在下次启动时切换为从该分区启动。

如果命令的输出中包含`firmware=0`或者`mtd=ubi`，执行下面的命令：

```bash
nvram set boot_wait=on
nvram set uart_en=1
nvram set flag_boot_rootfs=1
nvram set flag_last_success=1
nvram set flag_boot_success=1
nvram set flag_try_sys1_failed=0
nvram set flag_try_sys2_failed=0
nvram commit
ubiformat /dev/mtd9 -y -f /tmp/tmp/stock-initramfs-factory.ubi
```

如果命令的输出中包含`firmware=1`或者`mtd=ubi1`，执行下面的命令：

```bash
nvram set boot_wait=on
nvram set uart_en=1
nvram set flag_boot_rootfs=0
nvram set flag_last_success=0
nvram set flag_boot_success=1
nvram set flag_try_sys1_failed=0
nvram set flag_try_sys2_failed=0
nvram commit
ubiformat /dev/mtd8 -y -f /tmp/tmp/stock-initramfs-factory.ubi
```

重启路由器，将电脑的 IP 设定为`192.168.1.254`，掩码`255.255.255.0`。使用 SSH 连接 `192.168.1.1` 并执行以下命令：

```bash
sysupgrade -n /tmp/tmp/stock-squashfs-sysupgrade.bin
```

SSH 连接会自动断开并重启，OpenWRT 已经刷入成功了。

## 刷入大分区固件

如果你想保留原始固件分区布局，就不要执行下面的步骤了。SSH 连接已经刷入 OpenWRT 的路由器，执行`cat /proc/mtd`查看当前的分区布局。输入应该包含以下的结果：
```
mtd7: 00040000 00020000 "KF"
mtd8: 02200000 00020000 "ubi_kernel"
mtd9: 04e00000 00020000 "ubi"
```

如果你的 `mtd8`，`mtd9`的参数与我提供的不一致，就不要继续操作了，以免变砖。

```bash
ubiformat /dev/mtd8 -y -f /tmp/ubootmod-initramfs-factory.ubi
```

重启。

执行`cat /proc/mtd`查看当前的分区布局。

```
mtd7: 00040000 00020000 "KF"
mtd8: 07000000 00020000 "ubi"
```

务必确认`mtd8`为 ubi。

解锁 mtd 分区。执行以下命令安装内核模块`kmod-mtd-rw`。

```bash
opkg update && opkg install kmod-mtd-rw
```

如果不方便联网，就自己去 OpenWRT的包源上下一个，比如https://mirrors.nju.edu.cn/immortalwrt/releases/24.10.0/targets/mediatek/filogic/kmods/6.6.73-1-5dc876ca3b3685f0643c2f2c902f7b0b/kmod-mtd-rw_6.6.73.2021.02.28~e8776739-r1_aarch64_cortex-a53.ipk，然后运行：

```bash
opkg install /tmp/tmp/kmod-mtd-rw*.ipk --nodeps
```

最后 启用内核模块：

```bash
insmod /lib/modules/$(uname -r)/mtd-rw.ko i_want_a_brick=1
```

执行`dmesg`查看内核消息，mtd-rw 将会把所有 mtd 分区标记为可写。

删除内核崩溃日志，否则路由器会陷入循环重启。

```bash
rm -f /sys/fs/pstore/*
```

