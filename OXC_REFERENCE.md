# OXC 参考手册 — 规格、构建与调用

> tree-sitter 替代方案的技术参考。迁移方案本身见 `OXC_PLAN.md`，节点形状清单见 `lib/ts_syntax/NODE_SHAPES.md`。

## 架构总览

```
Dart 消费端（TSParser.parse → AstNode）
        │
  lib/ts_syntax/oxc_mapper.dart     oxc ESTree JSON → tree-sitter 兼容 CST
        │
  lib/ts_syntax/oxc_ffi.dart        dart:ffi（2 个符号）
        │
  lib/native/liboxc_ts.dylib/.so    Rust cdylib（std 静态链接，仅依赖系统 libc）
        │
  worker/oxc_ts/                    oxc_parser 0.147（pin 死）+ oxc_estree
```

分层原则：Rust worker 只做"解析 + 序列化"，**所有 tree-sitter 形状映射都在 Dart 侧**（`lib/ts_syntax/mapper_*.dart`），oxc 版本升级只需动 Dart mapper。

## 构建

### 前置

- Rust ≥ 1.95（oxc 0.147 的 MSRV），rustup 管理。
- oxc 全家版本在 `worker/oxc_ts/Cargo.toml` 用 `=0.147.0` pin 死，**升级必须走 bump 流程**（见下文）。

### 命令

```bash
cd worker/oxc_ts && cargo build --release
cp target/release/liboxc_ts.dylib ../../lib/native/          # macOS
cp lib/native/liboxc_ts.dylib lib/native/liboxc_ts.so        # mac 双后缀惯例（Mach-O 改名）
# Linux：在 Linux 机器或 rust:1 容器里同样构建，产物为 .so
```

产物约 1.1MB（release profile: lto + codegen-units=1 + strip）。`lib/native/` 被 .gitignore 排除（与 tree-sitter 库同惯例），新机器须自行构建。

### 验证产物

```bash
nm -gU lib/native/liboxc_ts.dylib | grep oxc_   # 应见 _oxc_parse / _oxc_free
otool -L lib/native/liboxc_ts.dylib             # 应仅依赖 libSystem.B.dylib
echo 'const a = 1' | worker/oxc_ts/target/release/oxc_ts ts   # CLI 冒烟
```

## FFI 规格

仅两个导出符号（`worker/oxc_ts/src/lib.rs`）：

```c
// 解析 len 字节的 UTF-8 源码；lang: 0=ts 1=tsx 2=js 3=jsx。
// 返回堆分配的 JSON C 字符串，调用方必须用 oxc_free 释放。
// 不可能返回 null（除非 payload 含 NUL，实际不会发生）。
char* oxc_parse(const uint8_t* code, uint32_t len, uint32_t lang);

// 释放 oxc_parse 返回的字符串。null 安全。
void oxc_free(char* ptr);
```

纪律（违反即进程崩溃或泄漏）：

- **panic 永不越界**：worker 内 `catch_unwind` 全包，解析 panic 转为 `{"ok":false,...}` JSON。
- **所有权**：JSON 由 Rust 分配、Dart 读后调 `oxc_free` 释放，配对使用。已通过 30 万次调用 RSS 零增长实测。
- SFC script 一律按 module 解析（`SourceType::ts()/tsx()/mjs()/jsx()`）。

## JSON payload 规格

### 成功（含可恢复诊断）

```jsonc
{
  "ok": true,
  "program": { "type": "Program", "body": [ /* oxc ESTree 节点 */ ], "start": 0, "end": 30 },
  "comments": [
    { "type": "comment", "kind": "line", "value": " hello", "start": 13, "end": 21 }
  ],
  "diagnostics": [
    { "error": "A module cannot have multiple default exports.", "start": 7, "end": 14 }
  ]
}
```

- `program`：oxc ESTree 序列化（`oxc_estree` CompactFormatter，含 TS 字段）。**span 是 UTF-8 字节偏移**，与 tree-sitter / `AstNode.startByte` 语义一致。
- `comments`：手工序列化（oxc 的 ESTree Comment 实现**故意 `unimplemented!()` panic**，注释文本须自行切源码）。`value` 不含 `//` 或 `/* */` 定界符。
- `diagnostics`：可恢复错误（语法 panic 之外的语义/语法诊断，如 duplicate default exports）——**契约与 tree-sitter 的"永远返回一棵树"对齐**，消费端自行判断是否致命。

### 失败（parser panic / 非法输入）

```jsonc
{ "ok": false, "diagnostic": { "error": "Unexpected token", "start": 6, "end": 7 } }
```

oxc parser 对语法错误是 panic 式的（`const = ;` 直接 fatal），这点与 tree-sitter 的错误恢复本质不同；已知影响仅限 3 条语料（pipeline operator 等，属 HANDOFF 已豁免的 errorRecovery 家族）。

## Dart 调用

