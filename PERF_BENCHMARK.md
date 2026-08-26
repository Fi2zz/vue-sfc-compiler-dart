# PERF_BENCHMARK — 性能基准方案（2026-08-25 定稿；2026-08-26 首期已实施）

> 目的：为投产评估提供数据支撑。回答三个问题——单核吞吐多少、FFI 占比多少、并发能否线性扩展。
> 与 HANDOFF.md（路线）、OXC_REFERENCE.md（TS 解析后端）互补。
>
> 运行方式：`dart run bench/gen_large.dart && dart run bench/bench.dart --runs=300 --warmup=30 --out=bench/results/<name>.json`

## 首期结果（2026-08-26，macBook arm64 / Dart 3.12.2 JIT / 10 核，runs=300）

**全管线吞吐**（预热后 P50）：

| 档位 | 文件数 | 单轮 P50 | 吞吐 |
|---|---|---|---|
| tiny | 5 | 0.25ms | ~19,800 files/s |
| typical（真实 SFC top20） | 20 | 0.36ms | ~55,700 files/s |
| ts_heavy | 5 | 0.45ms | ~11,100 files/s |
| tmpl_heavy | 5 | 1.19ms | ~4,200 files/s |
| large（10x/50x 合成，34KB） | 2 | 9.67ms | ~207 files/s |
| error（快速失败路径） | 5 | 0.03ms | ~166,700 files/s |

**TS 解链路分段**（ts_heavy 5 个 script，每轮）：FFI(含 JSON 传输) **81µs** ≈ 81%，mapper **5µs** ≈ 5%，全链 100µs。→ TS 解析成本由 Rust+JSON 序列化主导，Dart mapper 可忽略；优化方向在 worker 的序列化格式而非 mapper。

**isolate 并发**（typical 语料，300 轮）：1x=41ms 基准 → 2x=1.78、4x=**2.41**、8x=**2.41**。4 隔离后饱和（P/E 核混合 + GC 争用），服务端并行编译有效但非线性。

**内存**：各档 RSS 增量 0.3–10MB/300 轮，无泄漏信号。

结论：JIT 预热后典型 SFC 单核 >5 万 files/s，对构建工具场景余量充足；瓶颈排序 FFI/JSON > codegen > mapper。

## 首期结果补充：AOT 对比（2026-08-26，同机 `dart compile exe`，参数一致 runs=300）

| 档位 | JIT P50 | AOT P50 | 加速 |
|---|---|---|---|
| tiny | 252µs | **59µs** | **4.27x** |
| typical | 359µs | **127µs** | 2.83x（≈**157k files/s**） |
| ts_heavy | 449µs | 213µs | 2.11x |
| tmpl_heavy | 1192µs | 853µs | 1.40x |
| large(34KB) | 9669µs | 8936µs | 1.08x |
| error | 30µs | 22µs | 1.36x |

- 小文件受益最大（JIT 编译开销占比高）；越大越接近 FFI/IO 下限（large 仅 1.08x）
- TS 链路分段：FFI 81→72µs、mapper 5→4、全链 100→88µs——Rust 段与 AOT 无关，Dart 侧 jsonDecode 略降。**AOT 下 FFI 占比升至 ~82%，JSON 跨界传输是 TS 重负载场景的第一瓶颈**
- 并发：AOT 扩展性更好——8 isolate 达 **2.77x**（JIT 2.41x，无 JIT 编译器线程争抢）

投产含义：服务端常驻进程应使用 AOT（`dart compile exe`）部署；TS 重负载若需再提速，优先改 worker 序列化格式（二进制/零拷贝），其次才是 Dart 侧。

## 首期结果补充：官方 @vue/compiler-sfc 3.5.41 同机对照（2026-08-26，node v23.5.0/V8，runs=300）

`bench/bench_official.mjs` 与 Dart runner 同语料同方法（共享 `bench/corpus_shared.json`）。三方最新一轮（pointAt 优化后）：

