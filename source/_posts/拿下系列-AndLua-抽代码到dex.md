---
title: 拿下系列:AndLua+抽代码到dex
date: 2022-06-28 03:40:20
categories:
  - 逆向
tags:
  - 拿下
  - AndroLua
  - Lua
cover: https://s2.loli.net/2022/06/28/l3PFWxeEKMpQIBV.png
description: 轻松破解andlua的抽代码到dex
url_title: andlua_fuck_1
---

## 前言

最近想新开一个拿下系列，专门研究下androlua逆向相关的东西，正好之前也有提到过AndLua+的抽代码到dex，先拿这个开刀。

## 样本分析

在AndLua+的设置里，可以开启抽代码到dex的开关，开启之后所有的lua文件都会在编译后抽离放入dex里面。

新建一个项目随便写点东西，在打包就可以拿到样本去分析了。

用jadx打开，看样本差不多是这样的

![这是样本](https://s2.loli.net/2022/06/28/wSfnOdiDrzXcUq5.png)

因为这个项目里面没有塞其他的文件，都是lua文件，所以assets目录没了。毕竟lua文件都被抽取到dex里了嘛。

基于对AndroLua系app的共通性，我们直奔LuaActivity去，不过andlua作者改了点东西，他把LuaActivity类移动到`com.andlua.LuaActivity`去了。

问题不大，直接上来跟踪onCreate，一下子就发现了点东西

```java
/** decompiled for jadx */
Intent intent = getIntent();
String string = intent.getExtras().getString("LuaCode");
Object[] objArr = (Object[]) intent.getSerializableExtra(ARG);
if (objArr == null) {
   objArr = new Object[0];
}
//省略无用代码
try {
    doString("require \"import\"import \"com.andlua.R\"", new Object[0]);

    doString(new StringBuffer().append(new StringBuffer().append("function andlua_main(...)").append(string.replaceAll("\"...\"...\"...\"", " ").replaceAll("'...'...'...'", "\"")).toString()).append("end").toString(), new Object[0]);

    runFunc("andlua_main", objArr);
    //省略无用代码 
    if (!this.pageName.equals("main")) {
        runFunc("main", objArr);
    }
    runFunc(this.pageName, objArr);
    Object[] objArr2 = new Object[1];
    objArr2[0] = bundle;
    runFunc("onCreate", objArr2);
    //省略无用代码
    } catch (Exception e) {
    //省略无用代码
}


```

看反编译的代码，首先从当前活动的intent接收到了一个为String类型的值，key为`LuaCode`，不出所料就是可运行的代码了。

接下来先运行了一次doString方法，导入了`import`这个基于androlua+的lua软件基本都会用到的库，再导入了`com.andlua.R`这个类。

> 这里提示一下，由于andlua+和androlua+一样，打包方式都是基于自身的apk去打包，并不会重新编译resource资源，所以这个R类是共通的，有兴趣的话我可以单独开一篇详解androlua+的打包。

下面这两句就比较重要了，先new了一个StringBuffer，然后添加了一串文本`"function andlua_main(...)"`，再往下看，对获取到的`LuaCode`做了两次替换,替换完了也添加进去StringBuffer，最后添加一个`end`。这段也很好理解，就是把需要运行的代码做了个替换，然后包裹成诸如下面的形式

```lua
function andlua_main(...) code end
```

注意这是全局函数，定义之后会被注册在全局表里面，也就是可以使用luajava提供的全局值操作能力去操作它，例如`runFunc`就是使用了这样的api。

下面这句直接就调用了刚才定义的函数，也就是运行了代码。

我们先分析onCreate到这里，现在我们就知道了几个信息

- 直接运行的代码很可能是明文代码，否则不应该对代码进行替换
- onCreate里面不涉及到代码的解密操作，实际的代码早就在进入活动前就被拿出来（解密）了

接下来我们查看AndroidManifest.xml，很快就找到了主活动类的位置

```xml
<activity android:name="com.andlua.Main">
  <intent-filter>
    <action android:name="android.intent.action.MAIN"/>
    <category android:name="android.intent.category.LAUNCHER"/>
   </intent-filter>
</activity>
```

点进去`com.andlua.Main`分析一下，还是先看onCreate。

```java
/** decompiled for jadx */
super.onCreate(bundle);
try {
      unApk("assets", getFilesDir().getAbsolutePath());
      unApk("lua", getDir("lua", 0).getAbsolutePath());
} catch (IOException e) {

}
this.LuaDir = getFilesDir().getAbsolutePath();
new AndluaTool();
try {
  Intent intent = new Intent(this, Class.forName("com.andlua.LuaActivity"));
  intent.putExtra("name", "");
  intent.putExtra("LuaCode", AndluaTool.getLuaCode("main"));
  if (Build.VERSION.SDK_INT >= 21) {
      intent.addFlags(524288);
      intent.addFlags(134217728);
  }
  intent.setData(Uri.parse(""));
  startActivity(intent);
  overridePendingTransition(0, 0);
  finish();
} catch (ClassNotFoundException e2) {
  throw new NoClassDefFoundError(e2.getMessage());
}
```

相信眼尖的人一下就看出来这句代码了`intent.putExtra("LuaCode", AndluaTool.getLuaCode("main"));`

可以看到就是调用了AndluaTool的一个getLuaCode方法，我们点进去这个类去看下方法实现

```java
/** decompiled for jadx */
public static String getLuaCode(String str) {
    try {
        Class<?> cls = Class.forName(new StringBuffer().append("com.andlua.andlua_").append(str).toString());
        Field[] declaredFields = cls.getDeclaredFields();
        if (declaredFields.length <= 0) {
            return "";
        }
        Field field = declaredFields[0];
        field.setAccessible(true);
        return decrypt(field.get(cls.newInstance()).toString(), str.length());
    } catch (Exception e) {
        return "Cannot find class";
    }
}
```

逻辑很简单，就是动态加载一个类，前缀为`com.andlua.andlua_`，后面跟着传进来的str，在获取类的所有字段（包括私有)。
如果获取到的数组为空，就返回空字符，这个我们可以先猜测是因为这个代加载的类里没有对于的代码就返回空（不确定）。
不为空的话就获取第一个字段，并且新建这个类的对象去获取这个字段的值并且用toString转为String，同时调用`decrypt(String,int)`这个方法传入刚才toString的对象和传进来str的长度并且返回他的值。

