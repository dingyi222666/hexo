---
title: ipv6 折腾记：如何让自己家里的宽带支持 ipv6
date: 2022-06-27 15:59:07
tags:
  - 折腾
  - ipv6
category: 
  - 折腾  
description: 让我的家庭宽带用上 ipv6
headimg: https://s2.loli.net/2023/08/20/1sCgRxSVQUBDyqE.webp
url_title: use-ipv6
---

## 缘起

最近脑子一热，想在公网上访问到自己内网里的一些资源，搜索了一番发现申请 ipv4 的公网地址好像有点困难，ipv4 的地址明面上已经被用尽了，而且我所在的广西电信这里不在提供公网 ipv4 的服务了...

![广西电信-停止提供普通宽带公网 ipv4](https://s2.loli.net/2022/06/27/AtETIgoK2BWry5z.jpg "甚至在网用户也没有了")

但虽然 ipv4 没了，这不还有 ipv6 嘛，号称“其地址数量号称可以为全世界的每一粒沙子编上一个地址[\[1\]]。

## 折腾

一开始当然是善用搜索引擎，去搜索怎么开启 ipv6。

搜索了一番，大部分教程都和[这个](https://zhuanlan.zhihu.com/p/427678572)差不多一样的,主要的操作就是在光猫或者路由器的拨号页面，把 ip 模式选成 ipv4&ipv6 双栈。

![看图](https://pic3.zhimg.com/80/v2-d93980007e978fa4c03ccb1577d90852_720w.jpg)

我也照着他设置了一下，不过我是用路由器去拨号的，也有上面那个选项，直接选中保存就行了。

![QQ图片20220627162134.png](https://s2.loli.net/2022/06/27/mzr5PtoHSBNdw6Z.png)

然而事情并没有那么简单，直接勾选应用了之后并没有获取到 ipv6 的地址...

![QQ图片20220627162428.png](https://s2.loli.net/2022/06/27/qDcFYoTuUwpnZx1.png)

好家伙，压根都没有分配地址。又试了下 ipv6test 的测试结果：

![QQ图片20220627163004.png](https://s2.loli.net/2022/06/27/JZYkPdU1h9Nut3w.png)

我注意到了这句

> 你的DNS服务器(可能由运营商提供)已经接入 ipv6 互联网了。

好家伙，难道是运营商支持，却默认没给你获取 ipv6 地址的权限？说好的推进 ipv6 部署呢？没办法，我只能去问客服了，不过这个过程还是很轻松愉快的。客服也知道我的要求，让我留下户主身份证和电话号码，然后就等答复了。

![QQ图片20220627163856.jpg](https://s2.loli.net/2022/06/27/IvNydHBLuaOMUFk.jpg)

差不多是 2 天后，也就是 27 号今天，电信客服打电话跟我说帮我开通了。很快啊，我重复上面的操作，这次就获取到 ipv6 的地址了。

![QQ图片20220627164305.png](https://s2.loli.net/2022/06/27/UIZJfYHAiywnzjR.png)

再去 ipv6test 测试一下，这下就舒服了。

![QQ图片20220627164134.jpg](https://s2.loli.net/2022/06/27/QIOFoJiTcw2kylP.jpg)

这回就成功用上 ipv6 了。。

## 结语

这次折腾主要时间都浪费在了等运营商给我开通 ipv6 上。。也不知道广西电信怎么想的，说好的推进 ipv6 部署呢？

~~折腾完了又发现，因为路由器防火墙的原因，外网并不能访问到我这个 ipv6 的公网地址，防火墙直接给超时丢包了...只能去pdd搞了个路由器，等路由器到货了在继续折腾吧。~~

~~（也不知道什么时候能用 ipv 6开 mc 的服务器~~ （其实已经可以了）

update: 无法访问是因为 windows 的防火墙，😅

[\[1\]]:https://www.sohu.com/a/208692922_99958604