| 档位 | 官方 P50 | Dart-JIT P50 | Dart-AOT P50 | AOT vs 官方 | P90 口径 |
|---|---|---|---|---|---|
| tiny | 183µs | 267µs | **75µs** | **2.45x 快** | 3.36x |
| typical | 271µs | 364µs | **120µs** | **2.26x 快**（166k vs 74k files/s） | 2.14x |
| ts_heavy | 343µs | 459µs | **220µs** | 1.56x 快 | 2.04x |
| tmpl_heavy | 955µs | 1215µs | **892µs** | 1.07x 快 | 1.48x |
| large(34KB) | 7800µs | 9589µs | 8708µs | 0.90x——慢 10% | 0.93x |
| error | 98µs | 30µs | **23µs** | **4.26x 快** | 4.75x |

**进程冷启动对照**（CLI 单文件场景，tiny runs=1 含进程启动）：
`dart compile exe` 二进制 **~11ms**；node + require compiler-sfc **~638ms（58 倍差距，由模块加载主导）**。按文件派生子进程的构建集成场景下 AOT 优势压倒性。

结论与行动项：
1. 中小 SFC（构建工具主场景）Dart-AOT 领先官方 2–4 倍，P90 口径优势更大。
2. **大文件是唯一落后项**——分段画像（large_50：tmpl=6.8ms 61% / script=2.0ms / ts链=1.1ms / parse+style=1.2ms）显示大头在**模板管线**而非 mapper。已落地 `pointAt` 二分（mapper 段 -44%，端到端 -2.6%），差距从 13% 收窄到 11%。**剩余差距要靠模板侧优化**（codegen 字符串拼接/空白处理），是独立的大工程，未排期。
3. 官方对照跑法已固化进 bench 工具链，后续每次优化重跑三份 JSON 即可回归对比。

## 二期终版：四种基线方案统一对照（2026-08-26，AOT 交错三轮取中位）

**背景量化**：large_50 单次模板编译原触发 **601 次 FFI 往返**（逐表达式一次）。
单次往返分解：Rust 解析+序列化 0.26µs(9%) / jsonDecode 1.64µs(56%) / 其余为
分配与包装。四种消除策略同热状态交错实测（`--tier=large --runs=150` × 3 轮）：

| 方案 | 机制 | large P50 中位 | vs off | 状态 |
|---|---|---|---|---|
| off | 逐表达式独立 FFI ×N | 11.92ms | 基线 | 已被替换 |
| **concat（推荐默认）** | 全部表达式拼成 `[e0,e1,…]` 单次解析 + span 再基线，零 FFI 契约变更 | **9.99ms** | **-16.2%** | ✅ 默认启用 |
| ffi（方案 A） | 新符号 `oxc_parse_batch`，一次往返返回 JSON 数组 | 10.63ms | -10.8% | 可用 |
| bin（方案 B） | OXB2 标签二进制 + ByteData 惰性视图直读 | 11.22ms | -5.9% | 对照保留 |

其余档位（tiny/typical/ts_heavy）经 ≥8 表达式阈值保护全部与 off 持平；
官方 @vue/compiler-sfc 同状态 large 对照 = 7.50ms。

**方法论教训（重要）**：早期"concat 净负收益"的结论来自跨会话顺序测量，
被机器热漂移污染——本轮改为**模式交错×多轮中位**后结论反转。任何 A/B 性能
对比必须交错采样；PERF_BENCHMARK 的对比表一律以同轮数据为准。

**解码层微基准**（207 表达式批量 transport+decode，三轮实测）：JSON+jsonDecode
≈1050µs；OXB2+纯 Dart ByteData 视图 ≈1500µs（**bin ≈ json 的 142–149%**）。
键表内联（OXB2 相比初版内联键编码 2317µs 已提速 ~35%）仍不敌原生 C 解码器
——同抽象层级下 Map 中间层的消灭在 Dart 侧无胜利路径。⚠️ 勘误：本文档曾误记
bin=13.4ms(16 倍)，系修复键表 bug 后未重测的无依据数字，2026-08-26 实测更正。

