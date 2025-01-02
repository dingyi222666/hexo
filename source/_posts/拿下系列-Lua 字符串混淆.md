---
title: "拿下系列: Lua字符串混淆"
date: 2024-01-26 22:23:20
categories:
  - 逆向
  - 混淆
tags:
  - 拿下
  - AndroLua
  - Lua
description: 详解 Lua 字符串混淆
url_title: lua-string-obfuscation 
---

## 前言

最近看到我一年前写的 [lua-parser](https://github.com/dingyi222666/lua-parser)，再加上我在两年前曾经研究过 Lua 字符串混淆。但是今时不同往日了，这类混淆已经可以被轻松破解，所以我就有个想法，基于我上面提到的那个库，写那么个一两期教程来实现字符串混淆。后续也可能会加上字符串反混淆的教程。

**以下代码实现只兼容 `Lua 5.3`，不保证其他版本的兼容性。**

## 如何实现？

字符串混淆，在代码混淆这块是一个很常规技术。它的主要目的就是保护常量，防止反编译后能被直接读出来常量，并且也能有效干扰反编译人员分析。

对于 Lua 字符串混淆，使用词法分析进行混淆是一个很好的实现。使用正则表达式也可以，但是很难匹配出转义文本，如`'\''`，使用 AST(Abstract Syntax Tree) 单独实现反而显得过于麻烦（完全解析整个语法耗时更长），AST 更适合于整块代码的混淆实现。

词法分析的步骤是从左往右逐个字符地扫描源代码，产生一个个的单词符号。也就是说，它会对输入的字符流进行处理，再输出标记（token）。执行词法分析的程序即词法分析器器（lexical analyzer，简称lexer），也叫扫描器（scanner）。

使用词法分析器分析后，会输出相关的 token，一般可以分为以下几类：

- 关键字：如 for, function, ...
- 标识符：用来表示各种名字，如变量名、数组名和过程名
- 常量：数字，字符，字符串等其他类型的值，如 '123', 112.2
- 运算符：+、-、*、/、...
- 界符：逗号、分号、括号、换行、空白等其他符号

当然我们今天不是来学习怎么写 lexer 的，只是给大家科普一下这个东西。使用 lexer 我们就可以把下面这段代码

```lua
print("hello world")
```

变成

```text
NAME print
LPAREN (
STRING "hello world"
RPAREN )
```

形如这样的 token 流。眼尖你的一定发现了 `STRING`！没错，词法分析可以扫描出代码里的字符串，这样我们就可以对字符串进行处理了。

并且 lexer 相比正则表达式，它更简单和方便（在调用库的情况下），并且是严格扫描，不会像上面的正则表达式，去匹配可能会出问题。

决定了如何匹配并处理字符，我们还没有决定怎么处理字符串来达到混淆的效果。

在 lua 5.3 中，新增了 `utf8` 模块，可以使用 `utf8.char` 来将一个 unicode 字符码转换成对应的 utf8 字符。
这个方法允许传入多个 unicode 字符码，返回一个 utf8 字符，所以我们可以直接把字符串转换成 unicode 字符码，然后调用该方法来获取原字符串。

基础的思路都有了，我们现在就可以开始编写实现代码了。

## 最初实现

### 引入库

打开 Intellij IDEA, 新建一个 kotlin 项目，引入我上面的库：

```kotlin
implementation("io.github.dingyi222666:luaparser:1.0.1")
```

### Hello World

完成后面我们可以新建一个 stringFog.kt 文件，先写入如下代码

```kotlin
fun stringFog(code: String): String {
    val lexer = LuaLexer(code)

    val buffer = StringBuilder()

    for ((token, tokenText) in lexer) {
        if (token === LuaTokenTypes.STRING || token === LuaTokenTypes.LONG_STRING) {
            println("string!: $tokenText")
            buffer.append(tokenText)
        } else {
            buffer.append(tokenText)
        }
    }

    return buffer.toString()
}
```

在 `Main.kt` 中编写 `main` 函数，调用上面的代码：

```kotlin
fun main() {
    val source = "print(\"hello world\")"

    print(stringFog(source))
}

运行一下，你应该能看到如下输出：

```text
string!: "hello world"
print("hello world")
```

你看，使用 lexer 就是这么轻松简单。

上面的代码我们判断了 token 类型是否为 `LuaTokenTypes.STRING` 或者 `LuaTokenTypes.LONG_STRING`，如果是的话，就打印出对应的字符串。

这里的 `buffer` 是用于存储 `lexer` 扫描出的 token 对应代码的，等会我们在实现混淆的时候这个会很有用。

### 实现混淆

接下来我们来基于上面的思路，来实现混淆。

我们新建一个 `getObfuscationString` 方法，用于将字符串转换为混淆后的代码。

```kotlin
fun getObfuscationString(string: String): String {
    val decodedText = parseLuaString(string)

    return decodedText.map {
        // 转换成 unicode 字符码
        it.code
    }.joinToString(prefix = "utf8.char(", postfix = ")", separator = ",")
}
```

上面的 `parseLuaString` 是将 lexer 扫描出的纯字符串进行转义，转换成实际字符串值，如 `hello world` 会被转换为 `hello world`。

修改一下 `stringFog` 方法，将 `LuaTokenTypes.STRING` 或者 `LuaTokenTypes.LONG_STRING` 的处理方式改为调用 `getObfuscationString` 来处理。

```kotlin
fun stringFog(code: String): String {
    val lexer = LuaLexer(code)
    val buffer = StringBuilder()

    for ((token, tokenText) in lexer) {
        // 是否为字符串类型
        if (token === LuaTokenTypes.STRING || token === LuaTokenTypes.LONG_STRING) {
            buffer.append(getObfuscationString(tokenText))
        } else {
            buffer.append(tokenText)
        }
    }

    return buffer.toString()
}
```

重新运行一下 `main` 函数，看看结果：

```lua
print(utf8.char(104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100))
```

可以看到，我们的字符串已经被混淆了。

### 优化实现，支持长字符串

然而对于大字符串，因为 `utf8.char` 能传入的参数有限（100 个左右？），如果一股脑的全部传入，会导致运行时出现，所以需要对长字符串进行处理。

我们可以对字符串进行分割，然后将分割后的字符串进行处理，最后再合并起来。

```kotlin

fun getObfuscationString(string: String): String {
    val decodedText = parseLuaString(string)

    val codeList = decodedText.map {
        it.code
    }
    
    // 小于 60，直接返回原来的字符串
    if (codeList.size < 60) {
        return codeList.joinToString(prefix = "utf8.char(", postfix = ")", separator = ",")
    }

    // 大于 60，将字符串拆分成多个字符串，然后合并起来

    // 使用立即执行函数
    val buffer = StringBuilder("(function()")

    buffer.append("local tab = {}\n")

    codeList.chunked(decodedText.length / 60).forEach {
        buffer.append("table.insert(tab, ")
        buffer.append(it.joinToString(prefix = "utf8.char(", postfix = ")", separator = ","))
        buffer.append(");")
    }

    // concat 替代 lua 原有的 .. 连接符号，速度更快，然后我们立即执行
    buffer.append("return table.concat(tab)\nend)()")

    return buffer.toString()
}
```

修改 `main` 函数，更换一下我们测试的代码：

{% folding 新的测试代码实现 %}

```kotlin
fun main() {
    println(stringFog(code))
}

val code = """
        local a = "hello world, 你好 世界"
        local b = "hello world"
        local c = "hello world"
        local d = "safkljhdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjbjjjjjjjjjjjjjjjbjbjbjbjbjbjbjbjjjjj"
        local e = "safkljhdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjdjbjjjjjjjjjjjjjjjbjbjbjbjbjbjbjbjjjjj"
        local f = {b = b,c=c,a = a,d = d,e =e}
        
        print(f.a)
        print(f.b)
        print(f.c)
        print(f.d)
        print(f.e)
        print("xxxxxxxxxxxxx")
        print("xx")
        
        function a(t) 
            for i=1, 10 do
                t[i] = i
            end
           return t
        end  
        function c(s) return s end
        print(table.concat(a({}),","))
        print(c "hello world")
    """.trimIndent()

  

```

{% endfolding %}

在运行一下，应该会输出下面的代码：

{% folding 混淆后代码 %}

```lua
local a = utf8.char(104,101,108,108,111,32,119,111,114,108,100,44,32,20320,22909,32,19990,30028)
local b = utf8.char(104,101,108,108,111,32,119,111,114,108,100)
local c = utf8.char(104,101,108,108,111,32,119,111,114,108,100)
local d = (function()local tab = {}
table.insert(tab, utf8.char(115,97,102,107,108,106,104,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,98,106,106,106,106));table.insert(tab, utf8.char(106,106,106,106,106,106,106,106));table.insert(tab, utf8.char(106,106,106,98,106,98,106,98));table.insert(tab, utf8.char(106,98,106,98,106,98,106,98));table.insert(tab, utf8.char(106,98,106,106,106,106,106));return table.concat(tab)
end)()
local e = (function()local tab = {}
table.insert(tab, utf8.char(115,97,102,107,108,106,104,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,100,106,100,106,100));table.insert(tab, utf8.char(106,100,106,98,106,106,106,106));table.insert(tab, utf8.char(106,106,106,106,106,106,106,106));table.insert(tab, utf8.char(106,106,106,98,106,98,106,98));table.insert(tab, utf8.char(106,98,106,98,106,98,106,98));table.insert(tab, utf8.char(106,98,106,106,106,106,106));return table.concat(tab)
end)()
local f = {b = b,c=c,a = a,d = d,e =e}

print(f.a)
print(f.b)
print(f.c)
print(f.d)
print(f.e)
print(utf8.char(120,120,120,120,120,120,120,120,120,120,120,120,120))
print(utf8.char(120,120))

function a(t) 
    for i=1, 10 do
        t[i] = i
    end
   return t
end  
function c(s) return s end
print(table.concat(a({}),utf8.char(44)))
print(c utf8.char(104,101,108,108,111,32,119,111,114,108,100))
```

{% endfolding %}

这样就可以同时支持短字符串和长字符串。

## 优化实现，使用常量池

然而上面的代码出现了一堆 utf8.char 和其参数，很明显这太多了，我们可以考虑用常量池，简化输出并且优化重复的常量数字，下面是一些思路

由于每个字符串都可以被转换为 unicode 数组，我们可以考虑先将字符串转换为 unicode 数组，然后将这些数组的数字存储到常量池中，最后在代码中引用这些常量数字。

按照我上面的思路，生成出来的代码可能会是这样：

```lua
local int_pools = { [0] = 1, [1] = 3}
local string_pool = { [0] = {int_pools[1],int_pools[2]}}

print(utf8.char(table.unpack(string_pool[0])))
```

为什么不直接在 string_pool 中存储字符串呢？这是为了减少可以直接通过 print(string_pool) 拿到整个字符串数组，后面也会尝试对这些数字进行加密，增强混淆强大。

那我们就可以编写一个 `StringPool` 类，写出下面的实现：

```kotlin
class StringPool {
    private val pool = mutableListOf<Pair<String, List<Int>>>()

    private fun getOrPutCodeList(string: String, list: List<Int>) {
        // 检查字符串是否已经存在
        if (!pool.any { it.first == string }) {
            pool.add(Pair(string, list))
        }
    }

    // 原 getObfuscationString 实现
    fun getObfuscationString(string: String): String {
        val parsedString = parseLuaString(string)
        val chunkList = parsedString.chunked(30)

        // 初始化池
        chunkList.forEach { chunkString ->
            getOrPutCodeList(chunkString, chunkString.map { char -> char.code })
        }

        // 如果只有一个字符串，那么直接返回
        if (chunkList.size == 1) {
            val first = chunkList[0]
            val codeListOfIndex = pool.indexOfLast { it.first == first }

            return "utf8.char(table.unpack(string_pool[${codeListOfIndex}]))"
        }

        // 和上面的一样，构造一个立即执行的闭包
        val buffer = StringBuilder("(function()")

        buffer.append("local tab = {}\n")

        chunkList.forEach { chunkString ->
            val codeListOfIndex = pool.indexOfLast { it.first == chunkString }

            if (codeListOfIndex == -1) {
                throw Exception("string not found")
            }
            buffer.append("table.insert(tab, utf8.char(table.unpack(string_pool[${codeListOfIndex}])));")
        }

        buffer.append("return table.concat(tab)\nend)()")

        return buffer.toString()
    }

    fun formatToTable(): String {
        // 初始化一个常量池
        val buffer = StringBuilder("local int_pool = {\n")

        // <code,<index,code>>
        val mapped = mutableMapOf<Int, Pair<Int, Int>>()
        var mappedIndex = 0
        pool.map { it.second }.forEach { codeList ->

            codeList.forEach { code ->
                // 映射到常量池
                if (!mapped.containsKey(code)) {
                    mapped[code] = (mappedIndex++ to code)
                }
            }
        }

        mapped.forEach {
            buffer.append("  [${it.value.first}] = ${it.value.second},")
        }

        buffer.append("};\n")

        val buffer1 = StringBuilder("local string_pool = {\n")

        pool.forEachIndexed { index, pair ->
            buffer1.append("  [${index}] = {")
            buffer1.append(
                // 也就是 mapped[code] -> first, first 即为该 code 的实际存在 int_pool 的索引位置
                pair.second.joinToString(prefix = "", postfix = "", separator = ",") {
                    "int_pool[${mapped[it]?.first}]"
                })
            buffer1.append("},\n")
        }

        buffer1.append("};\n")

        buffer1.insert(0, buffer)

        return buffer1.toString()
    }
}
```

优化一下 `stringFog` 函数，改成调用 `StringPool` 类的实现：

```kotlin
fun stringFog(code: String): String {
    val lexer = LuaLexer(code)

    val buffer = StringBuilder()

    val pool = StringPool()

    for ((token, tokenText) in lexer) {
        if (token === LuaTokenTypes.STRING || token === LuaTokenTypes.LONG_STRING) {
            buffer.append(pool.getObfuscationString(tokenText))
        } else {
            buffer.append(tokenText)
        }
    }

    // 插入头部的代码，池子的实际值
    buffer.insert(0, pool.formatToTable())

    return buffer.toString()
}
```

完成后重新运行，结果如下：

{% folding 混淆后代码 %}

```lua
local int_pool = {
  [0] = 104,  [1] = 101,  [2] = 108,  [3] = 111,  [4] = 32,  [5] = 119,  [6] = 114,  [7] = 100,  [8] = 44,  [9] = 20320,  [10] = 22909,  [11] = 19990,  [12] = 30028,  [13] = 115,  [14] = 97,  [15] = 102,  [16] = 107,  [17] = 106,  [18] = 98,  [19] = 120,};
local string_pool = {
  [0] = {int_pool[0],int_pool[1],int_pool[2],int_pool[2],int_pool[3],int_pool[4],int_pool[5],int_pool[3],int_pool[6],int_pool[2],int_pool[7],int_pool[8],int_pool[4],int_pool[9],int_pool[10],int_pool[4],int_pool[11],int_pool[12]},
  [1] = {int_pool[0],int_pool[1],int_pool[2],int_pool[2],int_pool[3],int_pool[4],int_pool[5],int_pool[3],int_pool[6],int_pool[2],int_pool[7]},
  [2] = {int_pool[13],int_pool[14],int_pool[15],int_pool[16],int_pool[2],int_pool[17],int_pool[0],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7]},
  [3] = {int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7]},
  [4] = {int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[7],int_pool[17],int_pool[18],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[18],int_pool[17],int_pool[18]},
  [5] = {int_pool[17],int_pool[18],int_pool[17],int_pool[18],int_pool[17],int_pool[18],int_pool[17],int_pool[18],int_pool[17],int_pool[18],int_pool[17],int_pool[18],int_pool[17],int_pool[17],int_pool[17],int_pool[17],int_pool[17]},
  [6] = {int_pool[19],int_pool[19],int_pool[19],int_pool[19],int_pool[19],int_pool[19],int_pool[19],int_pool[19],int_pool[19],int_pool[19],int_pool[19],int_pool[19],int_pool[19]},
  [7] = {int_pool[19],int_pool[19]},
  [8] = {int_pool[8]},
};
local a = utf8.char(table.unpack(string_pool[0]))
local b = utf8.char(table.unpack(string_pool[1]))
local c = utf8.char(table.unpack(string_pool[1]))
local d = (function()local tab = {}
table.insert(tab, utf8.char(table.unpack(string_pool[2])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[4])));table.insert(tab, utf8.char(table.unpack(string_pool[5])));return table.concat(tab)
end)()
local e = (function()local tab = {}
table.insert(tab, utf8.char(table.unpack(string_pool[2])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[3])));table.insert(tab, utf8.char(table.unpack(string_pool[4])));table.insert(tab, utf8.char(table.unpack(string_pool[5])));return table.concat(tab)
end)()
local f = {b = b,c=c,a = a,d = d,e =e}

