---
title: 魅族 Pro5 安装 Ubuntu Touch
date: 2023-03-18 15:44:23
categories:
  - 折腾
tags:
  - 魅族
  - Ubuntu
  - Android
  - 刷机
description: 手机体验安装 Linux 系统
url_title: meizu_pro5_install_ubuntu_touch
---

## 前言

最近闲的无聊，看到了有 10 多块钱的 WIFI 棒，骁龙 410+512/1G的组合，可以刷很多东西，Linux 啥的，看着就很有意思。

本来是想直接买一个弄弄，但发现这个东西有几个缺点：

1. 长时间运行发热量大
2. 没有电池
3. 配置低下

再三思索下，我取消了买 WIFI 棒的想法。但是另一个大胆的想法在我脑海里浮现：为什么不手机直接刷 Linux？

于是我就开始疯狂百度，搜索能刷 Linux 的系统，能刷的手机，最后发现了 Ubuntu Touch。

再三物色之后，我选择了用魅族 Pro5 来刷 Ubuntu Touch。原因有几个：

1. 4+64G也就200多，吊打上面 wifi 棒的配置
2. 一部手机可比一个 wifi 棒全能多了
3. 相比其他支持 Ubuntu Touch 的手机，Pro5 的性价比高。200多出头 CPU 也有骁龙 625 甚至是骁龙 660 的体验
4. ~~白色面板好看~~

**Tips: 本文默认你有一定的动手基础，并且下面的操作可能会导致手机无法正常使用，出现各种不可预知的问题，我不对此负责。**

## 解锁 Bootloader

要想折腾机子，解锁 Bootloader 是必不可少的。但魅族 Pro5 的 Bootloader 是锁定的，用的还是三星猎户座的 CPU，解锁还是比较麻烦的。

一番查找下，我找到了几个教程[^1][^2][^3]。
基本都是把手机刷到国际版系统，然后再解锁 Bootloader。

我们要刷的是 Ubuntu Touch，所以我们需要**刷到国际版的系统**再解锁 Bootloader，当然我们不能直接刷到国际版的系统，需要先降级系统获取完整 Root 了之后才能刷入国际版系统。

接下来我们开始一步步的解锁 Bootloader。

### 降级到 Flyme 5.x