**最终状态**：
1. 默认 `TS_EXPR_BATCH=concat`；off/ffi/bin 保留作对照与回退（env 可切）。
2. `oxc_parse_batch`/`_bin`、EstNode 接口、BinEstNode 全部保留：mapper 与
   传输解耦，未来协议演进只动实现类。
3. 差分器 `tools/diff_transport.dart` 固化为传输层改动的强制门禁
   （452 条三见证逐字节对拍）。
4. 遗留差距：large 档 vs 官方仍慢 ~33%（9.99 vs 7.50），瓶颈在模板管线
   结构性成本（非表达式链路），未排期。

## 三期复跑：三模式对照 + bin 传输复测（2026-08-26，runs=300）

同机串行重跑 JIT / AOT / 官方三份 + `TS_EXPR_BATCH=bin` 两份（JIT/AOT），
结果存 `bench/results/2026-08-26-macbook-{jit,aot,official-node,jit-bin,aot-bin}.json`。

**全管线 P50（µs/轮，各档从快到慢）**：

| 档位 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| tiny | AOT-bin 61 | AOT 103* | 官方 159 | JIT-bin 270* | JIT 451* |
| typical | AOT-bin 123 | AOT 124 | 官方 260 | JIT 361 | JIT-bin 362 |
| ts_heavy | AOT 234 | AOT-bin 243 | 官方 333 | JIT 482 | JIT-bin 484 |
| tmpl_heavy | AOT 914 | 官方 941 | AOT-bin 1182 | JIT 1252 | JIT-bin 1642 |
| large(34KB) | 官方 7529 | AOT 9913 | JIT 10509 | AOT-bin 11623 | JIT-bin 12468 |
| error | AOT/AOT-bin 23 | JIT 29 | JIT-bin 30 | 官方 95 | — |

\* tiny 档同机两次跑出 61–451µs 分布，<500µs 量级在本机不可用于回归判断；
回归锚点用 typical / ts_heavy（各模式漂移 ±7% 内）。

**bin vs concat**：bin 仅影响 ≥8 表达式档位（阈值保护生效），tmpl_heavy 慢 29–31%、
large 慢 17–19%，其余档位持平。二期"concat 默认、bin 对照保留"结论复测成立。
本轮为串行非交错采样，但差距远大于热漂移幅度，方向可靠。

**漂移项（vs 二期记录）**：AOT large 9913 vs 8708（+14%）、JIT large +10%——
建议冷却后单跑 large 复核；typical/ts_heavy/tmpl_heavy 无实质回归。

**RSS 异常（待排查）**：large 档 300 轮 RSS 增量 ~1.1GB（JIT/AOT 同量级），
tmpl_heavy ~90–130MB，与首期"0.3–10MB/300 轮无泄漏信号"矛盾。
需连跑 3000 轮看 RSS 是否 plateau：plateau 为 GC 行为，线性涨为泄漏。
**常驻服务部署前必须查清。**

### large 档分段画像（large_50，探针直测，µs/次）

探针：`tools/_seg_probe.dart`（管线分段）、`tools/_tmpl_probe.dart`（模板子段），
AOT 二进制在 `bench/build/{seg,tmpl}_probe`。

| 阶段 | JIT | AOT |
|---|---|---|
| SFC parse | 386 | 513 |
| script（FFI+JSON） | 2102 | 1997 |
| **template 全段** | **8157 (71%)** | **6072 (64%)** |
| style | 852 | 876 |
| 其中 baseParse | 880 | 359 |
| 其中 **transform+codegen** | **7512 (90% of tmpl)** | **5727 (94% of tmpl)** |

**官方同模板子段对照**（`tools/_tmpl_probe.mjs` + `tools/_tmpl_split_probe.dart`，
后者 1:1 复刻 compileTemplateSource 私有选项装配，AOT 交错 3 轮取中位，µs/次）：