到这里，在结合刚才Main类的分析，基本能判断出这个getLuaCode需要传的就是需要加载的lua的文件名。

下面继续分析`decrypt(String,int)`系列的实现，这里我准备贴出来整个类的代码，一段段贴太杂了。。。

```java
/** decompiled for jadx */
public class AndluaTool {
    private static final String KEY_AES = "AES";

    public static String getLuaCode(String str) {
        //省略代码
    }

    public static String d(String str) {
        return new StringBuffer().append(str.substring(0, LuaActivity.mWidthF * 2)).append(str.substring(str.length() - (LuaActivity.mWidthF * 2), str.length())).toString();
    }

    public static String decrypt(String str, int i) {
        return decrypt(str, d(String.valueOf(((long) (i + LuaActivity.mWidthF)) * Long.parseLong(decrypt(Main.F, "0000000000000000")))));
    }

    private static String decrypt(String str, String str2) {
        if (str2 == null || str2.length() != 16) {
            return "";
        }
        try {
            SecretKeySpec secretKeySpec = new SecretKeySpec(str2.getBytes(), KEY_AES);
            Cipher instance = Cipher.getInstance(KEY_AES);
            instance.init(2, secretKeySpec);
            return new String(instance.doFinal(hex2byte(str)));
        } catch (Exception e) {
            return "";
        }
    }

    public static byte[] hex2byte(String str) {
        if (str == null) {
            return null;
        }
        int length = str.length();
        if (length % 2 == 1) {
            return null;
        }
        byte[] bArr = new byte[(length / 2)];
        for (int i = 0; i != length / 2; i++) {
            bArr[i] = (byte) Integer.parseInt(str.substring(i * 2, (i * 2) + 2), 16);
        }
        return bArr;
    }

    public static String byte2hex(byte[] bArr) {
        /* 代码省略了 因为其实没调用的地方 */
    }
}
```

可以看到，最核心的解密方法是`decrypt(String, String)`，前面我们看到的`decrypt(String,int)`也是调用了这个方法，但是对传的第二个参数做了层层运算。从这里我们也可以判断出第二个参数就是密钥，第一个参数就是待解密的字符串。

