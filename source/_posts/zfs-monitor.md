---
title: 如何优雅监控zfs运行状态
date: 2024-03-14 23:21:00
updated: 2024-03-14 23:21:00
tags: []
categories: 奇技淫巧
---

TLDR: 使用 Grafana + InfluxDB + Telegraf。这也是清华大学TUNA所使用的方案。

<!--more-->

# 事件起因

清华大学TUNA镜像站想必大家已经十分熟悉。TUNA提供了一个状态页面，可以监控服务器的流量、磁盘空间等等。经过一番探究，发现数据表都是静态渲染的。

# 安装InfluxDB

# 安装Telegraf

## 编译安装zpool_influxdb

zpool_influxdb是一个用于 ZFS 池统计的 influxdb 线路协议代理，适用于 telegraf。

# 安装Grafana