print(f.a)
print(f.b)
print(f.c)
print(f.d)
print(f.e)
print(utf8.char(table.unpack(string_pool[6])))
print(utf8.char(table.unpack(string_pool[7])))

function a(t) 
    for i=1, 10 do
        t[i] = i
    end
   return t
end  
function c(s) return s end
print(table.concat(a({}),utf8.char(table.unpack(string_pool[8]))))
print(c utf8.char(table.unpack(string_pool[1])))
```

{% endfolding %}

好像还不错！但是现在的常量依旧不够安全，每个数字都能被转换成字符串，因此我们还需要再加一层保护。

## 增加常量加密

我们可以在对常量做一层加密，混淆时输出加密后的结果，在调用的代码里再解密，这样就能提高常量的安全性了。

按照上面的思路，代码可能会是这样：

```lua
local xor = ...
local int_pools = { [0] = 1, [1] = 3}
local string_pool = { [0] = {int_pools[1],int_pools[2]}}

print(utf8.char(xor(table.unpack(string_pool[0]),11)))
```

那就让我们开始吧：

首先给 `StringPool` 类增加加密相关方法，并且修改池的类型：

```kotlin
class StringPool {
    ...
    // <字符串,加密后 unicode 编码列表,加密密钥>
    private val pool = mutableListOf<Triple<String, List<Int>, Int>>()

