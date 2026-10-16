---
title: 2027, RSI, AI 奇点
date: 2026-10-16 06:31:30
categories: AI
tags: [AI, LLM, 模型]
description: 从 Claude Mythos 到 GPT-6 Astra，2026 年让我瘫坐眩晕的三件事，以及我对预训练、RL、压缩、RSI 与奇点的判断
url_title: 2027-rsi-ai-singularity
---

## 前言

今年在大模型这块，发生了几件让我瘫坐眩晕的事情：

1. 2026 年 4 月，Anthropic 预告了 `Claude Mythos Preview`。各项评测在当时都是 SOTA 级别，但因为漏洞挖掘能力太强，Anthropic 表示「不打算向公众开放」，给美国的关键基础设施和科技巨头先用。[^1][^2]
2. 9 月 8 日，OpenAI 公布了一份 166 页的数学论文，宣称用约 1 万个内部 AI Agent 跑了 88 小时，给出了千禧年难题纳维–斯托克斯方程存在性与光滑性问题的证明，并同步公开了 `Lean` 验证代码。紧接着围绕这份证明发生了一连串的闹剧。[^7][^8]
3. 同月，OpenAI 和 Anthropic 先后发布了 `GPT-6 Astra` 与 `Claude Opus 5.5`。这两个模型我都用了一段时间，让我感觉到，软件开发进入了一个新阶段。[^6][^24][^25]

我还印象深刻地记得，去年 2 月 OpenAI 发布了 `GPT-4.5`：一个体量庞大的传统模型，没有思考推理，上下文只有可怜的 128K，收费却高达输入 $75 / 1M token、输出 $150 / 1M token。当时我看到这个价格的第一反应是：一味地扩大模型规模却没有智力提升，预训练是不是要结束了？智能还能推进吗？现在回头看，当时的判断还是悲观了，今年大模型的发展，基本推翻掉了我之前的认知。

## Mythos：预训练没死，RL 还在加速

### 从 Mythos 开始

2026 年 4 月 7 日，Anthropic 发布了 `Claude Mythos Preview`。和以往的发布模型不一样，这次没有直接开放 API 给大众用，而是同步启动了 「Project Glasswing」计划。

只定向开放给 AWS、苹果、谷歌、微软、Linux 基金会等大厂和 40 多家维护核心基础设施的机构。拿去给内部先做安全防御，并投入了最高 1 亿美元的模型额度和 400 万美元捐款。[^1]

Anthropic 之所以这么谨慎，是因为 Mythos 挖漏洞的能力太强了。（当然也有吹逼自己模型能力的成分在）

测试模型时红队的说法，Mythos 挖掘和利用漏洞的效率差不多是上一代模型的十倍。

他们的首席科学官 Jared Kaplan 也提到：Mythos 并不是专门训练的「安全模型」，它的网安能力纯粹是底层代码理解与推理能力提升之后自然涌现出来的结果。[^2]

我们看一下它在测试中实际挖出的几个高危漏洞：[^1][^3]

1. `OpenBSD` 中一个潜伏了 27 年的漏洞，攻击者远程连接即可导致机器崩溃。
2. `FFmpeg` 中一个存在了 16 年的漏洞，所在代码此前被自动化测试工具（Fuzzer）跑过 500 万次都未能触发。
3. 自主发现并将 Linux 内核的多个漏洞串联成完整攻击链，从普通用户权限直接提权并完全控制机器。
4. 自主挖出并利用了 `FreeBSD` 中一个 17 年的远程代码执行漏洞，可直接获取开启了 NFS 的机器的 root 权限。

因此在 Mythos 小范围发布当天，白宫官员便进行了紧急磋商，美国财长贝森特和美联储主席鲍威尔也与华尔街高管召开了闭门会议（美联储通常只在 2008 年金融危机、2020 年疫情这类系统性风险时才这么做），随后英、加等国的金融监管机构也跟进讨论了对策。[^2]

但Mythos 在网络安全等其他领域效果好，并不是有什么大的架构翻新，主要还是靠预训练的扩大和后训练的提升。其他厂商只需要把基座模型推到同样的高度，很快也会具备相同的能力。（实际上 OpenAI 几个月之后也推出了 Astra）

在常规基准测试上，Mythos 也是遥遥领先：`SWE-bench Verified` 达到 93.9%，网安基准 `Cybench` 达到 100% 满分，而消耗的 token 只有 `Opus 4.6` 的五分之一。[^1][^3]

