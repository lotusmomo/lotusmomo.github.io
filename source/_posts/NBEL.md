---
title: 贝尔 EA0326GMP 刷官方 ImmortalWrt 教程
date: 2024-11-27 14:30:00
updated: 2024-11-27 14:30:00
tags: []
categories: 奇技淫巧
---

贝尔 EA0326GMP 是一款中国移动定制的WiFi 6 路由器，采用喜闻乐见的 MT7981B 方案，具有 128MB NAND 与 256MB DDR，无线规格为 2x2 MIMO AX3000。由于其优良的硬件规格与低廉的价格，该路由器具备了一定的可玩性与折腾价值。

本教程旨在提供一个刷写官方OpenWrt/ImmortalWrt与其ubootmod的方法，为喜欢使用OpenWrt/ImmortalWrt opkg 生态的用户提供参考。

<!--more-->

原始教程在：https://git.openwrt.org/?p=openwrt/openwrt.git;a=commit;h=40e7fab9e4a294882f198cb7fb5bc5eecee26ac8，commit message 为具体步骤。

# 解锁SSH

首先下载配置文件：https://firmware.download.immortalwrt.eu.org/cnsztl/mediatek/filogic/openwrt-mediatek-mt7981-nokia-ea0326gmp-enable-ssh.tar.gz。

将电脑网卡 IP 设为`192.168.10.100`，子网掩码`24`即`255.255.255.0`。登录路由器后台`192.168.10.1`，导入刚刚下载的配置文件。

导入完成后，你会发现web界面登不上了，密码总是错误，不过这已经不重要了。此时已经可以通过ssh连接到路由器。

# 备份 SPI NAND

在路由器原厂系统环境（以下简称stock固件）下查看SPI分区表：
```console
# cat /proc/mtd
dev:    size   erasesize  name
mtd0: 08000000 00020000 "spi0.0"
mtd1: 00100000 00020000 "BL2"
mtd2: 00080000 00020000 "u-boot-env"
mtd3: 00200000 00020000 "Factory"
mtd4: 00200000 00020000 "FIP"
mtd5: 00200000 00020000 "Config"
mtd6: 00200000 00020000 "Config2"
mtd7: 00c00000 00020000 "Aos-net"
mtd8: 00c00000 00020000 "bvasPlugin"
mtd9: 05680000 00020000 "ubi"
```

因为已经把整个 SPI NAND 映射到`mtd0`，所以只要备份`mtd0`就行了。由于stock固件可用内存过小，强行备份会oom，所以选择使用TCP发送数据，PC端上位机接收来备份。

因为路由器自带的busybox是阉割版，没有netcat，所以我们下一个静态链接的arm64 busybox： https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv8l ，用`scp`传到路由器的`/tmp`目录。

```bash
cd /tmp
# 赋执行权限
chmod +x /tmp/busybox-armv8l
dd if=/dev/mtdblock0 bs=1M | ./busybox-armv8l nc 192.168.10.100 5000
```

在pc端下个netcat，具体参考：https://cloud.tencent.com/developer/article/2182697

我使用MSYS2，更加简单方便。

```bash
pacman -Syyu
pacman -S openbsd-netcat pv
nc -l -p 5000 | pv > spi0_0.img
```

至此固件备份结束。

# 刷入 OpenWrt/ImmortalWrt

## 收集文件

首先前往官方 Firmware Selector （如果你有能力，可以直接前往国内镜像站下载相关文件）

需要获取的文件如下：