    private fun getOrPutCodeList(string: String, list: List<Int>) {
        if (pool.any { it.first == string }) {
            return
        }
        // 随机一个密钥
        val key = randomNumber(100, 10000).toInt()
        pool.add(Triple(string, encryptNumberList(list, key), key))
    }

    private fun randomNumber(min: Int, max: Int): Double {
        return (Math.random() * (max - min + 1)) + min
    }

    private fun encryptNumberList(list: List<Int>, key: Int): List<Int> {
        // 使用 xor 实现
        return list.map { it.xor(key) }
    }

    ...
}
```

接着修改 `getObfuscationString` 和 `formatToTable`，实现加密相关逻辑：

```kotlin
class StringFog{
    ...

    fun getObfuscationString(string: String): String {
        val parsedString = parseLuaString(string)
        val chunkList = parsedString.chunked(30)

        chunkList.forEach { chunkString ->
            getOrPutCodeList(chunkString, chunkString.map { char -> char.code })
        }


        if (chunkList.size == 1) {
            val first = chunkList[0]
            val codeIndex = pool.find { it.first == first }
            val index = pool.indexOf(codeIndex)

            // 增加 xor 函数，作为解密的实现
            return "utf8.char(table.unpack(xor(string_pool[${index}],${codeIndex?.third})))"
        }

        val buffer = StringBuilder("(function()")

        buffer.append("local tab = {}\n")

        chunkList.forEach { chunkString ->
            val codeIndex = pool.find { it.first == chunkString }
            val codeListOfIndex = pool.indexOf(codeIndex)

            if (codeListOfIndex == -1) {
                throw Exception("string not found")
            }
            buffer.append("table.insert(tab, utf8.char(table.unpack(xor(string_pool[${codeListOfIndex}],${codeIndex?.third}))));")
        }

        buffer.append("return table.concat(tab)\nend)()")

        return buffer.toString()
    }