```dart
import 'package:vue_sfc_parser/ts_syntax/oxc_ffi.dart';
import 'package:vue_sfc_parser/ts_syntax/oxc_mapper.dart';

final oxc = OxcFFI.load();                       // lib/native → cargo target 顺序探测
final payload = oxc.parseJson(code, 'ts');       // 解析（语言同 tree-sitter 惯例）
final root = OxcMapper(code, language: 'ts')     // ESTree JSON → tree-sitter 形状
    .mapProgram(payload);                        // 输出 AstNode，与 TSParser.parse 同型
```

- `OxcFFI.parseJson`：语法 panic 时抛 `OxcParseException(message, start, end)`；`ok:true` 时返回完整 payload（含 comments/diagnostics）。
- `OxcMapper`：**js 与 ts 是两套 tree-sitter 形状**（js 无 `required_parameter` 包装、class 名用 `identifier`、`field_definition`、heritage 无 `extends_clause`），构造时按 language 自动切换。
- 未覆盖的节点抛 `UnimplementedError`（fail loud，绝不静默出错树）。

## 已实测的 oxc ↔ tree-sitter 形状差异（mapper 依据）

| 主题 | oxc (ESTree) | tree-sitter | mapper 处理 |
|---|---|---|---|
| 语句分号 | 不含 `;` | statement 区间含 `;`（含 for 头） | `extendStatementEnd` |
| if/while/switch 条件 | 裸表达式 | `parenthesized_expression` 包裹 | 合成节点，回扫括号 |
| for-in/of 左值 | VariableDeclaration | 压平为裸 pattern | 解包 declarator.id |
| `x => x` 裸参 | params 数组 | 无 formal_parameters，identifier 直挂 | 看后随 `=>` 判定 |
| 模板 fragment | TemplateElement 含定界符 | string_fragment 仅内容、空省略 | `[start+1, end-(tail?1:2))` |
| 可选链 | `optional: bool` | `optional_chain` 实体节点（`?.`） | 按 property 位置合成 |
| 注解标识符 | Identifier span 含 `: T` | identifier 截到冒号前 + type_annotation 兄弟 | `splitAnnotation` |
| union/intersection | 扁平数组 | 左深嵌套 | `_foldedType` |
| `as const` | TSTypeReference(const) | 无类型子节点 | 丢弃 |
| 签名分隔符 | span 含 `;` | 截到注解尾 | `_signatureEnd` |
| 注释 | Program 独立列表 | named child 编排在树内 | 最深包含节点织入 |
| 前导 trivia | — | program 起于首个 named child（含注释） | start = min(首语句, 首注释) |
| `undefined` | Identifier | 专用 `undefined` 节点 | 按名字特判 |
| 空字符串 | — | 无 string_fragment | 省略空 fragment |

完整节点清单（103 种）与消费文件对照见 `lib/ts_syntax/NODE_SHAPES.md`。

## 校验工具链

```bash
# 语料（452 条真实输入：四样例管线 + batch 786 去重）
TS_AST_CORPUS=/tmp/c.jsonl dart run ./vue_dart.dart   # 等管线，recorder 落 jsonl

dart tools/ast_diff.dart            # 全量双解析 diff：当前 449/452 EXACT（理论上限）
dart tools/ast_diff.dart --census   # 附带 tree-sitter 节点 census
echo 'const a = 1' | dart tools/ast_probe.dart ts     # 单点两棵树并排 + 首个分歧
dart test test/oxc_ffi_test.dart    # 绑定单测（6 例）
```

`ast_diff` 同时是 mapper 的进度表与回归门：**449/452 是切换（Phase 4）的硬门槛**。

## oxc 版本 bump 流程（必须遵守）

oxc AST 在版本间有破坏性变更先例。任何 `Cargo.toml` 版本改动后：

1. `cargo build --release` 重编并替换 `lib/native/liboxc_ts.*`；
2. `dart test test/oxc_ffi_test.dart` 全绿；
3. `dart tools/ast_diff.dart` 必须维持 449/452——掉了就先修 mapper 再合入；
4. 四个 verifier（v1 157 / v2 114 / v3 75 / v4 12）与 batch 786 不跌。

## 已知坑（实测记录）

- `ParserReturn.errors` 在 0.147 已改名 `diagnostics`；`Program` 不再 derive serde，序列化走 `oxc_estree::ESTreeSerializer<ConfigNoFixes, CompactFormatter>::new(true, false)`。
- oxc `Program.comments` 有数据但 ESTree 序列化约定跳过——worker 单独输出 comments 数组。
- oxc `Identifier`/`ObjectPattern` 的 span **包含** typeAnnotation；tree-sitter 按冒号裁剪，映射时小心（`splitAnnotation` / `_annotatedParameter`）。
- Dart 语法坑：`x as int - 2` 不合法（`as` 优先级），必须 `(x as int) - 2`。
- macOS 上 `ru_maxrss` 单位是**字节**（不是 KB），做泄漏压测时别误读。
