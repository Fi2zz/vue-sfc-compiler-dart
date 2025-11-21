# dart_vue_compiler (WIP)

Status: WIP

当前进度

- 实现 `compileScript` 编译宏阶段

一个使用 Dart 实现的 Vue 3 `<script setup>` 编译器与示例生成器。目标是基于 `samples_vanilla` 输入，生成与官方 `samples` 一致的输出（`samples_dart`），并提供复杂用例对齐能力。

## 特性

- 支持主流编译期宏：`defineProps`、`withDefaults`、`defineEmits`、`defineExpose`、`defineSlots`、`defineOptions`、`defineModel`
- AST 驱动的语义分析与代码生成，尽量避免字符串硬编码
- 自动合并模型相关的 `props`/`emits`（`mergeModels`）以匹配官方输出结构
- 错误用法识别并抛出符合 `@vue/compiler-sfc` 的错误信息格式

## 目录结构

- `lib/` 编译与生成核心
  - `sfc_script_codegen.dart`：`<script setup>` 代码生成器
  - `sfc_compiler.dart`：解析结果包裹结构 `SetupResult`
  - 其他：宏与 TS AST 相关工具
- `samples/` 官方目标样例（对齐参考）
- `samples_vanilla/` 原始输入样例（不含官方包装）
- `samples_dart/` Dart 编译器生成的样例输出
- `vue_compiler.dart`：示例批量编译入口（生成 `samples_dart/*.md`）
- `vue_complex.vue`：复杂用例的源组件
- `vue_complex_official.md` / `vue_complex_dart.md`：复杂用例的官方 vs Dart 输出对比

## 快速开始

1. 运行示例编译（生成 `samples_dart`）：
   - `dart run ./vue_compiler.dart`
2. 对比官方输出：
   - `diff -qr samples samples_dart`
   - 或者逐文件对比：`diff -u samples/<name>.md samples_dart/<name>.md`
3. 复杂组件演示（已提供）：
   - 源：`vue_complex.vue`
   - 官方：`vue_complex_official.md`
   - 本编译器：`vue_complex_dart.md`

## 开发与调试

- 静态检查：`dart analyze lib/sfc_script_codegen.dart`
- 重新生成并格式化复杂用例：
  - `dart run ./vue_compiler.dart`
  - `prettier vue_complex_dart.md -w`（可选）
- 与官方对齐策略：
  - 优先通过 AST 收集/合并，避免硬编码常量
  - 运行时导入按实际使用注入；宏调用全部视为编译期行为

## 常见问题

- 问：为什么不会导入 `defineProps/defineEmits/...` 这些宏？
  - 答：它们是编译期宏，不属于运行时 API，生成阶段仅做重写，不进行导入。

## 许可

- 本仓库未显式声明许可证，如需发布请先补充 License 信息。
