---
title: Home Assistant 搭建指南
date: 2023-04-13 17:38:40
updated: 2023-04-13 17:38:40
tags: []
categories: 日常
---
## 简介
Home Assistant（以下简称HASS）是一款智能家居自动化平台，旨在帮助用户将各种智能设备整合在一起，从而实现更便捷、更高效、更智能的生活方式。通过HASS，用户可以轻松地控制家中的照明、温度、安防、音频、视频等各类设备，实现更智能、更个性化的家庭体验。HASS支持众多的智能设备品牌和协议，用户可以根据自己的需求进行定制和配置，实现智能家居的全面升级。

<!--more-->

## 准备环境
HASS是基于Docker开发的，已经为云原生的生产环境做好了准备。上至运行在服务器上的k8s集群，下至小巧的嵌入式设备，都能运行HASS。下面给出`Docker`与`k8s-pods`的安装方法。
### Docker-compose
- 执行`mkdir home-assistant && cd home-assistant`创建文件夹，并且新建文件`docker-compose.yaml`，写入如下的配置文件：
  ```yaml
  version: '3'
  services:
    homeassistant:
      container_name: homeassistant
      image: homeassistant/home-assistant
      volumes:
        - ./:/config
        - /etc/localtime:/etc/localtime:ro
      restart: unless-stopped
      privileged: true
      network_mode: host
  ```
  > Tips: 网络模式`host`仅能在`Linux`下使用。HomeKit扩展依赖`mDNS`功能，仅在`host`模式下可用。
- 运行`docker-compose up -d`启动。
### K8s deployment yaml
- 将以下内容写入`hass.yaml`:
  ```yaml
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    finalizers:
      - kubernetes.io/pvc-protection
    name: homeassistant
    namespace: default
  spec:
    accessModes:
      - ReadWriteMany
    resources:
      requests:
        storage: 10Gi
    storageClassName: 外挂存储的名字
    volumeMode: Filesystem
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: homeassistant
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: homeassistant
    template:
      metadata:
        labels:
          app: homeassistant
      spec:
        containers:
          - name: homeassistant
            image: homeassistant/home-assistant
            ports:
              - containerPort: 8123
            resources:
              limits:
                cpu: 200m
                memory: 512Mi
              requests:
                cpu: 10m
                memory: 64Mi
            volumeMounts:
              - mountPath: /config
                name: data
        volumes:
          - name: data
            persistentVolumeClaim:
              claimName: homeassistant
  ---
  apiVersion: v1
  kind: Service
  metadata:
    labels:
      app: homeassistant
    name: homeassistant
  spec:
    externalTrafficPolicy: Cluster
    ports:
    - protocol: TCP
      port: 8123
      targetPort: 8123
    selector:
      app: homeassistant
    sessionAffinity: None
    type: NodePort
  ```
- `kubectl apply -f homeassistant.yaml`
最后，访问`http://server_ip:8123`来进行初始化，设置用户名、密码等。
## 安装插件
HASS的高扩展性主要来源于它丰富的插件与扩展。本章节将以米家与HomeKit为例，讲述插件的安装与配置过程。
### 安装Home Assistant Community Store (HACS)
- 进入容器内部，并cd进入到HASS配置目录：
  `docker exec -it homeassistant bash`
- 使用命令行安装：
  `wget -O - https://hacs.vip/get | bash -`
  如果上面的命令执行后卡住不动，或没有提示安装成功，请尝试下面的命令：
  `wget -O - https://hacs.vip/get | HUB_DOMAIN=ghproxy.com/github.com bash -`
### 安装hass-xiaomi-miot米家插件
```bash
docker exec -it homeassistant bash
wget -q -O - https://cdn.jsdelivr.net/gh/al-one/hass-xiaomi-miot/install.sh | HUB_DOMAIN=hub.fastgit.org bash -
exit
docker-compose restart
```
#### 配置
- 配置 - 集成 - 管理集成 - 添加集成；
- 搜索`xiaomi`，选择 `xiaomi-miot-auto`；
- 选择“账号集成模式”；
- 输入小米账号（手机号）密码，选择”云端模式“；
此时，所有米家物联网设备已经接入完毕。
### 安装 Apple HomeKit 插件
- 前往配置 - 集成 - 管理集成 - 添加集成 - Homekit；
- 使用iOS设备上的家庭APP扫描网页“通知”面板上的二维码来添加HASS网关；
- 跟着苹果提示，把设备都添加到“家庭”中。