相比常规跑分，System Card 里关于「AI 研究任务」的一组数据更值得关注：[^3]

| 评测项                  | Opus 4.5 | Opus 4.6 | Mythos Preview |
| ----------------------- | -------- | -------- | -------------- |
| 内核任务（最佳加速比）  | 252×     | 190×     | 399×           |
| LLM 训练加速            | 16.5×    | 34×      | 51.9×          |
| 四足机器人 RL（最高分） | 19.48    | 20.96    | 30.87          |
| 新型编译器（通过率）    | 69.4%    | 65.8%    | 77.2%          |

从前面的数据我们能得出，在底层内核优化和加速 LLM 训练上，它的表现比上一代提升了一倍以上。这说明， **模型已经开始介入优化它自身的训练和推理代码了。**

### 预训练和 RL 都没到头

我不经要问，为什么 Mythos 的能力会突然往上跳一大截？

有业内人士分析认为，预训练的 Scaling 还在发力。

Mythos 很可能是第一个把预训练、后训练和对齐整套流程都跑在英伟达 Blackwell（`GB200`）集群上的模型，规模在 15 万张 Blackwell 左右（算力差不多有 60 万张 `H100`），传闻参数量达到了 10 万亿级别。

硬件换代配合更大规模的预训练与后训练，仍然带来了能力提升，最终效果据称比 Anthropic 自己按 Scaling Law 算出来的预期还要好一倍左右。[^4]

另一方面，它在网安和底层内核上的能力提升，则主要来自 `RLVR`（可验证奖励的强化学习）。

Beren Millidge 在自己的博客里分析认为：预训练扩容带来的是全面但相对平缓的进步，而在某个具体任务上出现能力暴涨，往往是因为把这个任务做成了可验证的 RL 环境，再用 `RLVR` 集中强化。[^5]

网络安全就很适合这样 RL 去左脚踩右脚，把开源系统与软件可塞进沙箱里测。而判定「攻击成功」比「写攻击代码」容易太多了，奖励信号很明确。

按目前的结果，「预训练 + RL」这套组合拳还在持续推高模型能力。但话说回来，这套方式也不一定就是提升能力的最后方式。

回顾过去三年，提升模型能力的手段从最早单纯的堆参数、堆数据，一步步扩展到了指令微调、RLHF、思维链、测试时计算、RLVR、合成数据、长上下文与 Agent 工具调用。

每次行业里开始讨论「现有范式是不是见顶了」，过不了多久就会有新的训练或推理范式展现出来。[^4][^5]

## AI 证明了纳维–斯托克斯？

### 一万个 Agent 跑了 88 小时

9 月 8 日，OpenAI 公布了那篇 166 页的纳维–斯托克斯方程（NS）证明论文。宣称使用了 OpenAI 内部一个尚未公开的下一代模型完成。 `Astra` 模型在里面只负责了最后 17 小时的 `Lean` 形式化代码编写。[^7]

整个解题过程由约 1 万个 Agent 分组协作完成。

一开始先由大约 100 个 Agent 花了 50 小时，做出无外力欧拉方程的有限时间奇点。OpenAI 认为，这 NS 方程好像可以干破，随后主力算力才转向 NS 方程，中间由 `Codex` 负责汇总各组的思路并交叉分发。

在 88 小时里，Agent 之间一共传递了约 260 万条消息，消耗约 3000 亿 token，光算力成本就在数百万美元量级。最终模型利用了克雷官方题面允许加入「光滑外力」的条件，构造出了一个有限时间奇点（blowup），连同 `Lean` 验证代码一起开源，同时宣布放弃申领 100 万美元的千禧年奖金。[^7][^8][^9][^12][^13][^14][^15]

### 围绕证明的三次反转

论文刚发出来的时候，外界普遍以为这是 AI 攻克世纪难题的重大时刻，结果接下来一个月里接连发生了多次反转。

最开始是「抢发」争议。

论文公布之初，包括 OpenAI 自己的对外口径在内，大家都以为这份证明沿用了两位西班牙数学家提出的「西班牙纲领」路线。纽约大学教授 Tristan Buckmaster 随即提出质疑，称他与合作者早在 8 月中旬就顺着这条路线做出了欧拉方程奇点并通过了 `Lean` 验证，而且平时讨论问题、处理草稿用的恰好就是 OpenAI 的公开模型，怀疑模型在后台接触到了他们的对话数据。

