# vue-sfc-compiler-dart

用 Dart 实现的 Vue 3 SFC 编译器（包名 `vue_sfc_parser`），目标输出与官方 `@vue/compiler-sfc` 逐字节对齐。

## 能力现状

| 管线 | 对齐指标 |
|---|---|
| compileScript | 157/157 EXACT（verifier v1） |
| compileTemplate | 114/114 EXACT（verifier v2） |
| compileStyle | 75/75 EXACT（verifier v3） |
| inline 模式 + bindings | 12/12 EXACT（verifier v4） |
| 官方测试集批量对齐 | 783/786（其余 3 个为既定豁免：babel errorRecovery 措辞族） |
| source map | 段级一致 700/700 |

已支持：

- 编译期宏全家桶：`defineProps`、`withDefaults`、`defineEmits`、`defineExpose`、`defineSlots`、`defineOptions`、`defineModel`
- `<script setup>` 完整编译：TS 类型 → 运行时声明推导、解构 props、top-level await、inline 模式表达式改写
- 模板编译：指令全家桶、stringifyStatic、bindingMetadata 联动、options API bindings、source map
- compiler-dom 兼容入口：`lib/compiler_dom.dart` 的 `compile()` / `parse()`（含 function 模式 + `with (_ctx)` 运行时编译路径，官方测试集 53/53 字节一致；支持自定义 `nodeTransforms` / `directiveTransforms` 注入、module 模式 `scopeId`、自定义插值 `delimiters`）
- scoped CSS：`:deep()` / `:slotted()` / `:global()`、`v-bind()` CSS 变量、keyframes 改名、isProd hash 命名
- 错误用法识别，抛出与 `@vue/compiler-sfc` 一致的错误信息与 code frame

明确不做：SSR codegen、CSS modules、预处理器（sass/less/stylus）。

## 架构概览

```
SFC 源码 → lib/sfc_parser.dart → SfcDescriptor
                                      │
        ┌───────────────┬─────────────┴──────────┐
  lib/script/     lib/template/             lib/style/
  compileScript   compileTemplate           compileStyle
        │               │
  TS/JS 表达式解析：lib/ts_syntax/（oxc ESTree JSON → tree-sitter 兼容 CST）
        │
  lib/native/liboxc_ts.*（Rust cdylib，dart:ffi 两个符号，见 OXC_REFERENCE.md）
```

## 使用方式

入口为 `lib/vue.dart` 的 `Vue` 类：

```dart
import 'package:vue_sfc_parser/vue.dart';

final descriptor = Vue.parse(source, filename: 'App.vue');
final result = Vue.compile(source, filename: 'App.vue');
// result.script / result.template / result.styles

// 官方 parse() 语义：结构性问题不抛异常，返回 descriptor + 错误列表
final outcome = Vue.parseCollecting(source, filename: 'App.vue');

// 独立 compileTemplate 所需的 bindingMetadata
final bindings = Vue.bindingMetadataOf(descriptor);
```

## 快速开始

环境要求：

- Dart SDK ^3.9.2
- Rust ≥ 1.95（构建 TS 解析 worker）
- Node + prettier（生成与格式化官方 ground truth）

```bash
dart pub get
make build-worker   # 构建 lib/native/liboxc_ts.*（被 .gitignore 排除，新机器必须自行构建）
```

## 验证

`samples*` 目录为官方编译器生成的 ground truth，`samples*_dart/` 为本实现输出，verifier 逐字节对比：

```bash
dart run ./vue_dart.dart && npx prettier samples_dart/*.md -w --log-level warn \
  && node verifier/v1/compare.mjs    # script，157/157
dart vue_dart_tmpl.dart && node verifier/v2/compare.mjs    # template，114/114
dart vue_dart_style.dart && node verifier/v3/compare.mjs   # style，75/75
dart vue_dart_inline.dart && node verifier/v4/compare.mjs  # inline，12/12

# compiler-dom 兼容层（compile()/parse() 口径）
node tools/batch_dom_official.mjs batch_dom_inputs.json ../batch_out/dom_official
dart tools/batch_dom_dart.dart batch_dom_inputs.json ../batch_out/dom_dart
node tools/batch_compare.mjs ../batch_out/dom_official ../batch_out/dom_dart  # 53/53

dart analyze                         # 须零 error/warning
```

注意：v1 的 `samples/` 经过 prettier(markdown) 格式化，`samples_dart/` 必须过同样的 prettier 步骤才能字节对齐。

## 目录结构

- `lib/` 编译器核心
  - `compiler_dom.dart`：compiler-dom 兼容入口（`compile()` / `parse()`）
  - `sfc_parser.dart` / `sfc_descriptor.dart` / `block.dart`：SFC 解析与描述符
  - `script/`：compileScript（宏处理、bindings 分析、TS 类型推导、MagicString 编辑模型）
  - `template/`：compileTemplate（解析、transform、codegen、source map、实体解码）
  - `style/`：compileStyle（CSS 解析、scoped 选择器重写、CSS 变量）
  - `ts_syntax/`：oxc FFI 绑定与 ESTree → tree-sitter 兼容 CST 映射
  - `native/`：oxc worker 动态库（构建产物，不入库）
- `worker/oxc_ts/`：Rust 解析 worker（oxc_parser，版本 pin 死）
- `samples/`、`samples_tmpl/`、`samples_style/`、`samples_inline/`：官方 ground truth
- `samples_dart/`、`samples_tmpl_dart/`、`samples_style_dart/`、`samples_inline_dart/`：本实现输出
- `verifier/`：v1–v4 比较器（详见 `verifier/README.md`）
- `tools/`：批量对齐、AST diff、模糊测试等工具链

## 相关文档

- `HANDOFF.md`：总体路线、工作方法、代码规范与已知坑
- `OXC_REFERENCE.md`：TS 解析后端的 FFI 规格、构建与版本 bump 流程
- `FFI_MIGRATION.md`：解析后端切换的契约面与回归套件
- `lib/ts_syntax/NODE_SHAPES.md`：节点形状清单
- `verifier/README.md`：比较器说明与运行记录

## 许可

MIT，见 `LICENSE`。
