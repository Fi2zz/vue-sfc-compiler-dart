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

| 配置 | baseParse | transform(含表达式缓存) | codegen | 模板全段 |
|---|---|---|---|---|
| 官方 (V8) | 359 | 1163 | 753 | 2253 |
| Dart-AOT concat | ~500 | **4764** | **938** | ~6100 |
| Dart-AOT bin | ~400 | **5786** | **780** | ~7000 |

（Dart-JIT 拆分探针数据不可用：减法式计时在 JIT 下出现负值，
分层优化/GC 干扰所致；JIT 档位级数据以 bench 300 轮为准。）

补充结论：
1. **codegen 两侧基本持平（938 vs 753，~1.2x）**——此前"transform+codegen
   3.0x"的真实构成是 **transform 4.1x（4764 vs 1163）拖后腿，codegen 不慢**。
   优化目标从整个模板段收窄到 transform 一段。
2. Dart transform 段含 `_fillExprCache` 表达式解析（concat ~1ms 经 FFI），
   官方非 inline 模式不解析表达式（prefixIdentifiers=false）——Dart 做更多
   工作仍更慢；非 inline 模式表达式解析是否必要是第一个可复查的优化点。
3. bin 的代价精确落在 transform 段（+~1000µs：OXB2 惰性视图在节点属性
   访问时解码，transform 是访问最密集的阶段），codegen 反而略降；
   与 bench 档位级差距同源；baseParse 不受影响。
4. baseParse 两侧同量级（Dart ~400–600 vs 官方 359，选项不同——Dart 用
   domParserOptions 全量 DOM 谓词，官方探针用 parserOptions），非瓶颈。


结论：
1. **large 档落后的账全在 transform 一段**（4.1x 慢于官方；codegen 持平、
   baseParse 同量级、script 段 FFI 仅占 21%）。AOT 把模板段压 26%，已榨干
   "编译器优化"层收益；剩余差距是 transform 的结构性成本（对象分配模式 +
   V8 分代 GC 对编译器类负载的天然优势）。
2. 追赶是大工程（分配削减 / 单 buffer codegen / `_weaveComments` 类平方级
   路径排查），且须保住 `tools/diff_transport.dart` 452 条对拍门禁；
   34KB SFC 非主场景，投入产出比低，维持"未排期"。动手前先用
   Dart DevTools allocation profiler 拿真实分配画像。
3. 表达式链路（`_fillExprCache` concat 解析）位于 template 段内部而非独立
   阶段，~1ms 量级；即使归零也填不平 3.0x 的 transform+codegen 差距。

**投产评估三问的最终答案**：单核吞吐 typical ~16 万 files/s（AOT）、
FFI 占 TS 链路约八成（优化空间在 Rust 序列化侧）、并发 4 isolate 饱和 ~2.4x。
**可投产；跟进项：① 查清 large 档 RSS 行为；② 模板管线大文件优化排期。**

### 待办清单（按优先级）

**P0 — 投产前必须完成**

1. **查清 large 档 RSS 行为**。300 轮 RSS 增量 ~1.1GB 与首期"0.3–10MB/300 轮
   无泄漏信号"矛盾。方法：large 档连跑 3000 轮记录 RSS 曲线——plateau 为
   GC 行为（可接受），线性涨为泄漏（阻塞常驻服务部署）。

**P1 — transform 优化的前置侦查**（目标段已收窄：transform 4.1x vs 官方，
codegen 持平、baseParse 同量级）

2. **复查非 inline 模式表达式解析的必要性**。官方 prefixIdentifiers=false 时
   不解析表达式，Dart 侧 `_fillExprCache` 在非 inline 仍 concat 解析全部
   表达式（large_50 ~1ms）。若对输出无影响则跳过，transform 段立省 ~20%。
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