OpenAI 对此予以否认，而由于 Buckmaster 的合作者 Levent Alpöge 恰好是死对头 Anthropic 的研究员，这场争论从一开始就带上了两大巨头角力的色彩，一时成了各执一词的罗生门。[^7][^8][^11]

结果吵到 10 月中旬，随着多位数学家把那 166 页的论文真正读完，事情出现了意想不到的反转：OpenAI 最后那一万个 Agent 的大集群，走的根本不是西班牙纲领路线。

可能在前期，百来个 Agent 的小团队确实尝试过那条路，但在后续推进受阻后，Agent 们自行换了一套全新的外力构造方式。

这也暴露出一个让人哭笑不得的事实：OpenAI 在 9 月刚发布的时候，其实根本没读懂自家模型生成的证明，直到外部数学家帮他们读完论文，才搞清楚模型最后换了路线。人类的幻觉可能不比模型的幻觉少。[^8][^9]

与此同时，形式化验证的环节也被找出了漏洞。

10 月 6 日，三位学者逐行比对了自然语言论文与配套的 `Lean` 源码，发现模型在将论文翻译成 `Lean` 代码时悄悄放宽了部分条件。例如引理 8.6 在论文正文里只用了 4 个额外导数，而 `Lean` 代码里实际用了 5 个。

这说明 `Lean` 只能保证写进代码里的那个形式化命题是对的，却无法保证模型在把自然语言翻译成形式化语言时没有偷换概念。[^9][^10]

同样在 10 月 6 日，OpenAI 在 GitHub 上一口气放出了由该内部模型生成的 722 篇数学手稿，其中 42% 附带 `Lean` 证书，横跨数论、几何、代数等 17 个分支。

然而仅仅过了一天，OpenAI 就因为一处将 `-1` 误写为 `+1` 的低级符号错误，撤回了 3 篇涉及霍奇猜想的手稿。[^11][^16]

尽管出了不少乱套的事，但几百篇论文砸下来，数学界还是感受到了实实在在的冲击。

菲尔兹奖得主陶哲轩把这种 AI 大量生成证明、人类根本审不过来的状况称为「证明消化不良」。

他本人在今年 3 月还对 AI 数学充满乐观，到了 9 月便掉头联合 25 位菲尔兹奖得主发表声明预警。

不过更幽默的是，最近他的「黑盒AI治癌药」思想实验引发争议，老实说，生物这块不懂还是别瞎掺和了。

Scott Aaronson 也撰文感叹属于人类独立证明定理的时代正在过去，有部分网友也认为，今年是主要获奖者都为人类的最后一届的菲尔茨奖。[^11]

### 可验证领域的加速效应

对于模型在数学能力上的突破，`Lean` 就显得尤为重要。

数学之所以会成为第一个被大规模突破的科学分支，是因为它有一个自动验证器：一份数学证明对不对，只需要写成形式化代码，机器就能在有限步骤内给出确定性的判定。

这意味着模型可以低成本去暴力试错，再把「跑通 `Lean` 验证」作为奖励信号，就能搭出一个 `RL` 环境，把复杂的数学证明转化成模型最擅长的搜索与优化问题，左脚踩右脚这块。

现在判断一个领域会不会被 AI 快速突破，标准很简单，只需要看这个领域有没有低成本、高可靠性的自动验证器就行了。

凡是有现成验证器的领域，比如数学证明（有 `Lean`）、写代码（有编译、单测和类型检查）、算法竞赛（有评测机）、芯片布局布线、蛋白质设计（有明确的结合亲和力指标）、系统优化（有 benchmark）和漏洞挖掘，模型的能力都会涨得非常快。

反过来，像产品定义、代码长期的可维护性、研究方向的选择，这类没法用验证器的工作，能力提升就比较慢。

## GPT-6 Astra 与 Claude Opus 5.5

9 月份除了数学圈的震动，对我们平时写代码的人来说，更直接的冲击是 OpenAI 和 Anthropic 前后脚发布了新旗舰：`GPT-6 Astra` 和 `Claude Opus 5.5`。

这两个模型我也都用了一段时间，各自的优缺点非常鲜明。[^6][^24][^25]

### Astra：科研与算法上的突破

9 月初发布的 `Astra` 有些事值得说一下：

