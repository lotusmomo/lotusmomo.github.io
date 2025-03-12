---
title: 在Rock5B开发板上安装RealVNC服务器
date: 2023-03-22 13:21:36
updated: 2023-03-22 13:21:36
categories: Linux
---


# 获取安装包

因为RealVNC的arm版本专为树莓派提供，我们需要访问https://mirrors.bfsu.edu.cn/raspberrypi/pool/main/r/realvnc-vnc/来找到安装包。下载6.x的最新版本：[realvnc-vnc-server_6.9.1.46706_armhf.deb](https://mirrors.bfsu.edu.cn/raspberrypi/pool/main/r/realvnc-vnc/realvnc-vnc-server_6.9.1.46706_armhf.deb)。因为最新的7.x从Licene Key验证改为License File，即使安装了也无法激活。

<!--more-->

# 安装软件包

执行`sudo -i`切换到root用户，执行：

```bash
wget https://mirrors.bfsu.edu.cn/raspberrypi/pool/main/r/realvnc-vnc/realvnc-vnc-server_6.9.1.46706_armhf.deb
dpkg -i realvnc-vnc-server_6.9.1.46706_armhf.deb
apt-get update
apt-get install -f
```

# 链接库文件

此时如果直接打开vncserver，会报错：

```
vncserver: error while loading shared libraries: libbcm_host.so.0: cannot open shared object file: No such file or directory
```

这是因为没有链接动态库。我们需要手动链接一下：

```bash
cd /usr/lib/aarch64-linux-gnu/
sudo ln libvcos.so /usr/lib/libvcos.so.0
sudo ln libvchiq_arm.so /usr/lib/libvchiq_arm.so.0
sudo ln libbcm_host.so /usr/lib/libbcm_host.so.0
```

# 关闭Wayland

大部分vnc服务器无法在Wayland桌面环境下运行。`sudo vim /etc/gdm3/custom.conf`并取消注释这一行：

```
#WaylandEnable=false
```

# 启动服务

```bash
sudo systemctl enable vncserver-virtuald.service
sudo systemctl enable vncserver-x11-serviced.service
sudo systemctl start vncserver-virtuald.service
sudo systemctl start vncserver-x11-serviced.service
```

重启开发板。

# 激活

realvnc的激活码在网上很容易找到，如：

```
VKUPN-MTHHC-UDHGS-UWD76-6N36A    有效期至2029-07-21
77NVU-D9G5T-79ESS-V9Y6X-JMVGA    有效期至2024-12-02
```

使用以下命令

```bash
vnclicense -add VKUPN-MTHHC-UDHGS-UWD76-6N36A
```

来应用激活码。

![connect-via-realvnc](/legacy/imgs/081932238c611ee75684ef379a1e5f85.png)

此时可以看到，已经可以通过vnc完美连接了。