首先我们下载旧版本的系统，这里是官方的[下载链接](http://download.meizu.com/Firmware/Flyme/PRO_5/5.1.3.0/cn/20160130134300/50c60f50/update.zip)。

下载完了之后把前面的 ROM 文件名命名为 "update.zip"，再把它放在手机内置存储根目录。然后同时按住**音量增加键和电源键**，等待几秒，直到手机重启到 Recovery。

如果看到这个界面（曝光调低了没显示出来手机本体...），那就是进去了。**记得两个选项都要勾选！！！** 接下来点击开始按钮开始刷机。

![1679129724056.jpg.jpg](https://s2.loli.net/2023/03/18/e6zdoJKGip7q1SO.jpg)

如果刷进去降级了之后一进去开始界面就黑屏的话，考虑升级下 ROM 包l。[这里](https://blog.csdn.net/liyuming566/article/details/82634452)有一些参考的ROM的链接。

### 取得自带的 Root 权限

~~刷机完成后，我们进入刚刚刷入的系统，登录 Flyme 帐户，然后，在“设置-指纹和安全”里开启系统的 Root 权限。Root 权限开启后，手机会自动重启应用更改。~~

现在 Flyme 旧版本没法直接申请 ROOT力，还得需要先更新 Flyme 账户，然后在应用下面的步骤。

点[这里](https://wwdv.lanzoul.com/ixqKn0qg14kd)下载Flyme 账户新版本安装包。安装后就可以继续了

登录 Flyme 帐户，然后，在“设置-指纹和安全”里开启系统的 Root 权限。Root 权限开启后，手机会自动重启应用更改。

![S30318-232337.jpg](https://s2.loli.net/2023/03/18/k6gsviTEh7P5fBl.jpg)

### 安装 SuperSU

下载 SuperSU 2.7.9版本。你可以自己去寻找相关版本，或者点[这里](https://supersu.cn.uptodown.com/android/download/1310131)下载。

安装后打开 SuperSU，选择“极客”模式并进入，SuperSU 将提示你更新二进制文件，以“常规方式”安装即可。在安装二进制文件的过程中，SuperSU 会申请 Root 权限，同意申请即可。

![S30318-232406.jpg](https://s2.loli.net/2023/03/18/uj4mWBvYilXb39K.jpg)

安装二进制文件完成后请重启手机应用更改。

### 安装 BusyBox

下载[BusyBox](https://github.com/meefik/busybox/releases/download/1.30.1/busybox-1.30.1-41.apk)，打开软件后同意 ROOT 权限，并且点击下面的 Install 按钮。

如果安装无误，结果应该是这样的：

![S30319-241144.jpg](https://s2.loli.net/2023/03/19/uKiPc6CDJFtx7vA.jpg)

### 在 RootBrowser 上操作

[下载](https://apkpure.com/root-browser/com.jrummy.root.browserfree/download/23600-APK)安装并打开RootBrowser，导航至以下目录：

> /dev/block/platform/15570000.ufs/by-name/

![S30319-241434.jpg](https://s2.loli.net/2023/03/19/lSTUoGzFwhqXyDv.jpg)

找到文件：proinfo，点击文件，选择“Open as…”。

![S30319-241438.jpg](https://s2.loli.net/2023/03/19/mDOULlfyzihIYbC.jpg)

选择“Text file”

![S30319-241444.jpg](https://s2.loli.net/2023/03/19/Mum2HEUNowKsTZA.jpg)

再选择“RB Text Editor”。

![S30319-241501.jpg](https://s2.loli.net/2023/03/19/kfiLs2ov4HP9rYA.jpg)

这期间，RootBrowser 将申请系统的 Root 权限，请同意申请。

打开文件后在编辑框里找到以下行：

`machine_type=M576_mobile_public`

将其改为：

`machine_type=M576_intl_official`

如下：

![S30319-241954.jpg](https://s2.loli.net/2023/03/19/1CkR9VYnFsTXfp7.jpg)

完成之后请保存更改，然后退出 RootBrowser，重启手机。

手机重启过之后，请再次在 RootBrowser 里查看 proinfo 的状态。如果“machine_type=”后的文本为“M576_intl_official”，则说明操作成功了。

### 刷入国际版系统

点[这里](https://forum.xda-developers.com/t/tutorial-unlock-the-bootloader-of-meizu-pro-5.3303127/)下载国际版Flyme刷机包

将国际版 Flyme 的刷机包命名为“update.zip”，将其放置在手机内置存储的根目录。

同时按住手机的音量增加键和电源键，等待数秒，直至手机重启到 Recovery。

刷机的步骤和上面基本一致，不再详细描述。

### 解锁 Bootloader

接下来就需要用上电脑了。

同时按住手机的音量减小键和电源键，等待数秒，直到重启到 Fastboot 模式。

将手机通过数据线连接到计算机（请保证 Fastboot 驱动已经正确安装），然后打开终端执行下面的命令（怎么配置到全局环境啥的我不会，自己去找教程）

```sh
fastboot devices
```

如果上面的指令没有输出类似这样的东西，请检查你和手机之间连接。

`xxxxxxxxxx    fastboot`

然后执行指令解锁 Bootloader

```sh
fastboot oem unlock
```

如果执行命令后输出类似这样的，那就可能是成功了

```text
OKAY [  0.005s]
Finished. Total time: 0.005s
```

再按一次手机的音量减小键和电源键，重启到 FastBoot 模式，如果显示有`unlocked`的字样，那就是解锁 Bootloader 成功了。

![~5_1L_PNV__UBJ_BERQGXVM.jpg](https://s2.loli.net/2023/03/19/BZ2SgpIJrVHDnax.jpg)

## 刷入 TeamwinRecovery

从[这里](https://drive.google.com/file/d/1T30ug5TQqzRxZiKsFk3IhpR5c218N4Pc/view
?usp=sharing)下载 TWRP。

然后执行这个指令刷入 TWRP

```sh
fastboot flash recovery TWRP_3.0_m86.img #替换成你的rec路径
```

如果成功，你应该能看到类似的输出

```text
Sending 'recovery' (23096 KB)                      OKAY [  0.544s]
Writing 'recovery'                                 OKAY [  0.248s]
Finished. Total time: 0.795s
```

## 刷入 Ubuntu Touch

感谢强大的酷友，这里直接就有包给刷了！

[真-魅族旗舰-Pro 5爆刷ubuntu touch，体验另类荣光](https://www.coolapk.com/feed/22297272?shareKey=MjNlZTM0OGExMDQ3NjQxNWZkZGM~&shareFrom=com.coolapk.market_13.0.2)

为了避免什么问题，我这就不贴原文了。照着他的操作就能刷到 Ubunt Touch了。

## 后记

今天折腾半天弄出来这篇博文，总算是把这台手机刷到 Linux 了。有时间可能还会在写写这系统能干什么（当然我才刚刷也不是太知道能干啥）

## 其他

### 常见问题

1. 为什么 proinfo 没改好？

    检查一下设置里的 ROOT 权限管理，也给上 BusyBox，RootBrowser 权限

### 参考链接

[^1]: [[TUTORIAL] Change region/ID to International in Meizu Pro 5](https://forum.xda-developers.com/t/tutorial-change-region-id-to-international-in-meizu-pro-5.3323883/)

[^2]: [魅族pro5解bl锁root刷面具，强行续命提高实用性](https://www.bilibili.com/read/cv19395437)

[^3]: [魅族PRO 5安装Ubuntu Touch系统](https://unixetc.com/post/meizu-pro-5-installs-ubuntu-touch-system/)

[^4]: [[TUTORIAL] Unlock the bootloader of Meizu PRO 5](https://forum.xda-developers.com/t/tutorial-unlock-the-bootloader-of-meizu-pro-5.3303127/)

[^5]: [Meizu Pro 5 Flyme OS To Ubuntu Touch + modem Update + Fingerprint Function.](https://forums.ubports.com/topic/2755/meizu-pro-5-flyme-os-to-ubuntu-touch-modem-update-fingerprint-function)

[^6]: [真-魅族旗舰-Pro 5爆刷ubuntu touch，体验另类荣光](https://www.coolapk.com/feed/22297272?shareKey=MjNlZTM0OGExMDQ3NjQxNWZkZGM~&shareFrom=com.coolapk.market_13.0.2)