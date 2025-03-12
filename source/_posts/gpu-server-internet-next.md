---
title: 新GPU服务器联网指南
date: 2023-03-02 12:49:00
updated: 2023-11-21 10:46:01
tags: []
categories: 奇技淫巧
---
新服务器运行在`Docker`容器里，使用信息中心分配的静态ip连接，无法连接至外部互联网。解决方法如下：

<!--more-->

## Linux
### Debian/Ubuntu
1. 安装Squid
   ```bash
   sudo apt-get update
   sudo apt-get install squid
   ```
2. 开启`IPv4`转发
   ```bash
   echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
   sudo sysctl -p
   ```
3. 修改配置文件
   ```bash
   vim /etc/squid/squid.conf
   ```
   删除
   ```
   http_access deny all
   ```
   添加一行
   ```
   http_access allow all
   ```
4. 启动Squid
   ```bash
   systemctl enable --now squid
   ```
### CentOS/RHEL
1. 安装Squid
   ```bash
   sudo yum install squid
   ```
2. 确认版本
   ```bash
   rpm -qa | grep squid
   ```
3. 开启`IPv4`转发
   ```bash
   echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
   sudo sysctl -p
   ```
4. 修改配置文件
   ```bash
   vim /etc/squid/squid.conf
   ```
   删除
   ```
   http_access deny all
   ```
   添加一行
   ```
   http_access allow all
   ```
5. 启动Squid
   ```bash
   systemctl enable --now squid
   ```
会用Linux的应该不要我教你怎么转发ssh吧:joy:
## Windows
1. 下载并安装`Squid for windows`：https://squid.diladele.com/
2. 选择`Console App`下载一个msi并安装：https://packages.diladele.com/squid/4.14/squid.msi
3. 右键状态栏图标，点击打开配置：
   ![image-20230302113031594](/legacy/imgs/63f219332288e2377b5f689f511526db.png)
4. 删除
   ```
   http_access deny all
   ```
   添加一行
      ```
      http_access allow all
      ```
5. 重启Squid
6. 在XShell里设置端口转发![image-20230302113228335](/legacy/imgs/6cc6cbaff27952d31e19a6efa0b8d0ac.png)
7. 连接到服务器，在`~/.bashrc`或`~/.zshrc`中添加以下配置：
   ```bash
   # proxy configure
   setproxy() {
       export HTTP_PROXY="http://127.0.0.1:3128"
       export HTTPS_PROXY="http://127.0.0.1:3128"
       export ALL_PROXY="http://127.0.0.1:3128"
   }
   unsetproxy() {
       unset HTTP_PROXY
       unset HTTPS_PROXY
       unset ALL_PROXY
   }
   ```
8. 新建文件`/etc/apt/apt.conf.d/proxy.conf`，并写入以下内容：
   ```properties
   Acquire {
     HTTP::proxy "http://127.0.0.1:3128/";
     HTTPS::proxy "http://127.0.0.1:3128/";
   }
   ```
9. 换源（此处以北京外国语大学镜像为例）：
   ```bash
   sudo mv /etc/apt/sources.list /etc/apt/sources.list.0
   sudo touch /etc/apt/sources.list
   sudo vim /etc/apt/sources.list
   ```
   写入以下内容：
   ```properties
   deb http://mirrors.ustc.edu.cn/ubuntu/ bionic main restricted universe multiverse
   deb-src http://mirrors.ustc.edu.cn/ubuntu/ bionic main restricted universe multiverse
   
   deb http://mirrors.ustc.edu.cn/ubuntu/ bionic-security main restricted universe multiverse
   deb-src http://mirrors.ustc.edu.cn/ubuntu/ bionic-security main restricted universe multiverse
   
   deb http://mirrors.ustc.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse
   deb-src http://mirrors.ustc.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse
   
   deb http://mirrors.ustc.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse
   deb-src http://mirrors.ustc.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse
   
   ## Not recommended
   # deb http://mirrors.ustc.edu.cn/ubuntu/ bionic-proposed main restricted universe multiverse
   # deb-src http://mirrors.ustc.edu.cn/ubuntu/ bionic-proposed main restricted universe multiverse
   ```
10. 运行`sudo apt-get update`，发现已经可以更新。
11. 运行
       ```bash
       setproxy
       curl baidu.com -x ${HTTP_PROXY}
       ```
    出现以下内容
       ```html
       <html>
       <meta http-equiv="refresh" content="0;url=http://www.baidu.com/">
       </html>
       ```
       即大功告成。
12. 强烈建议安装`Anaconda3`
       ```bash
       curl -O https://mirrors.nju.edu.cn/anaconda/archive/Anaconda3-2022.10-Linux-x86_64.sh
       chmod +x Anaconda3-2022.10-Linux-x86_64.sh
       ./Anaconda3-2022.10-Linux-x86_64.sh
       ```
13. `Pypi`换源：
       ```bash
       python -m pip install -i https://mirrors.bfsu.edu.cn/pypi/web/simple --upgrade pip
       pip config set global.index-url https://mirrors.bfsu.edu.cn/pypi/web/simple
       ```
14. `Conda`换源：
       ```bash
       touch ~/.condarc
       vim ~/.condarc
       ```
     输入以下内容：
       ```yaml
       channels:
         - defaults
       show_channel_urls: true
       default_channels:
         - https://mirrors.bfsu.edu.cn/anaconda/pkgs/main
         - https://mirrors.bfsu.edu.cn/anaconda/pkgs/r
         - https://mirrors.bfsu.edu.cn/anaconda/pkgs/msys2
       custom_channels:
         conda-forge: https://mirrors.bfsu.edu.cn/anaconda/cloud
         msys2: https://mirrors.bfsu.edu.cn/anaconda/cloud
         bioconda: https://mirrors.bfsu.edu.cn/anaconda/cloud
         menpo: https://mirrors.bfsu.edu.cn/anaconda/cloud
         pytorch: https://mirrors.bfsu.edu.cn/anaconda/cloud
         pytorch-lts: https://mirrors.bfsu.edu.cn/anaconda/cloud
         simpleitk: https://mirrors.bfsu.edu.cn/anaconda/cloud
       ```
