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

## 二期：表达式批量 FFI——方案 A/B 实现与对比（2026-08-26）

**问题量化**：large_50 一次模板编译触发 **601 次 FFI 往返**（每表达式一次）。单次往返分解（`r.id` 样本）：Rust 解析+序列化 0.26µs(9%) / UTF-8 解码 0.06µs / **Dart jsonDecode 1.64µs(56%)** / malloc-free+包装 ~0.9µs——JSON 中间层与逐次固定开销是主体。

**方案 A（ffi）**：新增 Rust 符号 `oxc_parse_batch(char**,n,lang)`（条目级 panic 隔离），一次往返返回 JSON 数组；模板 transform 前 pre-pass 收集全部 `(raw)` 包裹源 → 批量解析 → 按 source 文本缓存（包裹源完全决定解析树，缓存安全；asParams/asRawStatements 少数派走逐条回退）。
**方案 B（concat）**：零 FFI 改动，把所有表达式拼成 `[e0,e1,...]` 单次解析，元素子树深拷贝再基线到独立坐标。

| 档位(AOT runs=300) | off | A(ffi) | B(concat) |
|---|---|---|---|
| large(34KB) | 8.89ms | **8.05ms(-9.5%)** | 9.82ms(+10% 劣化) |
| tiny/typical/ts_heavy | 基线 | 持平（阈值≥8 保护） | — |

**结论**：
1. **A 采纳**：large 档 -9.5%，其余档位经阈值保护无回退；FFI 调用次数 601→0（表达式侧）。门禁全绿（v1 159 / v2 115 / v4 12 / dom 53+438 / probe / golden）。
2. **B 否决**：深拷贝再基线的分配风暴超过运输节省，实测净负收益——保留实现作对照记录，默认不启用。
3. 开关：`TS_EXPR_BATCH=ffi` 启用（阈值 ≥8 表达式才批处理）；默认 off 待生产验证后翻转。

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
