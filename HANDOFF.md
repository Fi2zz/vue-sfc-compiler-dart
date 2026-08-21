# HANDOFF — vue-sfc-compiler-dart

> 用途：新会话开场直接对 Kimi 说"读 Fi2zz/vue-sfc-compiler-dart 仓库的 HANDOFF.md 并按此继续"，即可重建上下文。
> 最后更新：2026-08-21

## 一句话现状

用 Dart 实现的 Vue 3 `<script setup>` 编译器，目标输出与官方 `@vue/compiler-sfc` 逐字节对齐。`compileScript` 已完成：**155/155 样例 EXACT**（verifier v1，见 `verifier/README.md`）。`compileTemplate` 和 `compileStyle` 尚未开始。整体完成度约 30%~35%。

## 仓库

- 地址：https://github.com/Fi2zz/vue-sfc-compiler-dart （私有）
- 默认分支：`master`
- 最近提交：2026-08-21「fix(script): 叶子 type_identifier 引用解析（155/155 EXACT）」

## 已完成（不要重做）

- SFC 解析与描述符：`lib/sfc_parser.dart`、`lib/sfc_descriptor.dart`、`lib/block.dart`
- `compileScript` 全量重写（`lib/script/`）：MagicString 编辑模型逐字移植（mini_magic.dart）、宏全家桶（defineProps/withDefaults/defineEmits/defineExpose/defineSlots/defineOptions/defineModel）、TS 类型 → 运行时声明推导、解构 props 转换、top-level await 转换、`__returned__` 生成
- 错误帧：官方 `generateCodeFrame` 逐字移植（`lib/script/script_error.dart`），配合 prettier 管线字节对齐 samples/
- 155/155 样例 EXACT：`node verifier/v1/compare.mjs`（先 `dart run ./vue_dart.dart && npx prettier samples_dart/*.md -w`）
- 复杂用例：`vue_complex.vue` → `vue_complex_dart.md` 与 `vue_complex_official.md` 对齐

## 待办（按优先级）

### P0 — compileTemplate（最大块，约占剩余工作 50%）
1. 模板解析器：HTML-like → 模板 AST（元素/文本/插值/注释节点）
2. 表达式转换：模板内表达式复用现有 tree-sitter TS AST 管线
3. 核心指令 transform：`v-if`/`v-else-if`/`v-else`、`v-for`、`v-on`（含修饰符）、`v-bind`（含 `.prop`/`.attr`）、`v-model`、`v-show`
4. 渲染函数 codegen：`createVNode`/`createElementVNode`/`toDisplayString` 等运行时 helper 收集与导入
5. 指令进阶：`v-slot` 体系（具名/动态/作用域插槽）、`v-html`/`v-text`、`v-memo`、`v-once`
6. 优化阶段：静态提升（hoistStatic）、补丁标记（patchFlag）、block tree、缓存事件处理器
7. setup 绑定元数据：模板引用与 `<script setup>` 绑定的联动分析（`bindingMetadata`）

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
node verifier/v1/compare.mjs          # 应 155/155 EXACT
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

## 新会话开场白（直接粘贴）

> 读 https://github.com/Fi2zz/vue-sfc-compiler-dart 仓库的 HANDOFF.md。这是一个用 Dart 实现 Vue 3 `<script setup>` 编译器的项目，目标输出与官方 @vue/compiler-sfc 对齐。compileScript 已完成（155/155 样例 EXACT，验证方式见「验证命令」）。现在按 HANDOFF 中的 P0 路线图继续 compileTemplate：先做模板解析器 → 模板 AST。工作方法：样例驱动、AST 优先、diff 官方输出验收。遵守 HANDOFF 中的代码规范。开始前先跑验证命令确认基线全绿。