    fun formatToTable(): String {
        // 解密头代码实现
        val xor = """
            local xor = function (array, key) local result = {} for i = 1, #array do result[i] = array[i] ~ key end return result end
        """.trimIndent()
        val buffer = StringBuilder(xor).append("\nlocal int_pool = {\n")

        // <code,<index,code>>
        val mapped = mutableMapOf<Int, Pair<Int, Int>>()
        var mappedIndex = 0
        pool.map { it.second }.forEach { codeList ->
            codeList.forEach { code ->
                if (!mapped.containsKey(code)) {
                    mapped[code] = (mappedIndex++ to code)
                }
            }
        }

        mapped.forEach {
            buffer.append("  [${it.value.first}] = ${it.value.second},")
        }

        buffer.append("};\n")

        val buffer1 = StringBuilder("local string_pool = {\n")

        pool.forEachIndexed { index, pair ->
            buffer1.append("  [${index}] = {")
            buffer1.append(
                pair.second.joinToString(prefix = "", postfix = "", separator = ",") {
                    "int_pool[${mapped[it]?.first}]"
                })
            buffer1.append("},\n")
        }

        buffer1.append("};\n")

        buffer1.insert(0, buffer)

        return buffer1.toString()
    }
}

```

无需修改 `stringFog`，重新运行一下，看看效果如何：

{% folding 混淆后代码 %}

```lua
local xor = function (array, key) local result = {} for i = 1, #array do result[i] = array[i] ~ key end return result end
local int_pool = {
  [0] = 8411,  [1] = 8406,  [2] = 8415,  [3] = 8412,  [4] = 8339,  [5] = 8388,  [6] = 8385,  [7] = 8407,  [8] = 8351,  [9] = 28627,  [10] = 31182,  [11] = 28325,  [12] = 22015,  [13] = 7481,  [14] = 7476,  [15] = 7485,  [16] = 7486,  [17] = 7537,  [18] = 7462,  [19] = 7459,  [20] = 7477,  [21] = 2763,  [22] = 2777,  [23] = 2782,  [24] = 2771,  [25] = 2772,  [26] = 2770,  [27] = 2768,  [28] = 2780,  [29] = 1890,  [30] = 1900,  [31] = 659,  [32] = 669,  [33] = 667,  [34] = 5739,  [35] = 5731,  [36] = 6801,  [37] = 9420,  [38] = 4093,};
