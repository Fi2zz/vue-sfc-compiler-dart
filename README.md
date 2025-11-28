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

## 迁移与基准

- 迁移脚本：运行 `dart run tool/migrate_comments.dart <repo_root>` 输出需替换的三类注释访问与命名参数位置，按建议替换为统一 `comments` 访问与过滤（基于 `placement`）。
- 基准：运行 `dart run tool/benchmark_comments.dart`，查看解析与打印耗时与注释数量等指标。

## 常见问题

- 问：为什么不会导入 `defineProps/defineEmits/...` 这些宏？
  - 答：它们是编译期宏，不属于运行时 API，生成阶段仅做重写，不进行导入。

## 许可

- 本仓库未显式声明许可证，如需发布请先补充 License 信息。

## AST 节点结构（Program/Node 注释）

- `body: List<Statement>`：程序的可执行语句列表（保持顺序）
- `comments: List<Comment>?`：程序级别的注释集合，与 `body` 平行，包含文件头/尾及整体范围内的注释；位置（start/end/loc）与文本完整保留；元素可含 `placement: leading|inner|trailing`。
- `directives: List<Directive>`：源文件指令，如 `"use strict"`
- `sourceType: String`：`script | module`
- `interpreter: InterpreterDirective?`：解释器指令（例如 shebang）

说明：

- 统一保留 `comments` 作为唯一注释入口；节点不再持有 `leadingComments`/`innerComments`/`trailingComments` 三类字段，分类语义通过 `Comment.placement` 表达；解析阶段将所有注释集中至 `Program.comments` 并进行去重。
