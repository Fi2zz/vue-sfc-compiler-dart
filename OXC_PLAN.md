# oxc 替换 tree-sitter FFI 实施方案

## 决策（已定）

用 **oxc**（Rust 写的 TS/JS parser，crate 公开）替换 tree-sitter。目标是摆脱 tree-sitter（语法权威性一般、grammar 包 + C 构建链丑），**FFI 模型本身保留**——新方案是 Rust cdylib + dart:ffi，同步调用、零 IPC。

背景结论（调研已核实）：

- tree-sitter 是通用解析框架（C 核心库 + 各语言 grammar 动态库）。当前痛点：grammar 生态质量参差、语法树形状与官方编译器出入大、要按语言维护多个动态库、makefile `build-core` 的 `CORE_SRCS` 为空靠 Homebrew 兜底。
- Dart 消费端深度绑定 tree-sitter 的 CST 形状：约 58 种节点类型名 + 子节点位置语义（`children[0]/[1]`）+ 特有形状（`export_statement` 包装、for-in/of 头压平、`switch_body` 下钻、注释作为 named child）。**映射层是所有替代方案的共有成本**。
- oxc 的适配优势：crate 公开不用 fork；`oxc_ast` 带 serde `serialize` feature，JSON 序列化现成；`Span` 是 UTF-8 字节偏移，与现有 `AstNode.startByte/endByte` 语义一致；TS/TSX/JSX 全覆盖（白送 TSX）；MIT。
- 被淘汰项：babel 系（明确不引入 JS 解析器）、tsgo fork（internal 包需 fork + UTF-16 换算 + 官方 API not ready）、纯 Dart 自研（自己养整个 TS 语法）、package:tree_sitter（API 半成品）、子进程 worker（FFI 可接受则不必承担 IPC/通道复杂度，作为将来的可选形态）。

## 总体架构

```
worker/oxc_ts/            # 新增：薄 Rust crate（~150 行）
  ├─ Cargo.toml           # crate-type = ["cdylib", "bin"]；pin 死 oxc 版本；oxc_ast 开 serialize
  └─ src/lib.rs           # C ABI：oxc_parse(code_ptr, len, lang) -> *mut c_char（JSON）
                          #         oxc_free(*mut c_char)；catch_unwind 兜 panic
                          # src/main.rs：同逻辑的独立可执行文件（调试/将来的 worker 形态共用）
lib/native/               # 沿用现有分发位置：liboxc_ts.dylib / liboxc_ts.so（替换 tree-sitter 系列）
lib/ts_syntax/            # 新增：Dart 侧 FFI 绑定 + 映射层
  ├─ oxc_ffi.dart         # dart:ffi 绑定（2 个函数，比现 ts_ffi.dart 薄得多）
  ├─ oxc_mapper.dart      # oxc JSON → AstNode（tree-sitter 兼容形状）
  └─ NODE_SHAPES.md       # 消费端节点形状权威清单（Phase 0 产出）
```

**为什么 FFI 直连而不是子进程**：`TSParser.parse()` 是同步 API，深嵌同步编译管线（6 处调用）；cdylib 进程内同步调用天然契合，零协议零通道，Rust std 静态链接进 cdylib（无 Homebrew 式外部依赖）。crate 同时出 `bin` 目标，将来若要 Web/故障隔离可平滑补 worker 形态，mapper 不动。

**映射层放 Dart 侧**：cdylib 只做"解析 + 序列化 oxc AST 为 JSON 字符串"，越薄越稳；58 种节点的形状映射、注释织入、怪癖复刻全部在 Dart，和消费端同语言、可用既有 UTF-8 工具、迭代不用重编 Rust。oxc bump 时只动 Dart mapper。

**FFI 边界的纪律**（比 tree-sitter 时代更简单但要守住）：JSON 字符串由 Rust 分配、Dart 读后调 `oxc_free` 释放；Rust 侧 `catch_unwind` 把 panic 转成 error JSON，绝不让 panic 穿过 FFI 边界（穿了就是整个 Dart 进程崩）。