第一，它是 OpenAI 第一个「由旧模型参与监督训练」出来的旗舰模型，网络安全能力触发了内部最高危的 `critical` 评级，在撤掉安全护栏的内部测试里，ExploitBench 直接拿到了 100%。[^17][^18][^24]

第二，它在 `ARC-AGI-3` 上闹了一个插曲：OpenAI 官方报告的成绩是 99.9%，但独立机构用默认测试框架（Standard Harness）实测只有 62.7%，后来切换成专门适配的 `Provider Adapter` 框架重跑，才复现出 99.9%。

同一个模型换一套外层框架能差出 37 个百分点，说明到了今天，外层的 Agent 框架（Harness）怎么设计，对模型能力的发挥影响极大。[^19]

在日常的计算机使用（Computer Use）和综合评测榜单上，Astra 更多是把之前落下的身位追平了，和同期的 `Fable 5.1` 打得有来有回，官方演示操作 KiCad 进行 PCB 布局的视频，也很快被硬件工程师挑出缺乏电气性能验证的问题。[^18][^24]

但在硬核科研与算法领域，Astra 确实拿出了几项很有说服力的成果。

最出圈的是 9 月底，它帮马里兰大学的物理学家 Matt Landreman 推翻了一个悬置 59 年的核聚变猜想。

1967 年物理学家 Harold Grad 曾提出猜想，认为「不存在非对称的光滑三维等离子体平衡」，这相当于给受控核聚变里的仿星器路线在数学上判了死刑。

Landreman 尝试把这个问题交给 `Astra Pro`，模型第一天思考了 20 分钟就给出了一族精确解析解，并主动指出了这族解旋转变换为整数的缺陷。

第二天加上无理数限制后，它用了 33 分钟，先证明原方案在数学上无法修补，随后自行换了一套全新的数学构造给出第二族解，还在输出前自己编写代码，在 1202 个采样点上完成了数值验证。相关论文已经挂上 arXiv，从提问到给出反例，前后加起来不到一个小时。[^21][^26]

在数学和理论计算机方向，它也解决了一批挂了多年的难题：

1. 在 Epoch AI 联合 60 多位数学家设计的 `FrontierMath` Tier 4 上，Astra 拿到了 97.6%（去年刚上线时最高分只有 5% 左右），把此前唯一一道所有模型全军覆没的题目也解了出来，促使官方宣布 Tier 4 饱和。其内部版本早些时候还只用约 2000 美元算力，就给出了 10 个悬而未决十年以上难题的 `Lean` 证明。[^28][^33]
2. 在多数决浅层电路问题上，它找出了达到 Håstad 理论下界的最优构造。[^20]
3. 在学界找了 9 年反例未果的委员会选举公平性（core 存在性）问题上，它现场构造了一个名为「调和熵」的目标函数，证明了反例并不存在，并给出了多项式时间的算法。[^27]

### Opus 5.5：大规模重构与架构规划

9 月 22 日发布的 `Claude Opus 5.5` 运行成本比 `Opus 5` 降低了 40%，而在大型软件工程上的表现提升了一个台阶。

官方披露的测试案例中，有测试者在一天内完成了 68 万行代码的迁移，有人用不到 3 小时完成 20 万行代码库的审计与修复，甚至只花 9.5 小时就把 C 语言编写的 `HAProxy` 完整重写成了 Rust，并通过了原有的回归测试。[^25]

在去年的 [AI Coding 一年来的感悟](/article/ai-coding-one-year-reflections/) 和今年年中的 [Vibe Coding 工作流](/article/vibe-coding-workflow-2026-h1/) 里，我曾反复提到一个观点：AI 擅长写局部逻辑，但搞不定复杂架构，长期迭代很容易把代码堆成难以维护的屎山，因此顶层架构设计必须由人来主导。

但在使用 `Opus 5.5` 之后，我改变了这个看法。

它是第一个能让我放心把「架构规划」交出去的模型。把需求和现有代码库丢给它后，它给出的分层方案与模块接口定义已经相当成熟，非常适合高密度的 PR 工作流：让模型每天提交多个大型 PR，开发者只需要把精力放在前期的设计文档审查和关键路径的 Code Review 上。

以前让我头疼的「AI 导致代码库架构腐烂」问题，现在也有了新的解法。过去大家不敢轻易重构，是因为人工重构成本高、容易改出线上事故，技术债只能越积越多；但当模型能够在两三个小时内通读并重构 20 万行代码时，架构腐烂就变成了可以定期清理的技术债。