local string_pool = {
  [0] = {int_pool[0],int_pool[1],int_pool[2],int_pool[2],int_pool[3],int_pool[4],int_pool[5],int_pool[3],int_pool[6],int_pool[2],int_pool[7],int_pool[8],int_pool[4],int_pool[9],int_pool[10],int_pool[4],int_pool[11],int_pool[12]},
  [1] = {int_pool[13],int_pool[14],int_pool[15],int_pool[15],int_pool[16],int_pool[17],int_pool[18],int_pool[16],int_pool[19],int_pool[15],int_pool[20]},
  [2] = {int_pool[21],int_pool[22],int_pool[23],int_pool[24],int_pool[25],int_pool[26],int_pool[27],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28]},
  [3] = {int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30]},
  [4] = {int_pool[31],int_pool[32],int_pool[31],int_pool[32],int_pool[31],int_pool[32],int_pool[31],int_pool[32],int_pool[31],int_pool[32],int_pool[31],int_pool[33],int_pool[31],int_pool[31],int_pool[31],int_pool[31],int_pool[31],int_pool[31],int_pool[31],int_pool[31],int_pool[31],int_pool[31],int_pool[31],int_pool[31],int_pool[31],int_pool[31],int_pool[31],int_pool[33],int_pool[31],int_pool[33]},
  [5] = {int_pool[34],int_pool[35],int_pool[34],int_pool[35],int_pool[34],int_pool[35],int_pool[34],int_pool[35],int_pool[34],int_pool[35],int_pool[34],int_pool[35],int_pool[34],int_pool[34],int_pool[34],int_pool[34],int_pool[34]},
  [6] = {int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36]},
  [7] = {int_pool[37],int_pool[37]},
  [8] = {int_pool[38]},
};
local a = utf8.char(table.unpack(xor(string_pool[0],8371)))
local b = utf8.char(table.unpack(xor(string_pool[1],7505)))
local c = utf8.char(table.unpack(xor(string_pool[1],7505)))
local d = (function()local tab = {}
table.insert(tab, utf8.char(table.unpack(xor(string_pool[2],2744))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[4],761))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[5],5633))));return table.concat(tab)
end)()
local e = (function()local tab = {}
table.insert(tab, utf8.char(table.unpack(xor(string_pool[2],2744))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1800))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[4],761))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[5],5633))));return table.concat(tab)
end)()
local f = {b = b,c=c,a = a,d = d,e =e}