## Phase 0 — 语料与对照基座（已开工）

1. ✅ recorder 已落：`lib/ts_parser.dart` 的 `recordCorpusEntry()`（`TS_AST_CORPUS` 环境变量指向 JSONL 即记录每次 parse 的 code+language）。
2. 生成语料：带环境变量跑全管线——`dart run ./vue_dart.dart`、`dart vue_dart_tmpl.dart`、`dart vue_dart_style.dart`、`dart vue_dart_inline.dart`、`dart tools/batch_compile.dart batch_inputs.json ../batch_out/dart`，去重为 `tools/ast_corpus.jsonl`。
3. `tools/ast_diff.dart`：逐条语料同时走旧 tree-sitter `TSParser` 与新 oxc 链路，递归 diff `AstNode.toJson()`（type/起止字节/行列/children 顺序全等）；输出按节点家族的覆盖率/不一致报告（mapper 未完成时就是进度表）。
4. `lib/ts_syntax/NODE_SHAPES.md`：扫描 `lib/script` + `lib/template/transforms`，列出全部被判断的 tree-sitter 节点类型名及每处形状假设（`children[i]` 位置语义、export_statement 包装、for-of 压平、switch_body 下钻、注释作为 named child 等）。

## Phase 1 — Rust cdylib + Dart FFI 绑定

### 构建方案（如何编出 oxc 动态库）

1. **工具链**：rustup 管理；当前 oxc_parser（~0.144）要求 Rust ≥ 1.95，本机 1.94 需先 `rustup update`。
2. **crate 定义**（`worker/oxc_ts/Cargo.toml`）：`[lib] crate-type = ["cdylib"]` 是关键，产出 `.dylib/.so`；依赖 `oxc_parser` / `oxc_ast`（开 `serialize` feature）/ `oxc_span` / `oxc_allocator` / `serde_json`，全部 `=版本号` pin 死，防 oxc AST breaking 变更。
3. **C ABI**（`src/lib.rs`，仅两个导出函数）：
   - `oxc_parse(code: *const u8, len: u32, lang: u32) -> *mut c_char`：`catch_unwind` 全包；ts/tsx/js → `SourceType`；成功/失败都返回 `CString`（失败为 error JSON），所有权移交调用方；
   - `oxc_free(ptr: *mut c_char)`：`CString::from_raw` 回收。
4. **编译**：`cargo build --release` → macOS 产 `target/release/liboxc_ts.dylib`，Linux 产 `.so`。Rust cdylib 把 std **静态编入库内**，对外只依赖系统 libSystem/libc（比 tree-sitter 时代还干净，无 Homebrew 式外部依赖）。验证：`otool -L` 查依赖、`nm -gU` 查 `oxc_parse/oxc_free` 导出符号。
5. **各平台产物**：
   - macOS arm64（本机）：target 已装，直接编；现有双后缀惯例用 `cp liboxc_ts.dylib liboxc_ts.so`（Mach-O 改名，同现 makefile 对 tree-sitter 的做法）；
   - macOS x86_64（如需）：`rustup target add x86_64-apple-darwin` 后交叉编；
   - Linux x86_64：优先 **Linux 机器/容器（`rust:1` 镜像）里跑同样的 `cargo build --release`**；备选 `cross build --target x86_64-unknown-linux-gnu`；glibc 兼容性用旧发行版构建或 `x86_64-unknown-linux-musl` target 规避；
   - Windows：不需要，不编。
6. **产物落位**：`lib/native/liboxc_ts.dylib` / `.so`，沿用现有位置与 `_nativeCandidates` 平台探测；体积预期几 MB，可 `strip`。
7. **makefile**：`build-worker` 目标 = `cd worker/oxc_ts && cargo build --release` + 拷贝到 `lib/native/`；替换 build-ts/build-js/build-core/clean-native。

### Dart 侧