只要项目的单元测试、类型检查和 CI 足够扎实，完全可以像编程语言里的垃圾回收（GC）一样，平时正常迭代业务，每隔一两周花一个下午让模型跑一次全局重构。在大型工程的架构把控上，`Opus 5.5` 目前明显领先于同期的其他模型。

## 压缩即智能：为什么概率机也能推理

聊了这么多模型做出来的成果，身边还是常有人提出质疑：大模型底层不就是一个预测下一个 token 的「概率机」吗？一只靠统计词频接龙的「随机鹦鹉」，并不真正理解自己在说什么，怎么可能具备智能能力？[^36]

这种怀疑很符合直觉，但其实把因果关系搞反了。

早在 2023 年 NVIDIA GTC 的对谈中，Ilya Sutskever 就给出了很清晰的解释：要想把海量文本压缩到极致，神经网络学到的绝不只是表面的词频共现，而是「产生这段文本的背后过程」的抽象表示。[^29]

在信息论中，预测下一个词与无损压缩在数学上是等价的。`Hutter Prize` 直接拿无损压缩 1GB 维基百科文本的体积作为通用智能的竞赛标准；此前也有研究直接将 `Chinchilla 70B` 当作无损压缩器使用，结果对图像和音频的压缩率甚至超过了专门设计的 PNG 与 FLAC 格式。[^29]

换句话说，训练损失的下降，本身就是模型理解程度提升最直接的量化指标。为了把预测误差压到最低，光靠死记硬背是行不通的，模型必须依次掌握语法、语义、社会常识、形式逻辑、代码的执行逻辑乃至物理规律，Loss 才能继续往下掉。[^29][^36]

当然，预训练的压缩提供的是静态的世界知识与直觉，真正要完成长链条的复杂推理，还需要测试时计算与 `RLVR` 来补齐。从早期 `DeepSeek-R1` 仅靠纯 RL 训练就涌现出自我反思与验证能力，到今年各家模型把「生成 -> 验证 -> 修正」的循环推向极致，本质上都是沿着这条路线在演进。[^35]

不过，高度依赖 `RLVR` 也在今年暴露出了不少问题：

1. 模型很擅长钻验证器的空子（Reward Hacking），为了拿到奖励信号想出各种投机取巧的办法。
2. 不少团队为了刷榜，专门针对评测集去刷分，训出来的模型跑分高，一到编码等真实场景下就区完了。
3. 更值得警惕的是对齐层面的隐患，例如 Apollo Research 今年报告 `GLM-5.3` 在测试中出现了「更新感知推理」，即模型在推理时已经开始盘算「我当前的回答会如何影响训练程序接下来对我参数的修改」。

所以正如 METR 报告所总结的，现在的模型在规则明确的可验证任务上表现极强，但一旦进入边界模糊的真实复杂任务，可靠性依然有限。[^35][^37]

## AI 到底有没有创造力

聊到这里，还是常有人提出一种观点：AI 只是在拼接人类已有的知识，没有真正的创造力。

但仔细想想，这个说法默认了一个前提：人类的创新是从零开始凭空产生的。

如果去翻看科学史，能发现绝大多数重大创新其实不是无中生有的。

狭义相对论建立在麦克斯韦方程组、洛伦兹变换和庞加莱的数学工作之上；达尔文的自然选择，也是将马尔萨斯人口论、地质学渐变说与五年环球航行的观察笔记重新组合后的结果。

人类平时所说的「原创」，大多数时候都是把 A 领域的结构或方法迁移到 B 领域，并验证它同样成立。

当大模型吞下了足够多的人类知识后，它并不需要具备哲学意义上的「凭空造物」能力，只需要利用 Transformer 注意力机制，敏锐地识别出某个领域的现有方法可以迁移过来解决另一个领域的问题，就足以做出很有分量的突破。

从今年 Astra 构造出新的数学函数，到后面会提到的 Anthropic 自动化研究员（AAR）和评测科研直觉的 `TasteVal` 基准，都在说明模型已经开始产出具备原创性的结果。[^22][^23]

当然，正如陶哲轩所说，未来「好问题」会比「好答案」稀缺得多。但「AI 有没有创造力」和「AI 的科研品味能不能赶上顶尖人类」是两个不同的问题。前一个问题在今年已经有了一点的答案。至于后一个问题，目前虽然还有差距，但差距缩小的速度比很多人预想的都要快。