| 配置 | baseParse | transform(含表达式解析) | codegen | 模板全段 |
|---|---|---|---|---|
| 官方 (V8, prefixIdentifiers=true) | 1308 | 1626 | 790 | 3747 |
| Dart-AOT concat | ~500 | **4764** | **938** | ~6100 |
| Dart-AOT bin | ~400 | **5786** | **780** | ~7000 |

（官方口径已修正：compileTemplate 实际使用 prefixIdentifiers=true——
实测该标志使官方 baseParse 从 ~300 涨到 ~1300（交错 A/B 验证，
`tools/_parse_ab.mjs`），transform 含逐表达式 Babel 解析。
此前 prefixIdentifiers=false 探针（359/1163/753/2253）低估了官方成本，作废。
Dart-JIT 拆分探针数据不可用：减法式计时在 JIT 下出现负值，
分层优化/GC 干扰所致；JIT 档位级数据以 bench 300 轮为准。）

补充结论：
1. **baseParse Dart 反而快 2.6x（~500 vs 1308）**——tokenizer/parser 层
   移植不仅无差距，还领先；codegen 基本持平（938 vs 790，~1.2x）。
2. **差距精确锁定 transform：Dart-AOT 4764 vs 官方 1626 = 2.9x**。
   优化目标从整个模板段收窄到 transform 一段；模板全段差距 1.63x
   （6100 vs 3747），端到端 large 档差距（0.76x 慢 32%）另有 script 段
   （FFI+JSON ~2ms vs 官方 Babel）的贡献。
3. **表达式解析是 parity 必需，不是可省项**（修正此前错误判断）：
   官方 transformExpression 同样逐表达式 Babel 解析；Dart 的
   `_fillExprCache` concat 批处理（~1ms）已是该子任务的优化形态。
4. bin 的代价精确落在 transform 段（+~1000µs：OXB2 惰性视图在节点属性
   访问时解码，transform 是访问最密集的阶段），codegen 反而略降；
   与 bench 档位级差距同源；baseParse 不受影响。


结论：
1. **large 档落后的账主要在 transform 一段**（2.9x 慢于官方；codegen 持平、
   baseParse 反快 2.6x、script 段 FFI ~2ms）。AOT 把模板段压 26%，已榨干
   "编译器优化"层收益；剩余差距是 transform 的结构性成本（对象分配模式 +
   V8 分代 GC 对编译器类负载的天然优势）。
2. 追赶是大工程（分配削减 / `_weaveComments` 类平方级路径排查），
   且须保住 `tools/diff_transport.dart` 452 条对拍门禁；
   34KB SFC 非主场景，投入产出比低，维持"未排期"。动手前先用
   Dart DevTools allocation profiler 拿真实分配画像。
3. 表达式链路（`_fillExprCache` concat 解析）位于 transform 段内部，
   ~1ms 量级，且为 parity 必需（官方 transformExpression 同样逐表达式
   Babel 解析）；即使归零也填不平 2.9x 的 transform 差距。

**投产评估三问的最终答案**：单核吞吐 typical ~16 万 files/s（AOT）、
FFI 占 TS 链路约八成（优化空间在 Rust 序列化侧）、并发 4 isolate 饱和 ~2.4x。
**可投产；跟进项：① 查清 large 档 RSS 行为；② 模板管线大文件优化排期。**

### 待办清单（按优先级）

**P0 — 投产前必须完成**

1. **查清 large 档 RSS 行为**。300 轮 RSS 增量 ~1.1GB 与首期"0.3–10MB/300 轮
   无泄漏信号"矛盾。方法：large 档连跑 3000 轮记录 RSS 曲线——plateau 为
   GC 行为（可接受），线性涨为泄漏（阻塞常驻服务部署）。