print(f.a)
print(f.b)
print(f.c)
print(f.d)
print(f.e)
print(utf8.char(table.unpack(xor(string_pool[6],6889))))
print(utf8.char(table.unpack(xor(string_pool[7],9396))))

function a(t) 
    for i=1, 10 do
        t[i] = i
    end
   return t
end  
function c(s) return s end
print(table.concat(a({}),utf8.char(table.unpack(xor(string_pool[8],4049)))))
print(c utf8.char(table.unpack(xor(string_pool[1],7505))))
```

{% endfolding %}

这下就好了，常量里面的不同字符串对应的不同的编码，都会对应不同的已经加密的数字和密钥，增强了混淆强度。

## 更进一步？

现在的字符串混淆仅仅只对字符串混淆，但是我们都知道在 lua 里，以下几种操作可以替换成其他操作：

1. 形如 `a.b = c` 的代码等价于 `a['b'] = c`
2. 全局变量存于 `_G`，因此基于 .1, `print('h')` 也等价于 `_G['print']('h')`

那么我们就可以把上面两种代码替换成用字符串索引调用的代码，这样可以实现混淆隐藏部分字段，让代码逻辑看起来更混乱。

让我们重新编写 `stringFog` 的实现，使用 lexer 对代码进行简单分析

```kotlin
fun stringFog(code: String, globalVar: List<String>): String {
    val lexer = LuaLexer(code)

    val buffer = StringBuilder()

    val pool = StringPool3()

    val queue = ArrayDeque<Pair<LuaTokenTypes, String>>()

    // 是否可以混淆标识符
    var canObfuscation = true

    for ((token, tokenText) in lexer) {
        if (
            (token == LuaTokenTypes.STRING || token == LuaTokenTypes.LONG_STRING)
        ) {
            // 由于 lua 里支持形如 a "b" 这样的调用方式，我们判断最后的 token 是否为标识符，并决定加括号
            if (queue.lastOrNull()?.first == LuaTokenTypes.NAME) {
                buffer.append("(")
                buffer.append(pool.getObfuscationString(tokenText))
                buffer.append(")")
            } else {
                // 直接混淆
                buffer.append(pool.getObfuscationString(tokenText))
            }

        } else if (token == LuaTokenTypes.NAME) {
            // 如果为标识符

            // 确认是否可混淆，并且该标识符是否为全局变量，还需要判断最后一个标识符是否为点调用，要确保不是点调用
            if (canObfuscation && globalVar.contains(tokenText) && queue.lastOrNull()?.first != LuaTokenTypes.DOT) {
                buffer.append("_G[")
                buffer.append(pool.getObfuscationString(tokenText))
                buffer.append("]")

                queue.addLast(token to tokenText)
                continue
            }

            // 确保为点调用，形如 a.b，这里会改为 a['b']
            if (canObfuscation && queue.lastOrNull()?.first == LuaTokenTypes.DOT) {
                buffer.deleteCharAt(buffer.lastIndexOf(".")) // .
                buffer.append("[")
                buffer.append(pool.getObfuscationString(tokenText))
                buffer.append("]")

                queue.addLast(token to tokenText)
                continue
            }

            buffer.append(tokenText)
        } else {

            canObfuscation = when (token) {
                // function a.b，这样的函数名不能混淆
                LuaTokenTypes.FUNCTION -> {
                    false
                }

                // function a.b( 或者 a(a.b)，对于右者，越过左括号后允许混淆
                LuaTokenTypes.LPAREN -> {
                    true
                }

                // 类似上面
                LuaTokenTypes.RPAREN -> {
                    true
                }

                // 新开一行强制允许标识符混淆
                LuaTokenTypes.NEW_LINE -> {
                    true
                }

                else -> {
                    canObfuscation
                }
            }

            buffer.append(tokenText)
        }

        // 忽略空格和新行
        if (token != LuaTokenTypes.WHITE_SPACE && token != LuaTokenTypes.NEW_LINE) {
            queue.addLast(token to tokenText)
        }
    }


    buffer.insert(0, pool.formatToTable())

    return buffer.toString()
}

