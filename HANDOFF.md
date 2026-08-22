# HANDOFF — vue-sfc-compiler-dart

> 用途：新会话开场直接对 Kimi 说"读 Fi2zz/vue-sfc-compiler-dart 仓库的 HANDOFF.md 并按此继续"，即可重建上下文。
> 最后更新：2026-08-22

## 一句话现状

用 Dart 实现的 Vue 3 SFC 编译器，目标输出与官方 `@vue/compiler-sfc` 逐字节对齐。`compileScript` 已完成：**155/155 样例 EXACT**（verifier v1）。`compileTemplate`：**42/42 样例 EXACT**（verifier v2，含指令/插值/组件/v-slot/内置组件/stringifyStatic 触发样例）。剩余：compileTemplate 样例继续扩充（ws preserve/pre/textarea 边界/更多错误样例）、bindingMetadata 联动、compileStyle（P1）。整体完成度约 65%。

## 仓库

- 地址：https://github.com/Fi2zz/vue-sfc-compiler-dart （私有）
- 默认分支：`master`
- 最近提交：见 `git log`（template 阶段：transform+codegen 全量移植，v2 基线 20/20 EXACT）
- 注意：本机非交互环境无 git 凭据，push 会失败；每次提交后更新 `../_git_backups/vue-sfc-compiler-dart.bundle`（`git bundle create ... --all`），.git 目录曾在会话间丢失过，bundle 是恢复手段

## 已完成（不要重做）

- SFC 解析与描述符：`lib/sfc_parser.dart`、`lib/sfc_descriptor.dart`、`lib/block.dart`
- `compileScript` 全量重写（`lib/script/`）：MagicString 编辑模型逐字移植（mini_magic.dart）、宏全家桶（defineProps/withDefaults/defineEmits/defineExpose/defineSlots/defineOptions/defineModel）、TS 类型 → 运行时声明推导、解构 props 转换、top-level await 转换、`__returned__` 生成
- 错误帧：官方 `generateCodeFrame` 逐字移植（`lib/script/script_error.dart`），配合 prettier 管线字节对齐 samples/
- 155/155 样例 EXACT：`node verifier/v1/compare.mjs`（先 `dart run ./vue_dart.dart && npx prettier samples_dart/*.md -w`）
- 复杂用例：`vue_complex.vue` → `vue_complex_dart.md` 与 `vue_complex_official.md` 对齐

## 待办（按优先级）

### P0 — compileTemplate（核心管线已完成，进入覆盖面扩充）
已完成：模板解析器（tokenizer 移植）、transform 全家桶（v-if/v-for/v-on/v-bind/v-model/v-show/v-slot/v-html/v-text/v-memo/v-once、transformExpression/processExpression 走 tree-sitter TS AST、hoistStatic/cacheHandlers/patchFlag/block tree、asset URL/srcset 重写）、module 模式 codegen。入口 `lib/template/compile_template.dart`（compileTemplateSource），生成器 `vue_dart_tmpl.dart`，验收 `node verifier/v2/compare.mjs`（20/20 EXACT）。
已完成追加（2026-08-22）：stringifyStatic 全量移植（`lib/template/transforms/stringify_static.dart` + `const_eval.dart` 常量求值器替代官方 new Function eval + `stringify_utils.dart` JS 语义助手 + `html_attrs.dart` 官方属性表）；v-slot/动态组件/内置组件/`<slot>` outlet/scopeId/v-html/v-text/v-memo/v-once/错误样例已扩充；SFC 块扫描器改为深度感知（嵌套 `<template>` 不再误判重复块）。
剩余：
1. 样例继续扩充：ws preserve、pre/textarea 边界、更多错误样例（ERRORS 文本对齐）、v-for+v-slot 组合、动态参数边界
2. bindingMetadata 联动（compileScript 结果喂给模板：setup 引用 `_unref`/`$setup` 前缀等）——当前 compileTemplateSource 未接 bindingMetadata
3. processExpression 保真细节：parser 期 createExp 预解析（错误时机差异）、class-in-template 边界

### P1 — compileStyle（相对独立，可与 P0 并行）
- scoped CSS：data 属性注入 + 选择器重写
- `:deep()` / `:slotted()` / `:global()` 伪类处理
- CSS `v-bind()` → CSS 变量方案（与 `useCssVars` 联动）
- （可选）预处理器：sass/less/stylus 接入

### P2 — 打磨
- source map 生成
- inlineTemplate 模式
- 官方 `@vue/compiler-sfc` 测试集批量对齐
- edge case：comments、whitespace 处理策略、SSR codegen（可砍）

## 工作方法（已被验证有效，务必遵守）