**P1 — transform 优化的前置侦查**（目标段已收窄：transform 2.9x vs 官方，
codegen 持平、baseParse 反快 2.6x）

2. ~~复查非 inline 模式表达式解析的必要性~~ **已结案（不成立）**：
   compileTemplate 实际用 prefixIdentifiers=true，官方 transformExpression
   同样逐表达式 Babel 解析；`_fillExprCache` 为 parity 必需，不可跳过。
3. **Dart DevTools allocation profiler 拿 transform 段真实分配画像**后再动手；
   禁止凭猜优化。重点看：节点对象分配、字符串中间产物、`_weaveComments`
   类平方级路径（文档坑位清单第 4 条已点名）。
4. 任何 transform 改动必须过 `tools/diff_transport.dart` 452 条对拍门禁 +
   全量样例回归；性能结论必须用交错采样（二期方法论教训）。

**P2 — 数据质量**

5. **冷却后单跑 large 档复核**：本轮 AOT large 9913µs 比二期记录（8708）高 14%，
   需排除热漂移后再判断是否有真实回归。
6. 回归锚点档位固定为 typical / ts_heavy（漂移 ±7% 内）；tiny 档（<500µs）
   与 JIT 探针级减法计时均不可用于回归判断（本轮实测噪声证据）。

## 四期：transform 冗余解析修复 + 待办清单结案（2026-08-26）

**根因**（代码审查定位，探针实测佐证）：large_50 每次编译在批缓存之外还有
**250 次独立 FFI 表达式解析**（v-model ×100、v-on ×100、v-for source ×50，
单次 ~7.9µs ≈ 2.0ms，占纯 Dart transform 的 54%）：
1. `isMemberExpressionOf`/`isFnExpression`（transform_expression.dart）对同一
   表达式全新解析，不查 `exprCache`——官方这两个谓词是零解析的 AST 类型检查
   （baseParse 已把 AST 挂在 `exp.ast`），Dart 侧 `node.ast` 字段从未写入。
2. v-for 整支 exp（`x in list`）被收集进批处理但无消费者（白占 24% 名额），
   而真正被消费的 `forParseResult.source` 未收集（每次编译 50 次独立解析）。

**修复**（输出零变化，全部过门禁）：
- 两个谓词先查 `exprCache['(source)']`（树含 ERROR 或未命中回退独立解析）；
- 批收集跳过 v-for 整支 exp、改收 `forParseResult.source`（key 对齐消费方）；
- 顺带修 `v_once_memo.dart` 模块级 `_seenOnce/_seenMemo` 跨编译泄漏
  （官方用 WeakSet；改为 `transform()` 入口清空）；
- P1 分配批次：循环内 RegExp 构造提升顶层 / code-unit 区间判断、
  `locStub()` 收敛共享实例（已确认无 mutate 点）、`textOf` 去重。

**门禁**：452 条对拍 0 mismatch；批量回归 783/786（3 个 DIFF 经 stash 前后
对照确认为既有遗留，基线 772 已过时）；dart test 13/13；样例 v1–v4 全 EXACT。

**效果**（AOT，large_50 / large 档，多次取中位）：

| 指标 | 修复前 | 修复后 | 变化 |
|---|---|---|---|
| transform 段 | 4764µs | **~2250µs** | **-53%** |
| 模板全段 | ~6100µs | ~3500µs | -43% |
| bench large P50 | ~9800µs | **7294µs** | -26% |
| tmpl_heavy P50 | 914µs | 742µs | -19% |

**large 档首次追平并反超官方**（7294 vs 7529µs）——唯一落后项摘帽。
transform 对官方差距从 2.9x 收敛到 ~1.4x（2250 vs 1626），剩余为
fill 批解析 ~1ms（parity 必需）+ 分配模式差异。

**修复后三模式复跑**（runs=300，覆盖更新三期三份 JSON）——
**六档 Dart-AOT 全部第一**：