```

修改 `main` 函数，增加几个全局变量:

```kotlin
fun main() {
    println(stringFog(code, listOf("print","table")))
}
```

运行结果如下：

{% folding 混淆后代码 %}

```lua
local xor = function (array, key) local result = {} for i = 1, #array do result[i] = array[i] ~ key end return result end
local int_pool = {
  [0] = 2413,  [1] = 2400,  [2] = 2409,  [3] = 2410,  [4] = 2341,  [5] = 2418,  [6] = 2423,  [7] = 2401,  [8] = 2345,  [9] = 18021,  [10] = 20600,  [11] = 18195,  [12] = 31817,  [13] = 8426,  [14] = 8423,  [15] = 8430,  [16] = 8429,  [17] = 8354,  [18] = 8437,  [19] = 8432,  [20] = 8422,  [21] = 4920,  [22] = 4906,  [23] = 4909,  [24] = 4896,  [25] = 4903,  [26] = 4897,  [27] = 4899,  [28] = 4911,  [29] = 1513,  [30] = 1511,  [31] = 9188,  [32] = 9201,  [33] = 9190,  [34] = 9187,  [35] = 9192,  [36] = 686,  [37] = 672,  [38] = 678,  [39] = 1898,  [40] = 1890,  [41] = 5406,  [42] = 5392,  [43] = 5398,  [44] = 4991,  [45] = 4983,  [46] = 920,  [47] = 922,  [48] = 897,  [49] = 902,  [50] = 924,  [51] = 8290,  [52] = 8972,  [53] = 6407,  [54] = 8779,  [55] = 9044,  [56] = 4913,  [57] = 2304,  [58] = 7760,  [59] = 7749,  [60] = 7750,  [61] = 7752,  [62] = 7745,  [63] = 8625,  [64] = 8637,  [65] = 8636,  [66] = 8627,  [67] = 8614,  [68] = 3972,};