1. **样例驱动**：新功能先加 `samples_vanilla/<name>.vue` 输入与 `samples/<name>.md` 官方输出（由官方编译器生成），再实现到 `diff` 无差异
2. **AST 优先**：禁止正则/字符串硬编码收集语义信息；TS 侧走 tree-sitter（FFI 动态库在 `lib/native/`，含 .so 和 .dylib）
3. **宏即编译期**：`defineProps` 等宏只做重写，永不生成 import
4. **字节偏移安全**：AST offset 切字符串必须走 UTF-8 安全切片（已有工具，勿用裸 `substring`）
5. 官方行为不确定时：跑官方编译器看输出，以官方为准

## 验证命令

```bash
# Dart SDK 在 /mnt/agents/output/_toolchain/dart-sdk/bin（先加 PATH）
dart run ./vue_dart.dart && npx prettier samples_dart/*.md -w --log-level warn
node verifier/v1/compare.mjs          # 应 155/155 EXACT（script）
dart vue_dart_tmpl.dart && node verifier/v2/compare.mjs   # 应 20/20 EXACT（template）
dart analyze                          # 须零错误（runner.dart 有一个历史 info lint 可忽略）
```

关键：samples/ 是官方输出经 prettier(markdown) 格式化后的结果，samples_dart 必须过同样的 prettier 步骤才能字节对齐（错误帧空行的双空格硬换行、前导空白折叠均来自 prettier）。

## 代码规范（硬性约束）

- 函数/方法参数 ≤ 4 个；函数体 ≤ 20 行（不含注释/空行/纯括号行）；`build()` ≤ 15 行
- class ≤ 100 行，超过按优先级拆分：状态管理 → Controller/Bloc，UI 子树 → 独立 Widget，共享工具 → Extension，跨类行为 → Mixin，数据转换 → Mapper，回调 → Handler
- 单函数 if/else/switch 分支总数 ≤ 3，嵌套 ≤ 2 层，单条件 `&&`/`||` ≤ 2 个，三元禁止嵌套，优先 early return
- 布尔变量/函数用形容词，禁止 `is/has/can/should` 前缀
- 组合优于继承；Dart 空安全 + 现代构造语法 + 集合字面量 + async/await（禁 then 链）
- 禁止废弃 API
- 提交前 `dart analyze` 零错误；git 禁止 force push / force update

## 已知坑（别重踩）

- tree-sitter FFI 需要对应平台的动态库，Linux 用 `.so`，macOS 用 `.dylib`；CI/新机器先确认库文件存在
- 多字节字符（中文注释/emoji）会让 AST byte offset 切错位置——必须 UTF-8 安全切片；`tsParserParseString` 必须传 UTF-8 字节长度而非 UTF-16 长度
- Dart `String.split(RegExp(r'(\r?\n)'))` 与 JS 不同：捕获组分隔符会被丢弃，移植官方 generateCodeFrame 之类逻辑时须手动保留分隔符
- 官方编译器对 import 排序有自己的规则（运行时 API 多行块、按 setup 源顺序），不要去"优化"它
- `samples.json` 是样例索引/元数据，新增样例时同步更新
- babel 会把语句后跨空行的注释挂为 trailingComments，hoistNode 须连同注释与后续全部空白一起移动
- 已知隐患（未触发）：typeScope 条目跨 parse 时未携带各自 SrcView，setup 若整体引用 normal script 声明的 interface 作为 props 类型，成员键提取会用错 view
- 模板侧：官方 Symbol 身份以 helper 名字符串建模（genNode 遇 helperNames 集合内字符串输出 `_name`）；官方依赖 JS `arr[-1] === undefined` 的循环（v-if 分支键）移植时要显式判负；`transformIf` 的 createCommentVNode 注册发生在 alternate 构造时（影响 import 顺序）；DOM parserOptions.parseMode 是 html 不是 base
- `samples_tmpl.json` 是模板样例索引，新增模板样例时同步更新并用 `node gen_official_tmpl.mjs` 重新生成 ground truth

## 新会话开场白（直接粘贴）

> 读 https://github.com/Fi2zz/vue-sfc-compiler-dart 仓库的 HANDOFF.md。这是一个用 Dart 实现 Vue 3 SFC 编译器的项目，目标输出与官方 @vue/compiler-sfc 逐字节对齐。compileScript 已完成（155/155 EXACT），compileTemplate 核心管线已完成（verifier v2 首批 20/20 EXACT）。现在按 HANDOFF 的 P0 剩余项继续：先跑验证命令确认基线全绿，然后扩充模板样例覆盖面（v-slot/动态组件/内置组件/错误样例）并迭代到全 EXACT，或移植 stringifyStatic。工作方法：样例驱动、AST 优先、以官方编译器输出为准。遵守 HANDOFF 中的代码规范与 git 约束（禁止 force push）。