| 档位 | AOT | 官方 | JIT | AOT vs 官方 |
|---|---|---|---|---|
| tiny | **82** | 159 | 265 | 1.93x 快 |
| typical | **129** | 268 | 375 | 2.08x 快 |
| ts_heavy | **247** | 340 | 530 | 1.37x 快 |
| tmpl_heavy | **748** | 944 | 1135 | 1.26x 快（修复前 1.03x） |
| large | **7178** | 7476 | 7879 | 1.04x 快（修复前慢 32%） |
| error | **24** | 96(JIT 32) | 32 | 4.0x 快 |

附带改善：large RSS 增量 ~1.1GB → ~675MB（-39%，250 次解析消除的直接
效果）；large P90 20428 → 13520µs，尾延迟改善大于 P50。TS 链路分段与
并发加速比无变化（修复只动模板表达式链路）。

**三期判断修正**：三期"transform 差距是结构性成本、追赶是大工程、未排期"
的结论是**错误的**——真实主因是移植遗漏造成的重复工作（250 次冗余解析），
一次小改动即收复大部分差距。教训：先查"是否多做了工作"，再谈"结构性成本"。

**待办清单结案**：
1. P0 RSS：**非泄漏，是 GC 行为**——3000 轮轨迹前 ~1500 轮爬升至 ~2.7GB
   后，后 1500 轮在 1.8–2.7GB 区间震荡、包络不上行（探针
   `tools/_rss_probe.dart`）。注意点为峰值堆驻留偏高，非阻塞项。
   另修的 v-once/v-memo 泄漏见上。
2. P1.2 已结案（parity 必需）；P1.3 审查完成并落地修复（本节）。
3. P2.5 large 复核：修复前 9775µs（仍高于二期 8708，min 7655 指向热漂移），
   修复后 7294µs 已远低于二期记录，回归疑虑消除。
4. ~~剩余可选优化~~ **已落地（2026-08-26，be6421a）**：`SrcView._buildMap`
   纯 ASCII 快路径（恒等映射，跳过 utf8.encode+建表）、`hoist_static`
   toCache 惰性分配、`expression_walk` 空作用域 const 复用。交错采样：
   模板探针 sum -6.7%、large 端到端 -1.4%，无回归。表达式重建分配簇
   （KnownIds/ExpressionWalker 复用）因状态重置有行为风险，放弃。
   此后 Dart 侧模板链路已进入递减区；再压需动 Rust 序列化格式
   （script 段 ~2ms + fill ~1ms，占 large 的 ~40%），未排期。

### 下一步工作（2026-08-26 定，未排期）

性能现状：六档 Dart-AOT 全线领先官方（typical 2.08x / large 1.04x），
Dart 侧易拿收益已尽。剩余大头是 FFI+JSON 传输（占 large ~40%、
ts_heavy 链路 ~80%）。下一步唯一有意义的工程：

**Rust 侧序列化精简（worker/oxc_ts）——已实施并按验收线关闭（2026-08-26）**

字段消费审计（mapper 三文件实测）：A 组死字段（decorators/sourceType/
diagnostics 复数/hashbang/directive 等）占负载 **15.2%**，集中在最高频
Identifier 节点（单个 Identifier 51% 是死字段）；crate（oxc_estree
0.147）原生开关收益为 0，正路为自定义 Serializer 黑名单。

实施结果（后按约定 revert）：
- TrimSerializer ~200 行 Rust，黑名单 24 字段（名字冲突项
  expression/generator/id/value/property 不可按名裁剪，保留）；
- 负载 -14.1%（601,378 → 516,661 字节 / 452 条语料）；
- 门禁全绿：452 对拍 0 mismatch、ast_diff 452/452、批量 783/786、
  dart test 13/13、样例 v1–v4 全 EXACT、cargo test 2/2；
- 微基准（23KB TS parseJson 链路）**-10%**，机制有效；
- **端到端未达验收线**：ts_heavy -3.7%、large -0.4%（噪声）——
  ts_heavy 单条 payload 仅 1–3KB，FFI 调用固定开销主导；
  large 由模板段主导。按验收约定（<5% 放弃）revert，工作区已还原。

