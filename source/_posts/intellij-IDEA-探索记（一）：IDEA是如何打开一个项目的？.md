---
title: intellij IDEA 源码探索记（一）：IDEA是如何打开一个项目的？(持续更新中)
date: 2022-10-20 11:21:21
categories:
   - 折腾
   
tags:
   - 源码
   - 阅读
   - 学习
   - java
   - kotlin
   - idea
---


### 前言

最近由于项目需要，就去尝试阅读了下idea的源码（已经git clone下来了）。s确实是没想到idea的项目架构之庞大，故就准备开个新坑，去尝试解析idea中的某些功能背后的实现原理。

>（如果没有例外声明，该系列所基于的idea源码版本为212.3116.29，可以自己去github上下载相关源码）

### 从启动程序开始

#### 寻找入口类

无论怎么样，启动一个应用程序总是会有入口，idea这种大型ide也不例外。

不过idea的代码实在是太庞大了，总不能一个个的找吧？其实有个简单的办法。

用idea打开idea的源码，在等待漫长的项目准备工作后，后面就可以开始运行了。

此时不要直接运行，编辑一下运行配置（Run > Edit Configurations)

![运行配置编辑界面](https://s2.loli.net/2022/10/20/ymC5XvSF2rikTOU.png)

可以看到默认的运行配置就有几种，直接看启动jvm参数后面附的类

`com.intellij.idea.Main`

这样就找到了标准的入口类，只要启动了带图形界面的idea就一定会执行这个类。

#### 启动IDEA

跳转到这个类，查看源码，我们直接看main方法

```java
 public static void main(String[] args) {
    LinkedHashMap<String, Long> startupTimings = new LinkedHashMap<>(6); //启动耗时记录？
    startupTimings.put("startup begin", System.nanoTime());

    if (args.length == 1 && "%f".equals(args[0])) {
      //noinspection SSBasedInspection
      args = new String[0]; //置空arg
    }

    if (args.length == 1 && args[0].startsWith(JetBrainsProtocolHandler.PROTOCOL)) {
      //这个protocol本质就是scheme协议的url，这里是处理了，不过我们不关心这里，直接启动软糯大概率是没有arg的
      JetBrainsProtocolHandler.processJetBrainsLauncherParameters(args[0]);
      //noinspection SSBasedInspection
      args = new String[0];
    }
    
    //这里省略一下，本质就是设置idea的模式，无头模式，轻量编辑模式，是否命令行打开的模式
    setFlags(args);

    try {
      //开始启动类
      bootstrap(args, startupTimings);
    }
    catch (Throwable t) {
      //启动失败弹出错误窗口
      showMessage(BootstrapBundle.message("bootstrap.error.title.start.failed"), t);
      System.exit(STARTUP_EXCEPTION);
    }
  }

```

继续查看`bootstrap`方法

``` java
private static void bootstrap(String[] args, LinkedHashMap<String, Long> startupTimings) throws Throwable {
    //加载属性配置？
    startupTimings.put("properties loading", System.nanoTime());
    PathManager.loadProperties();
    
    startupTimings.put("plugin updates install", System.nanoTime());
    // this check must be performed before system directories are locked
    if (!isCommandLine || Boolean.getBoolean(FORCE_PLUGIN_UPDATES)) {
      //安装插件更新
      boolean configImportNeeded = !isHeadless() && !Files.exists(Path.of(PathManager.getConfigPath()));
      if (!configImportNeeded) {
        installPluginUpdates();
      }
    }

    startupTimings.put("classloader init", System.nanoTime());
    //配置ide上下文的classloader（加载ide的其他jar库进去等）
    PathClassLoader newClassLoader = BootstrapClassLoaderUtil.initClassLoader();
    Thread.currentThread().setContextClassLoader(newClassLoader);

    startupTimings.put("MainRunner search", System.nanoTime());
    //这里又加载了一个main类，注意用的是newclassloader
    Class<?> mainClass = newClassLoader.loadClassInsideSelf(MAIN_RUNNER_CLASS_NAME, true);
    if (mainClass == null) {
      throw new ClassNotFoundException(MAIN_RUNNER_CLASS_NAME);
    }

    WindowsCommandLineProcessor.ourMainRunnerClass = mainClass;
    //反射调用方法启动
    MethodHandles.lookup()
      .findStatic(mainClass, "start", MethodType.methodType(void.class, String.class, String[].class, LinkedHashMap.class))
      .invokeExact(Main.class.getName() + "Impl", args, startupTimings);
  }
```