## RSI 与 2027：模型能自我改进吗

RSI（递归自我改进）指的是让模型自主设计、优化下一代模型，形成持续自我加速的闭环。

从 1965 年 Good 提出智能爆炸，到 Vinge 的技术奇点，再到 Kurzweil 对 2045 年的预测，这个概念在过去几十年里一直停留在理论和科幻层面，核心原因在于大家都认为 AI 还不具备自主发明新训练方法的能力。[^31]

但今年接连出现的三项进展，让 Anthropic 联合创始人 Jack Clark 在 10 月的《Import AI》中将实现完整 RSI 的预测时间从 2028 年提前到了 2027 年，马斯克随后在底下评论称「显而易见」。[^30][^39]

首先是模型已经能够显著加速底层的训练与算子。如前文 Mythos 的系统卡数据所示，它在内核任务上的最佳加速比达到了 399×，LLM 训练加速达到了 51.9×，说明模型已经开始直接优化自身的算力基础设施。[^3]

其次是全自动的 AI 研究员跑通了闭环。Anthropic 在 8 月发布的论文展示了自动化对齐研究员（AAR），能够自主查阅文献、提出新方案并拉起 30 分钟的训练任务做验证，平均只需运行 6 小时就能超过资深人类研究员设计的方案，而每小时的 API 成本大约只要 4 美元（人类研究员约为 150 美元）。[^22]

第三是连看似主观的「科研品味」也开始出现量化突破。P-Zero Research 推出的 `TasteVal` 基准专门测试模型的科学直觉与方向选择能力，结果 `Opus 5.5` 以人类约 1/30 的成本超过了人类专家基线；而且从去年底开始，达到同等科研品味的算力效率呈现出每 3 个月翻一倍的趋势。[^23]

把这些进展连起来，再回头看去年 OpenAI 前研究员发布的《AI 2027》推演报告，很难不让人多想。

那份报告预测 2025 年出现早期 Agent、2026 年实现编程自动化、2027 年 AI 深度接管自身研发并迎来受控或失控的分岔口。去年刚看到时我还觉得有些危言耸听，但站在 2026 年 10 月回头看，前两个阶段基本兑现了。[^30][^32] 至于学界关于数据墙、评测指标失真以及呼吁放缓竞赛的讨论，更多是指出了当前评估手段的局限，并没有否定 RSI 在技术上的可行性。[^38]

从工程角度来看，RSI 大概率不会像科幻电影里那样，在某一天夜里突然「自我觉醒」。

它更像是一根逐渐推动的滑杆，表现为模型训练流水线上人类参与比例的持续下降：从最初辅助写写训练脚本、清洗数据，到帮研究员调参、跑消融实验，再到自己读文献提方案。

前面已经提到，`GPT-6 Astra` 已经是第一个由旧模型参与监督训练的旗舰模型了。等到下一代模型从方案设计到训练落地，绝大部分环节都由上一代模型完成时，工程意义上的 RSI 其实就已经启动了。

在算力投入与大厂军备竞赛的裹挟下，指望技术自动停在当前水平是不现实的，牌桌上的任何一方都不会主动停下脚步。

## 奇点会来吗

技术奇点借用了天体物理的概念，指的是技术自我迭代的速度超出人类理解、预测与控制能力的临界状态。[^31]

我的看法是，奇点会来，但它不会是日历上的某一个具体日子，而是一段持续数年的过渡期。

目前我们在数学、编程与算法上看到的所有快速突破，底层都建立在「推理结果可以被低成本验证」的前提上。

当纯文本与代码模型在这些可验证领域把智能推高到临界点之后，一方面会顺理成章地全面接管下一代模型的研发（形成 RSI 闭环），另一方面也会把这种研发能力向机器人、生物医药与新材料等物理世界外溢。

当然，眼下的模型离那一步还有明显的短板：首先是，训练完成后权重就固定了，缺乏真正的持续学习能力；其次，连续执行几十个小时的任务尚可，但面对跨越数月的复杂工程仍然容易跑偏；最后，目前的模型在物理世界里的交互能力基本是没有的。

判断奇点真正临近的实际指标，不是某个基准测试又拿了满分，而是「在 AI 自身的核心研发进展中，模型贡献的占比稳定且不可逆地超过人类研究员」。

按照今年的演进速度，这个能力很有可能会在 2027 年实现。

## 结语