教训：A/B 必须换 dylib 而非 bench 二进制（dylib 运行时加载，
换 bench 二进制的对比无效）。

**至此 FFI+JSON 方向的端到端潜力封顶（~4%），全部传输层优化关闭。**
剩余理论空间（均需大工程，不建议）：作用域感知二维黑名单（按节点类型
+字段名，可再收 B 组 ~12% 负载但端到端仍 <5%）、Rust 直出紧凑二进制
（二期已证 Dart 侧解码必败，需零拷贝内存映射设计才有意义）。

明确不做：typical 档再优化（已 2 倍领先，无投产增量信息）；
表达式重建分配簇复用（行为风险，已评估放弃）。

## 最终结论（2026-08-26）

**性能答卷**（runs=300，六档热路径 + 冷启动全线领先，无一落后）：

| 档位 | Dart-AOT | 官方 3.5.41 | 倍率 |
|---|---|---|---|
| tiny | 79µs | 163µs | 2.06x |
| typical（主场景） | 122µs | 273µs | 2.24x |
| ts_heavy | 239µs | 336µs | 1.41x |
| tmpl_heavy | 753µs | 966µs | 1.28x |
| large(34KB) | 7388µs | 7886µs | 1.07x |
| error | 23µs | 97µs | 4.21x |
| 冷启动 | 11ms | 638ms | 58x |

**本轮做对了什么**：
1. 唯一短板（large）的根因不是"结构性成本"，是移植遗漏——transform 里
   250 次冗余 FFI 解析（v-model/v-on 谓词不查批缓存、v-for source 未入批），
   修复带来 large -28%、transform 段 -53%，large 从落后 32% 翻成领先 7%。
2. P2 分配微调（SrcView ASCII 快路径等）再 -1.4%，无回归。
3. 排雷：RSS 增长验证为 GC 稳态非泄漏；修 v-once/v-memo 真泄漏；
   修正官方基线口径错误（prefixIdentifiers=true）。

**已关闭的方向**（均有数据，不重开）：字段裁剪（-14% 负载→端到端 <5%，
已 revert）、Dart 侧二进制解码（二期证败）、codegen 内容删减 / 跳过
prettier（无可删内容且破坏 parity）、transform/codegen 阶段再投入
（纯 transform 已反快官方 1.3 倍，递减区）。

**天花板与储备**：热路径理论上限 typical ~3.5–4x、large ~1.8x，5 倍数学上
不成立。唯一未试的便宜方向：script 解析批量化（杀 FFI 固定开销，
ts_heavy 估 -10~17%，基础设施 `oxc_parse_batch` 已存在，探针量化后再定）；
零拷贝 SoA 为核弹级储备，留待官方追平时启用。

**投产判断：可以投产。** 典型场景 2.24x 吞吐 + 58x 冷启动 + 无泄漏 +
四门门禁（452 对拍 / 783 批量 / 13 单测 / 样例全 EXACT），AOT 部署
（`dart compile exe`）。回归跑法见文首，一条命令可复现。

## 一、基准问题（按优先级）

1. **全管线吞吐**：典型 SFC 每秒可编译多少（files/s），P50/P90 延迟多少。
2. **FFI 成本占比**：oxc_parse（Rust）+ JSON 反序列化 + mapper 在 TS 解析链路中各占多少；JSON 序列化是否是主要开销。
3. **并发扩展性**：N 个 isolate 是否近线性（Rust 侧 `oxc_parse` 为纯函数、Allocator 局部，理论可并发，未实测）。
4. **内存画像**：单次编译分配峰值、持续编译 RSS 是否稳定（FFI 泄漏已有 30 万次零增长结论，此处测 Dart 侧 GC 行为）。
5. **规模曲线**：耗时随源码大小的增长阶（线性验证——mapper 的 `pointAt` 是逐节点线性扫描行表，大文件下可能暴露 O(nodes×lines)）。