1. `lib/ts_syntax/oxc_ffi.dart`：`DynamicLibrary.open` 加载（沿用现 `_nativeCandidates` 平台探测模式）、`lookupFunction` 两个符号、Utf8 进出 + `oxc_free` 释放；error JSON → 抛带 code frame 的异常。
2. 单测：smoke（`const a = 1` → oxc JSON）、error JSON、连续 1 万次调用无泄漏（RSS 粗查）。
3. 验收：单测通过；`dart analyze` 零错误；四个 verifier 基线不跌（此阶段不动 TSParser，新旧 FFI 并存）。

## Phase 2 — mapper：JS 语法家族

按 NODE_SHAPES.md 清单逐家族实现（遵守 ≤200 行/文件，按家族拆 `mapper_expr.dart` / `mapper_stmt.dart` 等）：

- 表达式全家（优先级链各节点、call/member/new/模板/箭头/解构/spread/可选链/yield/await）；
- 语句与声明（变量/函数/类含私有字段与 static 块、import/export 全形态、switch/try/for 三形态）；
- tree-sitter 形状复刻：节点名映射表、named-children 顺序、export_statement 包装、for-in/of 头压平、switch_body 下钻；
- 每完成一家族跑 `ast_diff` 覆盖率报告推进。

## Phase 3 — mapper：TS 家族 + 注释 + 错误路径

- 类型注解全家族（联合/交叉/泛型/函数/元组/映射/条件/infer/索引访问/模板字面量/typeof/keyof 等）、interface/type alias/enum/declare/abstract/参数属性/`as`/`satisfies`/非空 `!`/import-export type；
- **注释织入**：oxc 把注释挂在 Program 独立列表，tree-sitter 把 comment 当 named child 编进树内原位置——mapper 按 span 把注释插入对应兄弟位置（ast_diff 对含注释语料全等为准，这步是映射层最需要设计的点）；
- 错误路径：非法输入 → error JSON → Dart 带 code frame 的异常（措辞不追求对齐 babel，官方 errorRecovery 本已策略性豁免）。

## Phase 4 — 切换、全量验证、拆除

1. `lib/ts_parser.dart`：`TSParser.parse` 内部切到 oxc 链路（签名、`AstNode` 不变；tsx/js 一并支持——oxc 白送 TSX）；`recordCorpusEntry` 保留（开发工具属性）。
2. 全量门禁：`dart analyze` 零错误；verifier v1 157 / v2 114 / v3 75 / v4 12 全 EXACT；batch 786 对齐数不跌（基线 772）；ast_diff 语料 100% 全等。
3. 拆除：删 `lib/ts_ffi.dart`、`lib/native/` 里 tree-sitter 系列动态库（保留 liboxc_ts）、pubspec 的 `tree_sitter` 依赖（**`ffi` 保留**）；`dart pub get`。
4. 文档：HANDOFF.md 已知坑"tree-sitter FFI 动态库"条目改写为 oxc cdylib 说明（构建/bump 流程/FFI 纪律），工作方法第 2 条更新；makefile 注释更新。

## 风险与对策

- **oxc AST 版本间 breaking**：pin 死版本；每次 bump 必须 ast_diff 全语料 + 四 verifier 重跑，写进 HANDOFF。
- **隐藏形状依赖**：切换的唯一门禁是 ast_diff 全语料 100% 全等，不靠抽查。
- **FFI 边界内存/panic**：`oxc_free` 配对释放 + `catch_unwind` 全包 + 泄漏单测，三条写进 Phase 1 验收。
- **回滚**：tree-sitter 路径保留到 Phase 4 门禁全绿才拆；此前所有改动均为新增文件，git revert 即回滚。

## 工作量估算

Phase 0 ~0.5 天；Phase 1 ~1 天；Phase 2-3 数日（mapper 是主体，ast_diff 驱动）；Phase 4 ~0.5 天。比纯 Dart 自研省掉 lexer/parser 全部工作量，比 worker 形态省掉通道/协议层。
