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

### 课后扩展练习

看了下论坛里的[课后作业](https://fishc.com.cn/thread-66283-1-1.html)，好家伙...

不过都说让我们抄了，那问题不大，搜索一下就有了

直接搜可能搜不出来，这时候我们得缝合搜索，比如搜索`统计文件行数`,`遍历文件夹`来多次获取结果，再把他缝一起。

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <unistd.h>
#define MAX 256

long total;

int countLines(const char *filename);
int forEachDir(const char *dirpath);

int countLines(const char *filename)
{
  FILE *fp;
  int count = 0;
  int temp;
  if ((fp = fopen(filename, "r")) == NULL)
  {
    fprintf(stderr, "Can not open the file：%s\n", filename);
    return 0;
  }
  while ((temp = fgetc(fp)) != EOF)
  {
    if (temp == '\n')
    {
      count++;
    }
  }
  fclose(fp);
  return count;
}

int forEachDir(const char *dirpath)
{
  DIR *dir;
  char pathname[MAX];                //目录的全名，=当前目录名+子目录名
  if ((dir = opendir(dirpath)) == 0) //无法打开则跳过
  {
    printf("open %s failed!\n", dirpath);
    return -1;
  }

  struct dirent *stdir;

  while (1)
  {
    if ((stdir = readdir(dir)) == 0)
      break; //遍历完一整个文件夹就停止循环

    sprintf(pathname, "%s/%s", dirpath, stdir->d_name); //获得目录全名（当前目录名 + 子目录名）

    if (stdir->d_type == 8) //文件则输出
    {
      int length = strlen(stdir->d_name);
      if (strcmp((stdir->d_name) + (length - 2), ".c") == 0)
      {
        total += countLines(pathname);
      }
    }
    else // if(stdir->d_type == 4)//文件夹则递归进行下一轮，打开文件夹
    {
      if (!strcmp(stdir->d_name, ".") || !strcmp(stdir->d_name, ".."))
        continue;

      forEachDir(pathname);
    }
  }
  closedir(dir); //关闭目录
  return 0;
}

int main()
{
  char path[MAX] = ".";
  getcwd(path, sizeof(path));
  printf("计算中...\n");

  int success = forEachDir(path);
  if (success != 0)
  {
    printf("遍历文件失败");
    return -1;
  }
  printf("目前你总共写了 %ld 行代码！\n\n", total);
  pause();
  return 0;
}

```

上面的代码就是我缝出来的例子，自己也有写了一点，就感觉c语言的字符串处理真麻烦...我想念其他语言了。