## 二、语料设计（`bench/corpus/`）

| 档位 | 来源 | 说明 |
|---|---|---|
| tiny | 手写 5 个 | 单 script setup 块、无 TS |
| typical | batch_inputs.json 抽 20 条 | 三块齐全、含指令/插值的真实形态 |
| ts-heavy | 手写 5 个 | 复杂类型参数（defineProps 泛型、接口继承）——压 FFI/mapper 链路 |
| tmpl-heavy | 手写 5 个 | ~500 行模板、深嵌套 v-for/v-if——压 transform/codegen |
| large | 合成生成器 | typical × 10/× 50 倍拼接，验证增长阶 |
| error | 既有错误样例抽 5 条 | 错误路径不能比成功路径慢得离谱 |

合成生成器 `bench/gen_large.dart` 提交进仓库，保证语料可复现。

## 三、测量方法

- **计时**：`Stopwatch`；每档预热 20 次丢弃（JIT），正式测 200 次取 P50/P90/Mean；AOT 场景（`dart compile exe`）预热 3 次即可。
- **分段打点**：parse(SFC) / TS 解析（FFI 调用与 OxcMapper 分别计时）/ compileScript / compileTemplate / compileStyle。分段用语料级开关而非改产品代码——在 bench 内直接调各层入口函数组合。
- **FFI 微基准**：同一输入裸调 `OxcFFI.parseJson` 1 万次 vs `OxcMapper.mapProgram` 1 万次 vs `TSParser.parse` 全链路，差值即各段成本。
- **并发**：`Isolate.run` 扇出 1/2/4/8 worker 各编 N 个文件，报总吞吐与加速比。注意 `OxcFFI._cached` 是进程级单例，DynamicLibrary 句柄跨 isolate 共享行为需先验证（isolate 不共享堆，FFI 句柄按 isolate 重新 open？实测确认）。
- **内存**：每轮后 `ProcessInfo.currentRss`；单次分配用 `--profile`（Dart DevTools）离线采样，不进自动化。
- **官方对照（可选第 2 期）**：同机 node 跑 @vue/compiler-sfc 3.5.41 同语料，输出**比值**（dart/js），避免绝对值误导。

## 四、环境记录（结果必附）

Dart SDK 版本、AOT/JIT 模式、机型/CPU/内存、OS、oxc cdylib 构建信息（cargo --version、liboxc_ts 大小）、是否插电/降频。结果存 `bench/results/<date>-<machine>.json`。

## 五、坑位清单（实施前必读）

1. **`TS_AST_CORPUS` 必须 unset**——corpus recorder 会把每次 parse 追加写盘，直接毁掉所有数据（ts_parser.dart:15）。
2. `OxcFFI.load()` 有缓存，首次调用含 dlopen 成本——预热阶段天然吸收。
3. prettier/verifier 等 node 工具链不在基准进程内，勿混入计时。
4. large 档注意 mapper `_weaveComments` 的最深包含查找是 O(children) 递归，深嵌套模板可能平方级——正是要测的东西，别提前"修"。
5. 错误语料走 `errorTree()` 快路径，与成功路径分开报告，不混平均。

## 六、交付物与验收

- `bench/bench.dart`（套件选择/档位/次数 CLI）+ `bench/gen_large.dart` + 结果 JSON schema
- 首期产出：一张分段耗时表 + 吞吐数字 + 并发加速比曲线 + FFI 占比结论
- 验收标准（首期测完基线后再定目标值，先记录不预设）：typical 档 P50、FFI 占比、8-isolate 加速比 ≥ 4x（预期）

## 七、明确不做

- 与 esbuild/swc 等第三方编译器的横向对比
- 浏览器/WASM 场景（当前仅服务端 Dart）
- CI 门禁化（先人工跑，数据稳定后再议）
