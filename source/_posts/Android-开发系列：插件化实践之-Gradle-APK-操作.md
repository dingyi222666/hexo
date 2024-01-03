---
title: Android-开发系列：插件化实践之 Gradle APK 重命名
date: 2024-01-03 21:32:27
categories:
  - 学习
tags:
  - Android
  - Kotlin
  - Gradle
description: 折腾几小时 Gradle, 终于实现了一个很简单的需求。。。
url_title: android_develop_series_gradle_apk_operation
---

## 背景

最近脑子一热，又想捡回来 MyLuaApp，于是开了这个新坑 [AndroCode](https://github.com/dingyi222666/AndroCode)。

准备在里面实现加载插件，也就是插件化的效果。

在开发的时候，想测试从 apk 里加载插件的效果，但是又不想手动复制插件的 apk 包，到项目的 assets 目录下。

于是想到了用 Gradle，在打插件包的时候把插件包的 apk ，自动复制到主项目的 assets 目录下。

## 实现

整体代码很简单，但是我自己摸索了几个小时之后，才弄出来。。

### 1. 遍历 `applicationVariants`，重命名 APK 输出名

```kotlin
android {
    //...
    applicationVariants.all {
        logger.lifecycle("Configure application variant $name")

        val appProject = project(":app")

        // 自定义后面复制apk 的输出路径
        val outputFileDir =
            "${appProject.projectDir}/src/main/assets/plugins"

        // 自定义文件名        
        val path = project.name + "-" +buildType.name + "-" +
                versionName + ".apk"

        outputs
            // 如果不去拿 internal 包里的类，这个 output 里面就没有 outputFileName 字段
            // default type don't have outputFileName field
            .map { it as com.android.build.gradle.internal.api.ApkVariantOutputImpl }
            .all { output ->
                output.outputFileName = path
                false
            }

    }
}
```

注意在遍历 outputs 之前需要把里面的输出转成内部类，否则会找不到 outputFileName 字段。

### 2. 复制 APK 到 assets 目录下

```kotlin
android {
    //...
    applicationVariants.all {
        // ...

   
        // 获取 app 模块的 preBuild 任务
        appProject.getTasksByName("pre${name.capitalized()}Build", true).forEach {
            it.apply {
                // 要求在打包 app 模块之前，先打包插件
                dependsOn(this@all.assembleProvider.get())
            }
        }

        // 配置当前变体的 assemble 任务，在完成后复制 APK 到 assets 目录下
        // 因为上面的依赖关系，就可以保证在复制后才开始打包 app 模块，保证 app 模块里打出来的包有我们这个插件 apk
        assembleProvider.configure {       
            doLast {
                copy {
                    this@all.outputs.forEach { file ->
                        copy {
                            from(file.outputFile)
                            into(outputFileDir)
                        }
                    }
                }
            }
        }

    }
}
```

上面的代码中我们在 app 模块的 preBuild 任务中配置要求依赖了 当前变体的 assemble 任务，这样在复制 APK 到 assets 目录下的时候，就保证了插件包的 apk 已经打好了。

然后在当前变体的 assemble 任务中，在完成后复制 APK 到 assets 目录下。

其实很简单的几十行代码，但是我查询了很多资料才完成了这个需求。。。下面贴上完整源代码：

```kotlin
android {
     applicationVariants.all {
        logger.lifecycle("Configure application variant $name")

        val appProject = project(":app")

        val outputFileDir =
            "${appProject.projectDir}/src/main/assets/plugins"

        val path = project.name + "-" +buildType.name + "-" +
                versionName + ".apk"

        outputs
            // default type don't have outputFileName field
            .map { it as com.android.build.gradle.internal.api.ApkVariantOutputImpl }
            .all { output ->
                output.outputFileName = path
                false
            }

        appProject.getTasksByName("pre${name.capitalized()}Build", true).forEach {
            it.apply {
                dependsOn(this@all.assembleProvider.get())
            }
        }

        assembleProvider.configure {
           
            doLast {
                copy {
                    this@all.outputs.forEach { file ->
                        copy {
                            from(file.outputFile)
                            into(outputFileDir)
                        }
                    }
                }
            }
        }
    }
}
```

## 总结

这是一个简单的需求，但是我花了几小时，查询了不少文档才实现的。。。


如果有更好的实现方式，欢迎留言。

## 参考

[^1]: [Android gradle plugin 8.1.0 change apk name](https://stackoverflow.com/questions/76788379/android-gradle-plugin-8-1-0-change-apk-name)

[^2]: [gradle在prebuild之前执行task](https://blog.csdn.net/vichild/article/details/72910326)

[^3]: [Android gradle配置生成的apk名称和存放位置](https://blog.csdn.net/u013855006/article/details/124440196)

[^4]: [AndroidStudio2021/3版 gradle7.0环境 自定义输出apk路径](https://www.cnblogs.com/loaderman/p/15213652.html)
