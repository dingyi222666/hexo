---
title: C语言学习笔记 (一)
date: 2022-07-01 04:56:19
categories:
    - 学习笔记
tags:
    - C语言
    - 学习
    - 笔记
---

## 前言

为什么我要学习C语言？主要还是感觉C无处不在，android的jni，lua的源码，以及java等等...
我迫切的需要学习这些底层的语言，来扩充我的知识面。

如不出意外，本系列笔记的内容均基于[该视频](https://www.bilibili.com/video/BV17s411N78s)的内容。

## 环境配置

大部分语言都需要配置环境，才能够正常的编译运行，c语言也不例外。

因为我只是来初学c的，所以就用了linux来配置环境了。

首先在虚拟机上安装好linux发行版，这里我选择的是ubuntu。
接下来安装好gcc等其他基础编译器

```shell
sudo apt-get install gcc g++ make
```

安装完成后，我们就可以编译运行c代码了。
但是直接使用vim来操作还是不太适合新手,再加上我是跑虚拟机的，主要都运行在windows，这里我们推荐用vscode的ssh-remote来操作

### 安装ssh-remote 插件

在宿主机的vscode中搜索并安装相关插件

![image.png](https://s2.loli.net/2022/07/01/9P5xL8IT6pcaSZ2.png)

接下来添加远程连接的系统，注意在这之前得配置好ssh服务，百度已经有很多教程这里就不描述了。

![image.png](https://s2.loli.net/2022/07/01/IQTrigcZsaVjdBk.png)

添加完之后点击地址右边的那个文件夹的图片，配置不出错的话就连接成功了。

这样在宿主机上也可以用vscode享受到虚拟机的操作环境，也可以安装各种插件，非常方便。

## Hello，World

把环境配置好了之后，用vscode连接上虚拟机的环境，新建一个study_c的文件夹，在新建一个hello_world.c的文件。接下来敲入如下代码

```c
#include <stdio.h>;

int main() {
  printf("Hello World\n");
  return 0;
}
```

在vscode上打开终端，不出意外的话打开的会是linux的终端。

![image.png](https://s2.loli.net/2022/07/01/2RWptGLIkKUCAVS.png)

用gcc编译，然后直接以可执行文件运行，可以看到成功输出了Hello，World！

![image.png](https://s2.loli.net/2022/07/01/tZ9JwvLqMDkHb1R.png)

很好，这就是我们的第一个c程序！