| 文件短名                  |                           下载链接                           | 备注                                                         |
| ------------------------- | :----------------------------------------------------------: | ------------------------------------------------------------ |
| `preloader.bin`           | [Go](https://mirrors.nju.edu.cn/immortalwrt/releases/23.05.4/targets/mediatek/filogic/immortalwrt-23.05.4-mediatek-filogic-nokia_ea0326gmp-preloader.bin) | 路由器的第一级Bootloader，由MTK提供的SDK提供。一般的厂商没有对其做出修改的能力，不刷也行。 |
| `bl31-uboot.fip`          | [Go](https://mirrors.nju.edu.cn/immortalwrt/releases/23.05.4/targets/mediatek/filogic/immortalwrt-23.05.4-mediatek-filogic-nokia_ea0326gmp-bl31-uboot.fip) | 引导程序映像。 用于启动时加载操作系统的底层软件。            |
| `initramfs-recovery.itb`  | [Go](https://mirrors.nju.edu.cn/immortalwrt/releases/23.05.4/targets/mediatek/filogic/immortalwrt-23.05.4-mediatek-filogic-nokia_ea0326gmp-initramfs-recovery.itb) | 集成最小文件系统的 Linux 内核。适用于首次安装或故障恢复。    |
| `squashfs-sysupgrade.itb` | [Go](https://mirrors.nju.edu.cn/immortalwrt/releases/23.05.4/targets/mediatek/filogic/immortalwrt-23.05.4-mediatek-filogic-nokia_ea0326gmp-squashfs-sysupgrade.itb) | 完整的系统，用于刷写新系统或更新现有系统。                   |

此外，我们还需要一个TFTP服务器，建议使用 Tftpd64 ： https://bitbucket.org/phjounin/tftpd64/downloads/tftpd64.464.zip

## 刷写 U-Boot

下载 bl31-uboot.fip，并在stock固件环境执行以下命令刷入FIP分区：

```bash
mtd write immortalwrt-23.05.4-mediatek-filogic-nokia_ea0326gmp-bl31-uboot.fip FIP    
```

## 进入 Initramfs 恢复环境

将PC的IP设置为 `192.168.1.254`，子网掩码`255.255.255.0`。

将下载好的`initramfs-recovery.itb`文件去除版本前缀，即去掉`23.05.4-`，重命名之后的文件名应该像这样：`immortalwrt-mediatek-filogic-nokia_ea0326gmp-initramfs-recovery.itb`。把该文件放置在 Tftpd64 的根目录，并启动 Tftpd 服务器。这一步最好关闭防火墙，不然很大可能失败。

拔路由器电源，找个针按住路由器上的 Reset ，插电开机。

过一会儿 tftp 服务器会读条，等待 Initramfs 恢复环境启动。等到路由器上的LAN灯亮起，就成功启动了，此时已经成功一半。

## 重新分区并刷入系统

SSH 连接`192.168.1.1`进入 Initramfs 恢复环境。首先新建目录`mkdir -p /tmp/flash`，scp上传4个刷机所需文件。

## 获取权限

安装`kmod-mtd-rw`，去你对应版本的包源里面找，比如 https://mirrors.nju.edu.cn/immortalwrt/releases/23.05.4/targets/mediatek/filogic/packages/ 。

SCP 传到`/tmp/flash`，执行

```bash
opkg install --nodeps kmod-mtd-rw*.ipk
```

安装，再执行

```bash
insmod /lib/modules/$(uname -r)/mtd-rw.ko i_want_a_brick=1
```

以安装内核模块，获取 mtd 的写权限。

执行以下命令确认分区表：

```console
root@ImmortalWrt:/tmp/flash# cat /proc/mtd
dev:    size   erasesize  name
mtd0: 00100000 00020000 "bl2"
mtd1: 00080000 00020000 "u-boot-env"
mtd2: 00200000 00020000 "factory"
mtd3: 00200000 00020000 "fip"
mtd4: 00200000 00020000 "config"
mtd5: 00200000 00020000 "config2"
mtd6: 07680000 00020000 "ubi"
```

这里你的输出结果如果跟我的不一样，建议你不要进行下一步操作，以免破坏原厂分区。

## 建立 U-Boot 环境变量分区

执行以下命令重新建立 UBI 子卷：

```bash
ubidetach -p /dev/mtd6 && ubiformat /dev/mtd6 -y && ubiattach -p /dev/mtd6
ubimkvol /dev/ubi0 -n 0 -N ubootenv -s 128KiB
ubimkvol /dev/ubi0 -n 1 -N ubootenv2 -s 128KiB
```

## 创建片上恢复分区

这一步是可选的。如果您不想使用 ubootmod 提供的 NAND 恢复启动功能，可以跳过此步骤。

但是假如你的路由器出现问题，你就要参照“进入 Initramfs 恢复环境” 一节，使用 tftp 进入 Initramfs 恢复环境。如果你刷了，在启动时按住 Reset 直接就能进入 Initramfs 恢复环境而无需在PC上启动 tftp 服务器。代价是ImmortalWrt系统会损失约10MB的可用空间，这是一个 Trade-off。

执行以下命令以创建片上恢复分区。这里恢复分区的大小要跟`initramfs-recovery.itb`的大小对应。即`11520KiB`。

```bash
ubimkvol /dev/ubi0 -n 2 -N recovery -s 11520KiB
ubiupdatevol /dev/ubi0_2 /tmp/flash/initramfs-recovery.itb
```

## 刷入主分区

保险起见再刷一遍preloader与ubootmod：

```bash
mtd write preloader.bin bl2
mtd write bl31-uboot.fip fip
```

最后使用`sysupgrade`命令刷写主分区，该命令执行后会自动重启。

```bash
sysupgrade -n squashfs-sysupgrade.itb
```

自动重启完成后，访问`192.168.1.1`，享受openwrt吧！

最后放一张配置完的图

