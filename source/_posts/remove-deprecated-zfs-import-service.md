---
title: 移除过时的 zfs-import 服务
date: 2025-03-15 14:05:31
tags: []
categories: Linux
---

有的时候我们已经删除了某个 zfs 存储池，但是 zfs-import 服务仍然尝试在系统启动时导入它。本文记录了如何移除这种过时的 zfs-import 服务。

<!--more-->

使用 `journalctl` 命令查看 systemd 的日志，找出目标服务。

```
root@pve01 ~ % journalctl -r | grep HDPool
Mar 15 13:58:20 pve01 systemd[1]: Failed to start zfs-import@HDPool01.service - Import ZFS pool HDPool01.
Mar 15 13:58:20 pve01 systemd[1]: zfs-import@HDPool01.service: Failed with result 'exit-code'.
Mar 15 13:58:20 pve01 systemd[1]: zfs-import@HDPool01.service: Main process exited, code=exited, status=1/FAILURE
Mar 15 13:58:20 pve01 zpool[2193]: cannot import 'HDPool01': no such pool available
Mar 15 13:58:20 pve01 systemd[1]: Starting zfs-import@HDPool01.service - Import ZFS pool HDPool01...
Feb 28 15:46:15 pve01 systemd[1]: Failed to start zfs-import@HDPool01.service - Import ZFS pool HDPool01.
Feb 28 15:46:15 pve01 systemd[1]: zfs-import@HDPool01.service: Failed with result 'exit-code'.
Feb 28 15:46:15 pve01 systemd[1]: zfs-import@HDPool01.service: Main process exited, code=exited, status=1/FAILURE
Feb 28 15:46:15 pve01 zpool[280083]: cannot import 'HDPool01': no such pool available
Feb 28 15:46:15 pve01 systemd[1]: Starting zfs-import@HDPool01.service - Import ZFS pool HDPool01...
Jan 13 20:25:17 pve01 systemd[1]: Failed to start zfs-import@HDPool01.service - Import ZFS pool HDPool01.
Jan 13 20:25:17 pve01 systemd[1]: zfs-import@HDPool01.service: Failed with result 'exit-code'.
Jan 13 20:25:17 pve01 systemd[1]: zfs-import@HDPool01.service: Main process exited, code=exited, status=1/FAILURE
Jan 13 20:25:17 pve01 zpool[2253]: cannot import 'HDPool01': no such pool available
Jan 13 20:25:17 pve01 systemd[1]: Starting zfs-import@HDPool01.service - Import ZFS pool HDPool01...
^C
```

`HDPool01` ZFS 池已经删除，但 `systemd` 仍然尝试导入它，导致 `zfs-import@HDPool01.service` 失败。可以通过以下步骤清理这个残留的 systemd 服务：

# 检查 systemd 服务状态

```
root@pve01 ~ % systemctl status zfs-import@HDPool01.service 

× zfs-import@HDPool01.service - Import ZFS pool HDPool01
     Loaded: loaded (/lib/systemd/system/zfs-import@.service; enabled; preset: enabled)
     Active: failed (Result: exit-code) since Sat 2025-03-15 13:58:20 CST; 4min 27s ago
       Docs: man:zpool(8)
    Process: 2193 ExecStart=/sbin/zpool import -N -d /dev/disk/by-id -o cachefile=none HDPool01 (code=exited, status=1/FAILURE)
   Main PID: 2193 (code=exited, status=1/FAILURE)
        CPU: 87ms

Mar 15 13:58:20 pve01 systemd[1]: Starting zfs-import@HDPool01.service - Import ZFS pool HDPool01...
Mar 15 13:58:20 pve01 zpool[2193]: cannot import 'HDPool01': no such pool available
Mar 15 13:58:20 pve01 systemd[1]: zfs-import@HDPool01.service: Main process exited, code=exited, status=1/FAILURE
Mar 15 13:58:20 pve01 systemd[1]: zfs-import@HDPool01.service: Failed with result 'exit-code'.
Mar 15 13:58:20 pve01 systemd[1]: Failed to start zfs-import@HDPool01.service - Import ZFS pool HDPool01.
```

显示 `enabled`，说明它仍然会在启动时尝试加载。

# 禁用并停止该服务

```bash
systemctl disable zfs-import@HDPool01.service
systemctl stop zfs-import@HDPool01.service
```

# 检查并移除 `zfs-import-cache`

ZFS 可能仍然缓存了旧的池信息：
```bash
rm -f /etc/zfs/zpool.cache
```
然后重新生成：
```bash
zpool set cachefile=/etc/zfs/zpool.cache $(zpool list -Ho name)
```
如果 `zpool list` 没有输出，那说明已经没有可用的池了，可以跳过这一步。

# 重启 `zfs-import.target`
```bash
systemctl restart zfs-import.target
```

# 检查 systemd 依赖项
有时 `zfs-import@HDPool01.service` 可能是其他服务的依赖项，查看所有相关 ZFS 服务：

```
root@pve01 /etc/zfs % systemctl list-units --type=service | grep zfs

  zfs-import-cache.service                              loaded active exited  Import ZFS pools by cache file
  zfs-import-scan.service                               loaded active exited  Import ZFS pools by device scanning
● zfs-import@HDPool01.service                           loaded failed failed  Import ZFS pool HDPool01
  zfs-import@tank.service                               loaded active exited  Import ZFS pool tank
  zfs-mount.service                                     loaded active exited  Mount ZFS filesystems
  zfs-share.service                                     loaded active exited  ZFS file system shares
  zfs-volume-wait.service                               loaded active exited  Wait for ZFS Volume (zvol) links in /dev
  zfs-zed.service                                       loaded active running ZFS Event Daemon (zed)
```

如果 `zfs.target` 仍然依赖 `HDPool01`，可以尝试重新加载：

```bash
systemctl daemon-reload
systemctl reset-failed
```

# 再次确认 systemd 依赖项

```
root@pve01 /etc/zfs % systemctl list-units --type=service | grep zfs

  zfs-import-cache.service                              loaded active     exited        Import ZFS pools by cache file
  zfs-import-scan.service                               loaded active     exited        Import ZFS pools by device scanning
  zfs-import@tank.service                               loaded active     exited        Import ZFS pool tank
  zfs-mount.service                                     loaded active     exited        Mount ZFS filesystems
  zfs-share.service                                     loaded active     exited        ZFS file system shares
  zfs-volume-wait.service                               loaded active     exited        Wait for ZFS Volume (zvol) links in /dev
  zfs-zed.service                                       loaded active     running       ZFS Event Daemon (zed)
```