---
title: 在 Windows 上为 git 设置 ssh 代理
date: 2025-01-02 08:49:05
categories: 教程
tags: 教程
url_title: set-ssh-proxy-for-git
---

## 问题

最近神秘高墙都开始阻断 github 的 ssh 连接了，导致我无法推送源码到 github 上。

![d327b203b803582ee704888f81fac9c5.png](https://s2.loli.net/2025/01/02/FIuhVcRDJtXHoiM.png)

针对这种问题，一般都是配置个代理解决。

google 搜一下，一般给出在 `~/.ssh/config` 里面添加如下配置：

```bash
ProxyCommand connect -S 127.0.0.1:10801 -a none %h %p

Host github.com
  User git
  Port 22
  Hostname github.com
  # 注意修改路径为你的路径
  IdentityFile "C:\Users\One\.ssh\id_rsa"
  TCPKeepAlive yes

Host ssh.github.com
  User git
  Port 443
  Hostname ssh.github.com
  # 注意修改路径为你的路径
  IdentityFile "C:\Users\One\.ssh\id_rsa"
  TCPKeepAlive yes
```

但是，这类配置只能在 `git bash` 里面使用，在 `powershell` 里面是无法使用的。

在 `VS Code` 和 `Windows Terminal` 默认都是用的 `powershell` ，按照上面配置完后你试一下大概率会出现如下错误：

```powershell
CreateProcessW failed error:2
posix_spawnp: No such file or directory
```

## 解决方案

解决方案也很简单，我们只需要手动指定 `connect.exe` 的地址即可。

```bash
ProxyCommand "C:\Program Files\Git\mingw64\bin\connect.exe" -S 127.0.0.1:7890 -a none %h %p

Host github.com
  User git
  Port 22
  Hostname github.com
  # 注意修改路径为你的路径
  IdentityFile "C:\Users\One\.ssh\id_rsa"
  TCPKeepAlive yes

Host ssh.github.com
  User git
  Port 443
  Hostname ssh.github.com
  # 注意修改路径为你的路径
  IdentityFile "C:\Users\One\.ssh\id_rsa"
  TCPKeepAlive yes
```

`connect.exe` 的地址一般在：`<你的 git 安装目录>\mingw64\bin\connect.exe`。

完成后，可以继续愉快的使用了。