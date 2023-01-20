---
title: 速成烂大街LuaIDE系列：AndroLua+程序怎么打包的
date: 2023-01-21 04:58:24
categories:
  - 学习
tags:
  - AndroLua
  - Lua
cover: https://s2.loli.net/2023/01/21/g7GsvZHkIoCj6OY.webp
description: 轻松破解andlua的抽代码到dex
url_title: androlua_build_analysis
---

## 前情提要

在[上期](https://blog.dingyi222666.top/2022/06/28/%E6%8B%BF%E4%B8%8B%E7%B3%BB%E5%88%97-AndLua-%E6%8A%BD%E4%BB%A3%E7%A0%81%E5%88%B0dex/)文章中，我有说过要新开一个坑，讲讲大部分 Android 上的 `Lua《IDE》` 怎么打包的。

今天我这是来填坑了。

## 正文

OK，进入正题。

相信大部分用过 `AndroLua+` 的人（以及基于此的衍生编辑器），都在感叹于 `Lua` 的免安装运行，以及那飞快的打包速度（对比 `Gradle` 来说，是的）。要想知道为什么 AndroLua+打包这么快，不如先看看与其他更为正式的 Android 构建系统( `Gradle` :?)的打包流程。

### Gradle 是怎么打包的？

来，咋们直接上图。

![image.webp](https://s2.loli.net/2023/01/21/g7GsvZHkIoCj6OY.webp)

是不是看起来就挺抽象的？其实这还是旧版本的，在新版本的 `Android Gradle Plugin` 中，这个流程更复杂。

当然了，我们今天并不是来研究 Android 的 Gradle 插件怎么打包的(这东西很复杂，而且我都没啃...)。这里就直接给出简单的结论：

1. 项目的资源文件(res/drawable...)经过 aapt/aapt2 处理(资源编译)生成编译后产物。
2. 在资源编译时并行处理其他操作，比如编译 Java 和 Kotlin 文件到 Dex(source->class->dex)。
3. 调用 Zipflinger(旧版本为 Apkbuilder)，将我们之前资源编译，代码编译(native 代码到 so，jvm 字节码到 dex)，以及 assets 等项目内其他资源文件夹都打包成 zip 文件。
4. 调用 ApkSigner 签名，并且在 ZipAlign 对齐，基本就产出了你的项目打包出来的 Apk。

看起来还挺复杂的吧，哈哈。其实这已经是我很简化的情况了，真正的 Android Gralde Plugin 打包流程比这个复杂的多。不过整体的流程基本都是这样。

现在你可以要问，那这和 AndroLua+打包有啥关系啊？其实 AndroLua+也是实现了类似这么一套的打包流程。但是，他简化了很多东西，从根本上就能比 Gradle 打包快了，还使用了某些黑科技。往下看就知道了。

### 那 AndroLua+呢？

AndroLua+的打包流程就简单多了，由于我还不太会画流程图，这边就描述一下过程吧。

1. 获取当前运行的软件的 apk，做为底包
2. 检查项目的 lua 代码文件，正则匹配出有那些 so 库或者 lua 库是需要塞进目标 apk 的(不需要的就不加进去了缩小体积)
3. 添加项目文件到目标 apk 的 assets 目录下，并且遍历底包的文件也添加进去
   1. 如果为项目文件的 welcome.png, icon.png，这两个特殊文件需要塞进 res/drawable 里替换底包文件以实现替换图标和启动图（还是会添加进 assets 里面)
   2. 如果为底包的 AndroidManifest.xml，则使用 mao.dex 编辑 axml 属性，更改包名，targetSdk，权限等属性。
   3. 如果为项目文件的可编译文件(lua/aly)，则在编译后放入目标 apk。
   4. 如果为底包的 dex 或者资源文件，直接添加进去(不用编译了)
   5. 如果为其他可被添加进去目标 apk 的文件，则直接添加进去。
4. 使用 sign.dex 签名 apk，最终生成已签名的 apk，打包完成。

看文字描述，是不是感觉比上面 gradle 的打包流程感觉多了？但是这基本上可以描述整个打包代码的实际逻辑了。而不是上面那样的抽象。

对比一下我们也可以看到，AndroLua+的打包流程少了很多东西。主要是资源编译和 dex 编译，只需要编译 lua 代码文件，其他的都使用旧的底包。这样就不需要调用其他工具来编译资源和 dex 文件了，自然速度就快了许多。

看到这基本上也得出结论了吧？基本上标题需要讲的内容就到这了。但是只是这样怎么行？不上点代码干货可不行。接下来就开始从代码层面讲 AndroLua+怎么打包的。

下面的源码分析需要你有一定的lua基础和java基础，否则可直接下滑查看后面的省流(总结)

## 源码分析

先贴个 `bin.lua` 的无注释源码。

```lua
require "import"
import "java.util.zip.ZipOutputStream"
import "android.net.Uri"
import "java.io.File"
import "android.widget.Toast"
import "java.util.zip.CheckedInputStream"
import "java.io.FileInputStream"
import "android.content.Intent"
import "java.security.Signer"
import "java.util.ArrayList"
import "java.io.FileOutputStream"
import "java.io.BufferedOutputStream"
import "java.util.zip.ZipInputStream"
import "java.io.BufferedInputStream"
import "java.util.zip.ZipEntry"
import "android.app.ProgressDialog"
import "java.util.zip.CheckedOutputStream"
import "java.util.zip.Adler32"

local bin_dlg, error_dlg
local function update(s)
    bin_dlg.setMessage(s)
end

local function callback(s)

    LuaUtil.rmDir(File(activity.getLuaExtDir("bin/.temp")))
    bin_dlg.hide()
    bin_dlg.Message = ""
    if not s:find("成功") then
        error_dlg.Message = s
        error_dlg.show()
    end
end

local function create_bin_dlg()
    if bin_dlg then
        return
    end
    bin_dlg = ProgressDialog(activity);
    bin_dlg.setTitle("正在打包");
    bin_dlg.setMax(100);
end

local function create_error_dlg2()
    if error_dlg then
        return
    end
    error_dlg = AlertDialogBuilder(activity)
    error_dlg.Title = "出错"
    error_dlg.setPositiveButton("确定", nil)
end

local function binapk(luapath, apkpath)
    require "import"
    import "console"
    compile "mao"
    compile "sign"
    import "java.util.zip.*"
    import "java.io.*"
    import "mao.res.*"
    import "apksigner.*"
    local b = byte[2 ^ 16]
    local function copy(input, output)
        LuaUtil.copyFile(input, output)
        input.close()
        --[[local l=input.read(b)
      while l>1 do
        output.write(b,0,l)
        l=input.read(b)
      end]]
    end

    local function copy2(input, output)
        LuaUtil.copyFile(input, output)
    end

    local temp = File(apkpath).getParentFile();
    if (not temp.exists()) then

        if (not temp.mkdirs()) then

            error("create file " .. temp.getName() .. " fail");
        end
    end

    local tmp = luajava.luadir .. "/tmp.apk"
    local info = activity.getApplicationInfo()
    local ver = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0).versionName
    local code = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0).versionCode

    --local zip=ZipFile(info.publicSourceDir)
    local zipFile = File(info.publicSourceDir)
    local fis = FileInputStream(zipFile);
    --local checksum = CheckedInputStream(fis, Adler32());
    local zis = ZipInputStream(BufferedInputStream(fis));

    local fot = FileOutputStream(tmp)
    --local checksum2 = CheckedOutputStream(fot, Adler32());

    local out = ZipOutputStream(BufferedOutputStream(fot))
    local f = File(luapath)
    local errbuffer = {}
    local replace = {}
    local checked = {}
    local lualib = {}
    local md5s = {}
    local libs = File(activity.ApplicationInfo.nativeLibraryDir).list()
    libs = luajava.astable(libs)
    for k, v in ipairs(libs) do
        --libs[k]="lib/armeabi/"..libs[k]
        replace[v] = true
    end

    local mdp = activity.Application.MdDir
    local function getmodule(dir)
        local mds = File(activity.Application.MdDir .. dir).listFiles()
        mds = luajava.astable(mds)
        for k, v in ipairs(mds) do
            if mds[k].isDirectory() then
                getmodule(dir .. mds[k].Name .. "/")
            else
                mds[k] = "lua" .. dir .. mds[k].Name
                replace[mds[k]] = true
            end
        end
    end

    getmodule("/")

    local function checklib(path)
        if checked[path] then
            return
        end
        local cp, lp
        checked[path] = true
        local f = io.open(path)
        local s = f:read("*a")
        f:close()
        for m, n in s:gmatch("require *%(? *\"([%w_]+)%.?([%w_]*)") do
            cp = string.format("lib%s.so", m)
            if n ~= "" then
                lp = string.format("lua/%s/%s.lua", m, n)
                m = m .. '/' .. n
            else
                lp = string.format("lua/%s.lua", m)
            end
            if replace[cp] then
                replace[cp] = false
            end
            if replace[lp] then
                checklib(mdp .. "/" .. m .. ".lua")
                replace[lp] = false
                lualib[lp] = mdp .. "/" .. m .. ".lua"
            end
        end
        for m, n in s:gmatch("import *%(? *\"([%w_]+)%.?([%w_]*)") do
            cp = string.format("lib%s.so", m)
            if n ~= "" then
                lp = string.format("lua/%s/%s.lua", m, n)
                m = m .. '/' .. n
            else
                lp = string.format("lua/%s.lua", m)
            end
            if replace[cp] then
                replace[cp] = false
            end
            if replace[lp] then
                checklib(mdp .. "/" .. m .. ".lua")
                replace[lp] = false
                lualib[lp] = mdp .. "/" .. m .. ".lua"
            end
        end
    end

    replace["libluajava.so"] = false

    local function addDir(out, dir, f)
        local entry = ZipEntry("assets/" .. dir)
        out.putNextEntry(entry)
        local ls = f.listFiles()
        for n = 0, #ls - 1 do
            local name = ls[n].getName()
            if name==(".using") then
                checklib(luapath .. dir .. name)
            elseif name:find("%.apk$") or name:find("%.luac$") or name:find("^%.") then
            elseif name:find("%.lua$") then
                checklib(luapath .. dir .. name)
                local path, err = console.build(luapath .. dir .. name)
                if path then
                    if replace["assets/" .. dir .. name] then
                        table.insert(errbuffer, dir .. name .. "/.aly")
                    end
                    local entry = ZipEntry("assets/" .. dir .. name)
                    out.putNextEntry(entry)

                    replace["assets/" .. dir .. name] = true
                    copy(FileInputStream(File(path)), out)
                    table.insert(md5s, LuaUtil.getFileMD5(path))
                    os.remove(path)
                else
                    table.insert(errbuffer, err)
                end
            elseif name:find("%.aly$") then
                local path, err = console.build(luapath .. dir .. name)
                if path then
                    name = name:gsub("aly$", "lua")
                    if replace["assets/" .. dir .. name] then
                        table.insert(errbuffer, dir .. name .. "/.aly")
                    end
                    local entry = ZipEntry("assets/" .. dir .. name)
                    out.putNextEntry(entry)

                    replace["assets/" .. dir .. name] = true
                    copy(FileInputStream(File(path)), out)
                    table.insert(md5s, LuaUtil.getFileMD5(path))
                    os.remove(path)
                else
                    table.insert(errbuffer, err)
                end
            elseif ls[n].isDirectory() then
                addDir(out, dir .. name .. "/", ls[n])
            else
                local entry = ZipEntry("assets/" .. dir .. name)
                out.putNextEntry(entry)
                replace["assets/" .. dir .. name] = true
                copy(FileInputStream(ls[n]), out)
                table.insert(md5s, LuaUtil.getFileMD5(ls[n]))
            end
        end
    end

    this.update("正在编译...");
    if f.isDirectory() then
        require "permission"
        dofile(luapath .. "init.lua")
        if user_permission then
            for k, v in ipairs(user_permission) do
                user_permission[v] = true
            end
        end

        local ss, ee = pcall(addDir, out, "", f)
        if not ss then
            table.insert(errbuffer, ee)
        end
        --print(ee,dump(errbuffer),dump(replace))

        local wel = File(luapath .. "icon.png")
        if wel.exists() then
            local entry = ZipEntry("res/drawable/icon.png")
            out.putNextEntry(entry)
            replace["res/drawable/icon.png"] = true
            copy(FileInputStream(wel), out)
        end
        local wel = File(luapath .. "welcome.png")
        if wel.exists() then
            local entry = ZipEntry("res/drawable/welcome.png")
            out.putNextEntry(entry)
            replace["res/drawable/welcome.png"] = true
            copy(FileInputStream(wel), out)
        end
    else
        return "error"
    end

    --print(dump(lualib))
    for name, v in pairs(lualib) do
        local path, err = console.build(v)
        if path then
            local entry = ZipEntry(name)
            out.putNextEntry(entry)
            copy(FileInputStream(File(path)), out)
            table.insert(md5s, LuaUtil.getFileMD5(path))
            os.remove(path)
        else
            table.insert(errbuffer, err)
        end
    end

    function touint32(i)
        local code = string.format("%08x", i)
        local uint = {}
        for n in code:gmatch("..") do
            table.insert(uint, 1, string.char(tonumber(n, 16)))
        end
        return table.concat(uint)
    end

    this.update("正在打包...");
    local entry = zis.getNextEntry();
    while entry do
        local name = entry.getName()
        local lib = name:match("([^/]+%.so)$")
        if replace[name] then
        elseif lib and replace[lib] then
        elseif name:find("^assets/") then
        elseif name:find("^lua/") then
        elseif name:find("META%-INF") then
        else
            local entry = ZipEntry(name)
            out.putNextEntry(entry)
            if entry.getName() == "AndroidManifest.xml" then
                if path_pattern and #path_pattern > 1 then
                    path_pattern = ".*\\\\." .. path_pattern:match("%w+$")
                end
                local list = ArrayList()
                local xml = AXmlDecoder.read(list, zis)
                local req = {
                    [activity.getPackageName()] = packagename,
                    [info.nonLocalizedLabel] = appname,
                    [ver] = appver,
                    [".*\\\\.lua"] = "",
                    [".*\\\\.luac"] = "",
                }
                --设置关联文件后缀
                if path_pattern==nil or path_pattern=="" then
                    req[".*\\\\.alp"] = ""
                    req["application/alp"] = "application/1234567890"
                  else
                    path_pattern=path_pattern:match("%w+$") or path_pattern
                    req[".*\\\\.alp"] = ".*\\\\."..path_pattern
                    req["application/alp"] = "application/"..path_pattern
                end
               
                for n = 0, list.size() - 1 do
                    local v = list.get(n)
                   
                    if req[v] then
                        list.set(n, req[v])
                   
                    elseif user_permission then
                        local p = v:match("%.permission%.([%w_]+)$")
                        if p and (not user_permission[p]) then
                            list.set(n, "android.permission.UNKNOWN")
                        end
                    end
                end
                local pt = activity.getLuaPath(".tmp")
                local fo = FileOutputStream(pt)
                xml.write(list, fo)
                local code = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0).versionCode
                fo.close()
                local f = io.open(pt)
                local s = f:read("a")
                f:close()
                s = string.gsub(s, touint32(code), touint32(tointeger(appcode) or 1),1)
                s = string.gsub(s, touint32(18), touint32(tointeger(appsdk) or 18),1)

                local f = io.open(pt, "w")
                f:write(s)
                f:close()
                local fi = FileInputStream(pt)
                copy(fi, out)
                os.remove(pt)
            elseif not entry.isDirectory() then
                copy2(zis, out)
            end
        end
        entry = zis.getNextEntry()
    end
    out.setComment(table.concat(md5s))
    --print(table.concat(md5s,"/n"))
    zis.close();
    out.closeEntry()
    out.close()

    if #errbuffer == 0 then
        this.update("正在签名...");
        os.remove(apkpath)
        Signer.sign(tmp, apkpath)
        os.remove(tmp)
        activity.installApk(apkpath)
        --[[import "android.net.*"
        import "android.content.*"
        i = Intent(Intent.ACTION_VIEW);
        i.setDataAndType(activity.getUriForFile(File(apkpath)), "application/vnd.android.package-archive");
        i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        this.update("正在打开...");
        activity.startActivityForResult(i, 0);]]
        return "打包成功:" .. apkpath
    else
        os.remove(tmp)
        this.update("打包出错:\n " .. table.concat(errbuffer, "\n"));
        return "打包出错:\n " .. table.concat(errbuffer, "\n")
    end
end

--luabindir=activity.getLuaExtDir("bin")
--print(activity.getLuaExtPath("bin","a"))
local function bin(path)
    local p = {}
    local e, s = pcall(loadfile(path .. "init.lua", "bt", p))
    if e then
        create_error_dlg2()
        create_bin_dlg()
        bin_dlg.show()
        activity.newTask(binapk, update, callback).execute { path, activity.getLuaExtPath("bin", p.appname .. "_" .. p.appver .. ".apk") }
    else
        Toast.makeText(activity, "工程配置文件错误." .. s, Toast.LENGTH_SHORT).show()
    end
end

--bin(activity.getLuaExtDir("project/demo").."/")
return bin
```

400 多行就实现了打包功能，不得不说还是很简洁的(指代码大小)。

其实阅读这部分代码也不算难，我们只需要关注 `binapk` 函数就可以了。它接收两个参数，一个是项目路径，一个是打包生成 apk 的路径。

接下来来一步步阅读，剖开本质内核。

### 1. 检查哪些库需要导入

先看看 `binapk` 函数的开头

```lua
require "import"
import "console"
compile "mao"
compile "sign"
import "java.util.zip.*"
import "java.io.*"
import "mao.res.*"
import "apksigner.*"
local b = byte[2 ^ 16]

--复制文件
local function copy(input, output)
    LuaUtil.copyFile(input, output)
    input.close()
end
--复制文件，但是不关闭输入流
local function copy2(input, output)
    LuaUtil.copyFile(input, output)
end
--创建父文件夹
local temp = File(apkpath).getParentFile();
if (not temp.exists()) then
    if (not temp.mkdirs()) then
        error("create file " .. temp.getName() .." fail");
    end
end

--临时的apk产物
local tmp = luajava.luadir .. "/tmp.apk"
local info = activity.getApplicationInfo()
--当前程序(也就是底包)的版本号
local ver = activity.getPackageManager()getPackageInf(activity.getPackageName(), 0)versionName
--底包的内部版本号
local code = activity.getPackageManager(getPackageInfo(activity.getPackageName(), 0versionCode
--local zip=ZipFile(info.publicSourceDir)
local zipFile = File(info.publicSourceDir)
local fis = FileInputStream(zipFile);
--local checksum = CheckedInputStream(fis, Adler3());
--从zipFile到这都是创建底包的输入流(读取底包数据)
local zis = ZipInputStream(BufferedInputStream(fis);
local fot = FileOutputStream(tmp)
--local checksum2 = CheckedOutputStream(fot,Adler32();
--zip输出流，写入到临时的apk产物
local out = ZipOutputStream(BufferedOutputStrea(fot))
local f = File(luapath)
--打包时产生错误的缓存buffer，因为就算中途打包失败也不能直接抛错，而是需要捕获处理，到后面清理缓存完了在报错
local errbuffer = {}
--这个表有点复杂，通俗的说就是一个{path:boolean}这样格式的表，左边的是路径，右边的是布尔值，表示是否已经添加(替换)到了目标apk中,如果为false的话在后续会在从底包里添加进去。
local replace = {}
--这个表用于检测当前需要从底包导入的lua/so库，是否已经导入过了
local checked = {}
--lua的导入库库列
local lualib = {}
--部分文件的md5集合，这个东西不用管。
local md5s = {}
local libs = File(activityApplicationInfonativeLibraryDir).list()
--这里是获取so库列表
libs = luajava.astable(libs)
```

基本上看注释都知道有啥用了吧...

继续看导入库的部分

```lua
--遍历so库
for k, v in ipairs(libs) do
    --libs[k]="lib/armeabi/"..libs[k]
    --设置为ture，也就是默认不打包进去
    replace[v] = true
end

local mdp = activity.Application.MdDir
--获取底包里面"./lua/"的乱库文件
local function getmodule(dir)
    local mds = File(activity.Application.MdDir .. dir).listFiles()
    --获取文件对象转成列表
    mds = luajava.astable(mds)
    for k, v in ipairs(mds) do
        --如果为文件夹，递归获取
        if mds[k].isDirectory() then
            getmodule(dir .. mds[k].Name .. "/")
        else
            --这里设置一遍mds[k]的意义是啥？？
            --反正就是拼接出来lua库路径，设置默认不打包进去
            mds[k] = "lua" .. dir .. mds[k].Name
            replace[mds[k]] = true
        end
    end
end

getmodule("/")

--检查代码里有那些库是需要打包进apk的
--path就是代码路径
local function checklib(path)
    --导入过了就不用再次导入了
    if checked[path] then
        return
    end
    local cp, lp
    --设置为true，也就是导入过
    checked[path] = true
    local f = io.open(path)
    local s = f:read("*a")
    f:close()
    --读取代码文件并且正则匹配(检测require)
    for m, n in s:gmatch("require *%(? *\"([%w_]+)%.?([%w_]*)") do
        --m第一层路径,n第二层路径
        --例如,import "loadlayout" 这里只有一层路径。
        --import "socket.t" 这里就有第二层路径了。

        --cp就是转换为so库的路径
        cp = string.format("lib%s.so", m)
        if n ~= "" then
            --两层路径
            lp = string.format("lua/%s/%s.lua", m, n)
            m = m .. '/' .. n
        else
            --一层路径
            lp = string.format("lua/%s.lua", m)
        end
        --是lib库吗？是的话设置为false，那就是需要导入了。
        if replace[cp] then
            replace[cp] = false
        end
        --是lua库？
        if replace[lp] then
            --检测lua库文件锁需要导入的其他lua文件
            checklib(mdp .. "/" .. m .. ".lua")
            --设置为需要导入
            replace[lp] = false
            lualib[lp] = mdp .. "/" .. m .. ".lua"
        end
    end
    --如上，只是换成检测import
    for m, n in s:gmatch("import *%(? *\"([%w_]+)%.?([%w_]*)") do
        cp = string.format("lib%s.so", m)
        if n ~= "" then
            lp = string.format("lua/%s/%s.lua", m, n)
            m = m .. '/' .. n
        else
            lp = string.format("lua/%s.lua", m)
        end
        if replace[cp] then
            replace[cp] = false
        end
        if replace[lp] then
            checklib(mdp .. "/" .. m .. ".lua")
            replace[lp] = false
            lualib[lp] = mdp .. "/" .. m .. ".lua"
        end
    end
end
```

这一部分代码就被我们啃下啦！继续看编译assets代码部分吧。

### 2.编译项目lua代码

```lua
--设置libluajava.so为false，也就是强制需要这个库(毕竟是lua实现库)
replace["libluajava.so"] = false

--添加文件夹到apk的assets上，
local function addDir(out, dir, f)
    --创建一个ZipEntry
    local entry = ZipEntry("assets/" .. dir)
    out.putNextEntry(entry)
    --获取传入的文件夹的列表
    local ls = f.listFiles()
    for n = 0, #ls - 1 do
        --文件名
        local name = ls[n].getName()
        if name==(".using") then
            --这个是主动声明需要导入的库文件，注意不会添加进去
            checklib(luapath .. dir .. name)
        --apk，luac不打包进去？    
        elseif name:find("%.apk$") or name:find("%.luac$") or name:find("^%.") then
        --是lua代码
        elseif name:find("%.lua$") then
            --检查引入库
            checklib(luapath .. dir .. name)
            --编译代码
            local path, err = console.build(luapath .. dir .. name)
            if path then
                if replace["assets/" .. dir .. name] then
                    --重复aly和lua
                    table.insert(errbuffer, dir .. name .. "/.aly")
                end
                --放入zip元素
                local entry = ZipEntry("assets/" .. dir .. name)
                out.putNextEntry(entry)
                --设置已经加进去apk
                replace["assets/" .. dir .. name] = true
                --真正的复制加入进去apk
                copy(FileInputStream(File(path)), out)
                --不关心
                table.insert(md5s, LuaUtil.getFileMD5(path))
                --移除
                os.remove(path)
            else
                --出错
                table.insert(errbuffer, err)
            end
        --是aly    
        elseif name:find("%.aly$") then
            --编译文件
            local path, err = console.build(luapath .. dir .. name)
            if path then
                --已经编译成了变成lua代码（包装而已），就替换名字为lua
                name = name:gsub("aly$", "lua")
                --重复lua和aly
                if replace["assets/" .. dir .. name] then
                    table.insert(errbuffer, dir .. name .. "/.aly")
                end
                local entry = ZipEntry("assets/" .. dir .. name)
                out.putNextEntry(entry)
                --设置加入进去
                replace["assets/" .. dir .. name] = true
                --复制
                copy(FileInputStream(File(path)), out)
                table.insert(md5s, LuaUtil.getFileMD5(path))
                --移除
                os.remove(path)
            else
                --出错
                table.insert(errbuffer, err)
            end
        elseif ls[n].isDirectory() then
            --继续递归遍历
            addDir(out, dir .. name .. "/", ls[n])
        else
            --其他的东西就直接加入吧。
            local entry = ZipEntry("assets/" .. dir .. name)
            out.putNextEntry(entry)
            replace["assets/" .. dir .. name] = true
            copy(FileInputStream(ls[n]), out)
            table.insert(md5s, LuaUtil.getFileMD5(ls[n]))
        end
    end
end


this.update("正在编译...");
if f.isDirectory() then
    --导入权限库
    require "permission"
    --直接dofile，甚至都没用load设置env我哭死
    dofile(luapath .. "init.lua")
    --项目需要的权限列表
    if user_permission then
        for k, v in ipairs(user_permission) do
            --需要导入
            user_permission[v] = true
        end
    end

    --pcall处理下免得直接给抛错了,这里调用addDir就是开始扫描项目里的assets
    local ss, ee = pcall(addDir, out, "", f)
    if not ss then
        table.insert(errbuffer, ee)
    end
    --print(ee,dump(errbuffer),dump(replace))

    --检测是否有icon
    local wel = File(luapath .. "icon.png")
    if wel.exists() then
        local entry = ZipEntry("res/drawable/icon.png")
        out.putNextEntry(entry)
        --有的话设置为true，避免等会遍历底包文件时候重复加入
        replace["res/drawable/icon.png"] = true
        copy(FileInputStream(wel), out)
    end
     --检测是否有启动图
    local wel = File(luapath .. "welcome.png")
    if wel.exists() then
        local entry = ZipEntry("res/drawable/welcome.png")
        out.putNextEntry(entry)
         --有的话设置为true，避免等会遍历底包文件时候重复加入
        replace["res/drawable/welcome.png"] = true
        copy(FileInputStream(wel), out)
    end
else
    return "error"
end
--遍历lua库，编译然后加入到apk
for name, v in pairs(lualib) do
    local path, err = console.build(v)
    if path then
        local entry = ZipEntry(name)
        out.putNextEntry(entry)
        copy(FileInputStream(File(path)), out)
        table.insert(md5s, LuaUtil.getFileMD5(path))
        os.remove(path)
    else
        table.insert(errbuffer, err)
    end
end
```

### 3.复制底包文件到目标apk

```lua
--axml替换数字
function touint32(i)
    local code = string.format("%08x", i)
    local uint = {}
    for n in code:gmatch("..") do
        table.insert(uint, 1, string.char(tonumber(n, 16)))
    end
    return table.concat(uint)
end

this.update("正在打包...");
local entry = zis.getNextEntry();
--这里是把底包之前的文件都给加入目标apk去
while entry do
    local name = entry.getName()
    --正则匹配so
    local lib = name:match("([^/]+%.so)$")
    --如果底包的这个文件在之前就加入过了就跳过
    if replace[name] then
      --是否加入so过（或者说是否需要加入)
    elseif lib and replace[lib] then
    --不加入底包的assets
    elseif name:find("^assets/") then
    --不加入底包的lua
    elseif name:find("^lua/") then
    --不加入签名相关配置文件
    elseif name:find("META%-INF") then
    else
        --创建新的entry
        local entry = ZipEntry(name)
        out.putNextEntry(entry)
        --是否为AndroidManifest？
        if entry.getName() == "AndroidManifest.xml" then
            --这里的path_pattern应该是前面dofile的结果，就是声明能打开的文件关联的后缀
            if path_pattern and #path_pattern > 1 then
                path_pattern = ".*\\\\." .. path_pattern:match("%w+$")
            end
            local list = ArrayList()
            --解码axml
            local xml = AXmlDecoder.read(list, zis)
            --需要替换的东西 key是原来的，value是目标
            local req = {
                --当前软件的包名
                [activity.getPackageName()] = 
                packagename, --目标包名
                --程序的名字 
                [info.nonLocalizedLabel] = appname,
                --版本号
                [ver] = appver,
                --alua的文件关联后缀，不要了。
                [".*\\\\.lua"] = "",
                [".*\\\\.luac"] = "",
            }

            --读取xml的字段
                local xml = AXmlDecoder.read(list, zis)
                local req = {
                    [activity.getPackageName()] = packagename,
                    [info.nonLocalizedLabel] = appname,
                    [ver] = appver,
                    [".*\\\\.lua"] = "",
                    [".*\\\\.luac"] = "",
                }
                --设置关联文件后缀
                if path_pattern==nil or path_pattern=="" then
                    req[".*\\\\.alp"] = ""
                    req["application/alp"] = "application/1234567890"
                  else
                    path_pattern=path_pattern:match("%w+$") or path_pattern
                    req[".*\\\\.alp"] = ".*\\\\."..path_pattern
                    req["application/alp"] = "application/"..path_pattern
                end
                --遍历amxl字段列表
                for n = 0, list.size() - 1 do
                    local v = list.get(n)
                    --需要替换
                    if req[v] then
                        list.set(n, req[v])
                    --呃，如果是权限的话
                    elseif user_permission then
                        local p = v:match("%.permission%.([%w_]+)$")
                        --这里搞笑的是alua是全权限的，也就是说，它是过滤你不设置的权限为空权限，剩下的就都是你设置的权限了。
                        if p and (not user_permission[p]) then
                            list.set(n, "android.permission.UNKNOWN")
                        end
                    end
                end
                local pt = activity.getLuaPath(".tmp")
                local fo = FileOutputStream(pt)
                --写入编辑后的到axml缓存文件里
                xml.write(list, fo)
                local code = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0).versionCode
                fo.close()
                local f = io.open(pt)
                local s = f:read("a")
                f:close()
                --直接替换数字常量的版本号，sdk等
                s = string.gsub(s, touint32(code), touint32(tointeger(appcode) or 1),1)
                s = string.gsub(s, touint32(18), touint32(tointeger(appsdk) or 18),1)

                local f = io.open(pt, "w")
                f:write(s)
                f:close()
                local fi = FileInputStream(pt)
                --打到apk里
                copy(fi, out)
                --删除缓存
                os.remove(pt)
            elseif not entry.isDirectory() then
                --其他的就直接复制到apk里了，注意是zip流不能关所以用的copy2
                copy2(zis, out)
            end

        --获取下一个zip里的元素
        entry = zis.getNextEntry()
    end
end  
--md5表用在这。。
out.setComment(table.concat(md5s))
    --print(table.concat(md5s,"/n"))
zis.close();
out.closeEntry()
out.close()
```

### 4.签名apk

```lua
--没有出错的话
if #errbuffer == 0 then
    this.update("正在签名...");
    --删除旧的apk
    os.remove(apkpath)
    --签名
    Signer.sign(tmp, apkpath)
    --删除tmp
    os.remove(tmp)
    --启动安装apk
    activity.installApk(apkpath)
    return "打包成功:" .. apkpath
else
    --删除tmp
    os.remove(tmp)
    --弹出打包错误
    this.update("打包出错:\n " .. table.concat(errbuffer, "\n"));
    return "打包出错:\n " .. table.concat(errbuffer, "\n")
end
```

怎么样，这就给分析完了吧。很高兴你能看到这里，能看到这里的至少说明你对这方面感兴趣。

## 尾声

总结一下AndroLua+的打包流程吧。

> 它通过使用底包，检查导入库等方式，尽量用最小的库和代码实现打包功能，有很快的打包速度。由于本身是基于lua实现的，lua是可动态运行的，替换assets基本就可以实现一半的打包了。

其实熟读`bin.lua`还是很有用的，比如你可以扩展导入库的路径，自己用签名库等等，这是作为一个Lua《IDE》的基本功。

比较可悲的是有一些人都还没怎么会，就直接用bin.lua给androlua换了个UI就写出来所谓Lua《IDE》了。至少你得学学andlua嘛，人家后续也是有加上了java编译(感觉没大用)的功能。

下期还不知道出什么，评论区留言？