下面来分析下`decrypt(String,int)`里面对第二个参数(密钥)的处理。

```java
decrypt(str,
d(
  String.valueOf(
    ((long) (i + LuaActivity.mWidthF)) * 
    Long.parseLong(
      decrypt(
        Main.F, "0000000000000000"))
  )
))
```

这样一格式化，是不是感觉好分析多了？
这个密钥就是对传进来的i，加上了一个LuaActivity的mWidthF，然后再乘以对Main.F的解密出来的值（转成Long）

通过查看这两个字段的定义，发现都是`public static final`常量值，其中mWidthF的值为`int mWidthF = 4`,F的值为`String F = "BF26AFC25EF730B449BFDFD95A6F0373";`

所以上面的这段代码也等价于下面的代码

```java
decrypt(str,
d(
  String.valueOf(
    ((long) (i + 4)) * 
    Long.parseLong(
      decrypt("BF26AFC25EF730B449BFDFD95A6F0373", "0000000000000000"))
  )
))
```

是不是瞬间感觉拉胯了？所以这就是为什么我要先做这东西的原因。。。

这样把常量替换了之后可以发现计算密钥右边相乘的值其实是不变的，也就是我们还可以用上面的代码跑一下计算出来右边表达式的值。即为`282658702528265`

再来一次常量替换，就舒服多了

```java
decrypt(str,
d(
  String.valueOf(
    ((long) (i + 4)) * 282658702528265l
  )
))
```

在分析下`decrypt(String,String)`,
可以看到用我们的密钥创建了一个SecretKeySpec类，并且做了一些初始化。最后对传入的字符串做一次`hex2byte`之后放入Cipher类实例中去参与解密并返回解密后的值。

至此，基本把样本分析完成了。下面就是写反编译代码的部分，其实看到这里你完全可以自己动手写一个反编译的实现，研究样本我会提供在文章的底部。

## 反编译代码实现

这部分没啥好说的，照抄AndluaTool的实现都可以，只不过要注意在LuaActivity里面运行的时候对代码做了一次替换，这个别忘记了。下面贴出来我用kotlin的实现。

```kotlin
import javax.crypto.Cipher
import javax.crypto.spec.SecretKeySpec

//aes解密
fun aesDecrypt(content: String, password: String): String {
    val secretKeySpec = SecretKeySpec(password.encodeToByteArray(), "AES")
    val instance = Cipher.getInstance("AES")
    instance.init(2, secretKeySpec)
    return String(instance.doFinal(hex2byte(content)))
}

//hex转byte
fun hex2byte(source: String): ByteArray {
    val length: Int = source.length
    if (length % 2 == 1) {
        return ByteArray(0)
    }
    val bArr = ByteArray(length / 2)
    for (i in 0 until length / 2) {
        bArr[i] = source.substring(i * 2, i * 2 + 2).toInt(16).toByte()
    }
    return bArr
}

//替换内容实现
fun replaceContent(source: String) = source.replace("\"...\"...\"...\"", " ").replace("'...'...'...'", "\"")

//解密主函数
fun decodeWithClass(clazz: Class<*>): String {
    val clazzName = clazz.name
    val prefix = "com.andlua.andlua_"
    if (!clazzName.startsWith(prefix)) {
        error("The class isn't be compiled for andlua")
    }
    val fileName = clazzName.substring(prefix.length)
    val fileNameLength = fileName.length
    val targetField = clazz.declaredFields[0].apply {
        isAccessible = true
    }
    val encodedCode = targetField.get(clazz.newInstance()).toString()
    return replaceContent(aesDecrypt(encodedCode,((fileNameLength + 4) * 282658702528265L).toString()))
}

fun main() {
    //这里是我们要反编译代码的类，可以替换成你自己的类名
    //需要注意的是类需要在加载环境里面，对于电脑上的jvm可以dex2jar之后在加载
    println(decodeWithClass(Class.forName("com.andlua.andlua_main")))
}
```

## 结语

今天好好折腾了一下这个拉胯的不行的抽代码到dex的破解，这种所谓加密加固可以说是只防小白了。。。

不过考虑到andlua现在也差不多g了，那只能说是好似了。

样本下载地址：[https://wwc.lanzoul.com/iZXEV0716nyh](https://wwc.lanzoul.com/iZXEV0716nyh)