local string_pool = {
  [0] = {int_pool[0],int_pool[1],int_pool[2],int_pool[2],int_pool[3],int_pool[4],int_pool[5],int_pool[3],int_pool[6],int_pool[2],int_pool[7],int_pool[8],int_pool[4],int_pool[9],int_pool[10],int_pool[4],int_pool[11],int_pool[12]},
  [1] = {int_pool[13],int_pool[14],int_pool[15],int_pool[15],int_pool[16],int_pool[17],int_pool[18],int_pool[16],int_pool[19],int_pool[15],int_pool[20]},
  [2] = {int_pool[21],int_pool[22],int_pool[23],int_pool[24],int_pool[25],int_pool[26],int_pool[27],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28],int_pool[26],int_pool[28]},
  [3] = {int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30],int_pool[29],int_pool[30]},
  [4] = {int_pool[31],int_pool[31],int_pool[32],int_pool[33],int_pool[31],int_pool[32],int_pool[33],int_pool[32],int_pool[31],int_pool[33],int_pool[31],int_pool[33],int_pool[32],int_pool[31],int_pool[33],int_pool[31],int_pool[33],int_pool[31],int_pool[33],int_pool[34],int_pool[31],int_pool[34],int_pool[33],int_pool[31],int_pool[33],int_pool[34],int_pool[33],int_pool[31],int_pool[35],int_pool[33]},
  [5] = {int_pool[36],int_pool[37],int_pool[36],int_pool[37],int_pool[36],int_pool[37],int_pool[36],int_pool[37],int_pool[36],int_pool[38],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[36],int_pool[38],int_pool[36],int_pool[38],int_pool[36],int_pool[38]},
  [6] = {int_pool[39],int_pool[40],int_pool[39],int_pool[40],int_pool[39],int_pool[40],int_pool[39],int_pool[40],int_pool[39],int_pool[40],int_pool[39],int_pool[39],int_pool[39],int_pool[39],int_pool[39]},
  [7] = {int_pool[41],int_pool[42],int_pool[41],int_pool[42],int_pool[41],int_pool[42],int_pool[41],int_pool[42],int_pool[41],int_pool[42],int_pool[41],int_pool[43],int_pool[41],int_pool[41],int_pool[41],int_pool[41],int_pool[41],int_pool[41],int_pool[41],int_pool[41],int_pool[41],int_pool[41],int_pool[41],int_pool[41],int_pool[41],int_pool[41],int_pool[41],int_pool[43],int_pool[41],int_pool[43]},
  [8] = {int_pool[44],int_pool[45],int_pool[44],int_pool[45],int_pool[44],int_pool[45],int_pool[44],int_pool[45],int_pool[44],int_pool[45],int_pool[44],int_pool[45],int_pool[44],int_pool[44],int_pool[44],int_pool[44],int_pool[44]},
  [9] = {int_pool[46],int_pool[47],int_pool[48],int_pool[49],int_pool[50]},
  [10] = {int_pool[51]},
  [11] = {int_pool[52]},
  [12] = {int_pool[53]},
  [13] = {int_pool[54]},
  [14] = {int_pool[55]},
  [15] = {int_pool[56],int_pool[56],int_pool[56],int_pool[56],int_pool[56],int_pool[56],int_pool[56],int_pool[56],int_pool[56],int_pool[56],int_pool[56],int_pool[56],int_pool[56]},
  [16] = {int_pool[57],int_pool[57]},
  [17] = {int_pool[58],int_pool[59],int_pool[60],int_pool[61],int_pool[62]},
  [18] = {int_pool[63],int_pool[64],int_pool[65],int_pool[63],int_pool[66],int_pool[67]},
  [19] = {int_pool[68]},
};
local a = utf8.char(table.unpack(xor(string_pool[0],2309)))
local b = utf8.char(table.unpack(xor(string_pool[1],8322)))
local c = utf8.char(table.unpack(xor(string_pool[1],8322)))
local d = (function()local tab = {}
table.insert(tab, utf8.char(table.unpack(xor(string_pool[2],4939))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[4],9090))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[5],708))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[6],1792))));return table.concat(tab)
end)()
local e = (function()local tab = {}
table.insert(tab, utf8.char(table.unpack(xor(string_pool[2],4939))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[3],1411))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[7],5492))));table.insert(tab, utf8.char(table.unpack(xor(string_pool[8],4885))));return table.concat(tab)
end)()
local f = {b = b,c=c,a = a,d = d,e =e}

_G[utf8.char(table.unpack(xor(string_pool[9],1000)))](f[utf8.char(table.unpack(xor(string_pool[10],8195)))])
_G[utf8.char(table.unpack(xor(string_pool[9],1000)))](f[utf8.char(table.unpack(xor(string_pool[11],9070)))])
_G[utf8.char(table.unpack(xor(string_pool[9],1000)))](f[utf8.char(table.unpack(xor(string_pool[12],6500)))])
_G[utf8.char(table.unpack(xor(string_pool[9],1000)))](f[utf8.char(table.unpack(xor(string_pool[13],8751)))])
_G[utf8.char(table.unpack(xor(string_pool[9],1000)))](f[utf8.char(table.unpack(xor(string_pool[14],9009)))])
_G[utf8.char(table.unpack(xor(string_pool[9],1000)))](utf8.char(table.unpack(xor(string_pool[15],4937))))
_G[utf8.char(table.unpack(xor(string_pool[9],1000)))](utf8.char(table.unpack(xor(string_pool[16],2424))))

function a(t) 
    for i=1, 10 do
        t[i] = i
    end
   return t
end  
function c(s) return s end
_G[utf8.char(table.unpack(xor(string_pool[9],1000)))](_G[utf8.char(table.unpack(xor(string_pool[17],7716)))][utf8.char(table.unpack(xor(string_pool[18],8658)))](a({}),utf8.char(table.unpack(xor(string_pool[19],4008)))))
_G[utf8.char(table.unpack(xor(string_pool[9],1000)))](c (utf8.char(table.unpack(xor(string_pool[1],8322)))))
```

{% endfolding %}

完成！一个支持字符串加密，并且附带一点点字符隐藏的字符串混淆就完成啦。

## 结语

本次我们从零开始，一步步实现并完善了一个 Lua 字符串混淆的实现。
当然了，这样的字符串混淆并不够安全，只能算是入门基础级的字符串混淆。

这类基于 lexer，parser 的实际应用常用于逆向相关领域，推荐各位深入学习。

所有的代码均开源在下面的地址，只供学习使用！

[LuaStringFog](https://github.com/dingyi222666/LuaStringFog)