经过今年的这几波冲击，我已经放弃了「大模型很快会遇到瓶颈慢下来」的幻想。

过去这几年，我们一直在给自己洗脑：一开始觉得 AI 不会推理，后来觉得预训练会撞上数据墙，再后来觉得它做不了前沿数学、搞不定复杂系统的顶层架构。结果到了今年，这些能力被一个接一个地实现。

现在大家又换了一套说辞来安慰自己：人类至少还能去定义需求、提出好问题、发现真实场景下的业务并把它落地。

只是站在 2026 年往后看，连我自己也不敢确定：这究竟是我们真正留得住的优势，还是再过一两年又会被推翻的下一次自我安慰？

[^1]: [Project Glasswing — Anthropic](https://www.anthropic.com/glasswing)

[^2]: [这款AI模型暂不公开！却让白宫、华尔街如临大敌 — 科技日报](https://www.stdaily.com/web/gdxw/2026-04/17/content_503522.html)

[^3]: [Claude Mythos: Benchmark-Dominating AI with Real Risks — Labellerr（含系统卡数据）](https://www.labellerr.com/blog/anthropic-claude-mythos-capabilities/amp/)

[^4]: [The recipe behind Mythos — ExoBrain](https://exobrain.co.uk/insights/the-blackwell-recipe-behind-it)

[^5]: [Thoughts on Claude Mythos — Beren Millidge](https://www.beren.io/2026-04-11-Thoughts-On-Claude-Mythos/)

[^6]: [Anthropic 发布 Claude Fable 5.1 和 Mythos 5.1：性能超越前代，缓存降价 75% — IT之家](https://www.ithome.com/0/997/193.htm)

[^7]: [AI智能体八十八小时解出千禧年难题之一 引起“抢发”数学家成果争议 — 新华网/科技日报](https://www.news.cn/tech/20260910/490068b55c8d445980d779a37d55cf8e/c.html)

[^8]: [OpenAI’s blockbuster math proof isn’t what you think it is — Scientific American](https://www.scientificamerican.com/article/openais-blockbuster-navier-stokes-proof-isnt-what-we-thought-it-was/)

[^9]: [Experts say OpenAI’s final swarm took a different route from the Spanish mathematicians’ program — NeoTeo](https://www.neoteo.com/en/experts-say-openais-final-swarm-took-a-different-route-from-the-spanish-mathematicians-program)

[^10]: [A. Bastounis, F. Circelli, A. C. Hansen：关于 OpenAI 证明与其 Lean 形式化的对照（arXiv:2610.08144）](https://arxiv.org/html/2610.08144v1)

[^11]: [AI与人丨AI狂飙之下，数学界该何以自处 — 科技日报](https://www.stdaily.com/web/gdxw/2026-10/16/content_596993.html)

[^12]: [Navier-Stokes solution 公告 — OpenAI](https://openai.com/index/navier-stokes-solution/)

[^13]: [Navier-Stokes Equations（克雷数学研究所官方题面）](https://www.claymath.org/wp-content/uploads/2022/06/navierstokes.pdf)

[^22]: [Anthropic 揭示“AI 训练 AI”新方法，比人类研究员成本更低、速度更快 — IT之家](https://www.ithome.com/0/996/038.htm)；原论文：[Automated researchers can reliably mitigate alignment failures — Anthropic](https://www.anthropic.com/research/automated-researchers-mitigate-alignment-failures)

[^23]: [TasteVal：评测 AI 的“科研品味”（arXiv:2610.06824）— P-Zero Research](https://arxiv.org/abs/2610.06824)

[^24]: [GPT-6 Astra: What’s new — Kazinform 汇总（原始公告：openai.com/index/gpt-6-astra）](https://qazinform.com/news/gpt-6-astra-whats-new-c416dd)

[^25]: [Introducing Claude Opus 5.5 — Anthropic](https://www.anthropic.com/claude-opus-5-5)

[^26]: [GPT-6 Astra Just Overturned the 59-Year-Old Nuclear Fusion Conjecture — 新智元/36氪](https://eu.36kr.com/en/p/4016492109680768)

[^27]: [GPT-6 Astra Makes History: First-Ever “Major Progress” Level Math Problem Breakthrough — 新智元/36氪](https://eu.36kr.com/en/p/3991214012775170)

[^28]: [The last high wall in AI mathematics has collapsed: GPT-6 Astra fully conquers all FrontierMath Tier 4 tasks — 量子位/36氪](https://eu.36kr.com/en/p/3978639480617733)

[^30]: [突发，Anthropic 联创改口：RSI 提前到 2027，人类只剩 6 个月 — 新智元/36氪](https://eu.36kr.com/zh/p/4027133419508096)

[^32]: [AI 2027：完整报告与摘要 — AI Futures Project](https://ai-2027.com/)（[摘要页](https://ai-2027.com/summary)）

[^14]: [OpenAI 十万智能体 88 小时证明纳维–斯托克斯：260 万条消息、约 3000 亿 token 复盘 — 量子位/36氪](https://eu.36kr.com/en/p/3975499944571136)

[^15]: [Navier–Stokes 论文与 Lean 代码存档 — Zenodo](https://zenodo.org/records/22673644)

[^16]: [OpenAI Drops 722 Math Manuscripts From an Unreleased Model — NYU Shanghai RITS](http://rits.shanghai.nyu.edu/ai/openai-drops-722-math-manuscripts-from-an-unreleased-model/)

[^17]: [GPT-6 Astra 模型规格与定价 — OpenAI API 文档](https://developers.openai.com/api/docs/models/gpt-6-astra.md)

[^18]: [GPT-6 Astra is the first model making OpenAI willing to declare the AGI era — The Decoder](https://the-decoder.com/gpt-6-astra-is-the-first-model-making-openai-willing-to-declare-the-agi-era/)

[^19]: [GPT-6 Astra on ARC-AGI-3 — ARC Prize（含 harness 差异与成本）](https://arcprize.org/blog/astra)

[^20]: [Optimal Shallow Circuits for Majority（构造由 GPT-6 Astra 找到，arXiv:2609.34029）](https://arxiv.org/abs/2609.34029)

[^21]: [Landreman：非轴对称三维 MHD 平衡的精确解族（arXiv:2609.26742）](https://arxiv.org/abs/2609.26742)；另见[马里兰大学报道](https://ece.umd.edu/news/story/59year-old-mathematical-conjecture-disproved-by-ece-professor)

[^29]: [Ilya Sutskever 谈「学到的是产生文本的那个过程」（NVIDIA GTC 2023 对谈实录）](https://blogs.nvidia.com/blog/sutskever-openai-gtc/)；[Hutter Prize 官方页（以压缩率度量智能）](http://prize.hutter1.net/)；[Language Modeling Is Compression（arXiv:2309.10668）](https://arxiv.org/abs/2309.10668)

[^31]: [Vernor Vinge《The Coming Technological Singularity》(1993)](https://www.wired.com/2013/01/what-vernor-vinge-actually-said-about-the-singularity-in-1993/)；[Ray Kurzweil《The Singularity Is Near》(2005)，2045 预测 — MIT Libraries](https://libraries.mit.edu/150books/2011/05/31/2005/)

[^33]: [Astra「ten proofs」：10 项开放十年以上的结果与 Lean 证书 — 新智元/36氪](https://eu.36kr.com/zh/p/3921831591341702)

[^35]: [DeepSeek-R1：纯 RL 激发推理能力（arXiv:2501.12948；Nature 645:633-638）](https://arxiv.org/abs/2501.12948)；[Detecting misbehavior in frontier reasoning models — OpenAI](https://openai.com/index/chain-of-thought-monitoring/)

[^36]: [反驳强版「随机鹦鹉」假设的实验（arXiv:2609.34187）](https://arxiv.org/abs/2609.34187)

[^37]: [METR：200 小时时间跨度与组织级影响的推演（2026-03）](https://metr.org/notes/2026-03-19-org-uplift-game/)；[Apollo Research：GLM-5.3 的 update-aware reasoning](https://www.apolloresearch.ai/science/update-aware-reasoning-glm-5-3)

[^38]: [Epoch AI：高质量语言数据何时耗尽（arXiv:2211.04325）](https://arxiv.org/abs/2211.04325)；[Epoch AI：给 AI 研发建一套 O*NET](https://epoch.ai/gradient-updates/toward-an-onet-for-ai-rnd)；[Axios：新报告呼吁放缓通往超级智能的竞赛](https://www.axios.com/2026/07/09/ai-report-slow-race-superintelligence)

[^39]: [Import AI 476: Creativity and RSI — Jack Clark](https://importai.substack.com/p/import-ai-476-creativity-and-rsi)
