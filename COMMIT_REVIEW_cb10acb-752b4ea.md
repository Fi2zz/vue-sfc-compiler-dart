# Commit 审查报告：cb10acb..752b4ea

- 审查日期：2026-08-28
- 范围：20 个 commit，565 个文件变更（+21,798 / −4,159）
- 主题：Vue SFC 编译器三大域移植落地 —— `compileScript`（script/）、`compileTemplate`（template/）、`compileStyle`（style/），配套三级 verifier 与 golden 样例；同时删除旧架构（sfc_macro.dart / sfc_script_codegen.dart / validate_usage.dart，共 ~1,600 行）。
- 方法：实际运行三套验证器复核 EXACT 声明；lib/script、lib/template、lib/style 三路并行深审（逐行对照 pinned 官方 `@vue/compiler-sfc@3.5.41` / `postcss@8.5.26` dist）；工具链与仓库卫生专项审查。

> 注：验证器在本机（当前 HEAD，含范围后增量）实测通过；报告中的 EXACT 复核结论对 752b4ea 时点同样成立（样例为其子集）。

---

## 一、验证结果复核（实测）

| 验证器 | 命令 | 实测结果 | 与 commit 声明一致性 |
|---|---|---|---|
| v1 (script/SFC) | `dart run ./vue_dart.dart` + prettier + `compare.mjs` | **159/159 EXACT** | ✅（752b4ea 时 155/155，为其子集） |
| v2 (template) | `dart run ./vue_dart_tmpl.dart` + `compare.mjs` | **115/115 EXACT** | ✅（752b4ea 时 89/89） |
| v3 (style) | `dart run ./vue_dart_style.dart` + `compare.mjs` | **75/75 EXACT** | ✅ |

重新生成全部输出后 `git status` 干净 —— 输出字节级可复现，commit message 中的 EXACT 数字可信。

**但有一个重要保留**：v3 的 14 个语法错误样例的 golden 内嵌了本机绝对路径（`/Users/fitz/REPO/vue-sfc-compiler-dart/xxx.vue:1:1:`，共 22 个文件），而 `verifier/v3/compare.mjs` 是纯字节比较、无路径归一化。**换机器或换 clone 目录后 75/75 必然出现 11 个假 DIFF**。"全绿" 目前只在原作者机器上成立。见 H1。

---

## 二、总体结论

这是一批**完成度和保真度都相当高**的移植：错误帧逐字节移植、官方 quirk 有意识保留并注释（`locStub` 共享、`lookAhead` 边界、NaN 传播、`PatchFlagNames[-1]`、JS 负下标等）、样例驱动的提交节奏纪律良好、旧架构删除干净。验证体系（官方输出作 ground truth + 逐字节 EXACT + runs/ 留痕）是本仓库最大的优点。

但深审发现了**若干现有样例未覆盖的真实缺陷**，其中 6 项严重（可产出损坏/错误产物或整编译崩溃）、十余项中级偏差。所有"全 EXACT"结论的边界是：**样例没覆盖到的输入路径仍会出错**，尤其是非 ASCII 源码（偏移单位混用）与 v-memo/嵌套 :deep/畸形 CSS 等组合场景。

---

## 三、严重问题（建议优先修复）

### S1. mini_magic：移动区间内的 edit 被渲染两次，产物损坏
- `lib/script/mini_magic.dart:96-125`（`_renderRange` 应用区间内 replacement）与 `:150-157`（主循环对同一 edit 再次写出）。
- 触发路径：`script_compile.dart:437-441` 对 `<script>` 的 `export default` 做 overwrite（落在移动区间内）→ `:135` `moveToFront`。
- 已端到端复现：`<script setup>` 在前、`<script>` 在后时，产物尾部出现重复替换文本（非法 JS）。
- 同族隐患：M1（`_takeOutro(from)` 位置错）、M2（重叠 edit 静默"先到先得"，magic-string 会 throw）。

### S2. css_ast walk 的 `return false` 语义与 postcss 相反
- `lib/style/css_ast.dart:138-144`：官方 visitor 返回 false = **终止整棵遍历**；Dart 实现 = 跳过子树、继续兄弟。
- 波及 `css_stringify.dart` 全部 first-match raw 探测（`:133/:228/:247/:275/:296/:314/:337/:352/:370`）：从"取第一个匹配"变为"被后续匹配覆盖"。实测：`.a{color:red;\n .b{x:y}\n}\n.c{d:e}` scoped 后官方 `&[data-v-test]{color:red\n  }`，Dart `&[data-v-test]{color:red}`。

### S3. scoped 插件按旧版官方移植，缺 3.5.x 嵌套 `:deep` 支持
- `lib/style/plugins_scoped.dart`：缺 `isDeepContainerPseudo` / `hasNestedDeep` 守卫 / `splitSelectorForNestedDeep`。
- 实测 `:not(:deep(.a)) .b{x:y}`：官方 `:not([data-v-test] .a) .b`；Dart **把 `:deep` 字面量泄漏进产物** `:not(:deep(.a)) .b[data-v-test]`。`:is/:has` 混合场景同样漏拆分。

### S4. style 异常捕获过窄，畸形输入直接崩溃
- `lib/sfc_compile_style.dart:43-48` 只 catch `CssSyntaxError`/`SelSyntaxError`；官方 `doCompileStyle` catch-all 进 `result.errors`。
- 实测 `:global{x:y}` / `:slotted{x:y}` 在 `plugins_scoped.dart:168/:203` 抛未捕获 `RangeError`，**逃出 `compileStyleSource` 使整个编译崩溃**（官方返回 error 对象）。

### S5. const_eval 覆盖不到时给错值而非 bail
- `lib/template/transforms/const_eval.dart:272-283`（`_looseEq` 不实现 ToPrimitive：`[] == ''` JS true / Dart false）；`:195`（`in` 只支持 Map：`'0' in ['a']` 错）；`:238`（`math.pow(2,1024)` int 回绕 vs JS Infinity）；`:163-165`（带符号十六进制）。
- 违反"不支持必须 bail"原则；官方 `new Function()` 对任意合法 JS 都正确。同类：`stringify_static.dart:275-290` 调用链无兜底，`const_eval.dart:291` 超 int64 hex 字面量直接 `FormatException` 崩溃。

### S6. v-memo + `<template v-for>` + `:key` 表达式双重处理
- `lib/template/transforms/v_for.dart:24-29` 处理一次，`:89-94` 对 `keyProperty.value` 再处理一次（官方 3.5.41 只处理一次）。key 为作用域外标识符时生成 `_ctx._ctx.foo`，**静默产出错误代码**。

### H1（基础设施）. v3 golden 内嵌机器绝对路径，跨机不可复现
- `samples_style/style_err_*.md` 与 `samples_style_dart/` 对应 11+11 个文件；`verifier/v3/compare.mjs` 无路径归一化。另把用户目录写进了仓库历史。HANDOFF.md:40 虽自我声明，但无任何缓解（比较器归一/生成时剥路径均未做）。

### H2（基础设施）. v1 比较器无退出码
- `verifier/v1/compare.mjs:36` 只打印不 `process.exit(...)`，v2/v3 都有。三套验证器契约不一致，v1 无法接 CI（DIFF 静默通过）。

---

## 四、中级问题

### script（lib/script/）
| # | 位置 | 问题 |
|---|---|---|
| M3 | `script_compile.dart:431-441` | `export { default as X } from 'y'` 被 `head.contains('default')` 误判为 export default，改写出非法 JS |
| M4 | `script_compile.dart:453-463` | `export default function/class` 的名字被错误登记进 `scriptBindings`（`__returned__`/bindingMetadata） |
| M5 | `bindings.dart:205-208` | `const props = defineProps(...)` 绑定类型 `setup-const`，官方为 `setup-reactive-const` |
| M6 | `script_compile.dart:685-687` vs `binding_metadata.dart:68-69` | propsDestructureRestId 两处绑定类型矛盾，靠事后覆盖"救回" |
| M7 | `macro_process.dart:377-388` | `_stripGetSet` UTF-8 字节差 vs UTF-16 substring 混用，含中文时切错位置/RangeError |
| M8 | `sfc_compile_script.dart:71/:92/:73` | `_validateNormalScriptExports` 字节/字符偏移混用（仅影响报错定位）；`:67` 自带 "todo 不应使用正则" |
| M9 | `ts_parser.dart:71-75` | oxc 解析异常 → 返回含 ERROR 节点的树继续编译，**解析失败被静默吞掉**（官方抛 SyntaxError） |
| M10 | `type_infer.dart:182-185/:159-186` | interface extends 不解析、`Partial/Pick/Omit/Record` 不展开、不可解析引用不报错——官方报错处这里**静默产出空 props** |
| M11 | `type_infer.dart:104-113` | union/intersection 同名键 last-wins 覆盖，官方 mergeElements 合并 |
| M12 | `script_compile.dart:188` | scopeId 用 filename 冒充 options.id，正则几乎永不匹配（死代码），v-bind CSS 变量名与官方不一致 |

### template（lib/template/）
| # | 位置 | 问题 |
|---|---|---|
| T3 | `v_model_core.dart:27-41` | 缺 3.5.41 新增 X_V_MODEL_ON_CONST（45）检查，golden 来自 3.5.41 会对不上 |
| T4 | `html_attrs.dart:10-12` | `isBooleanAttr` 缺 7 属性（itemscope/allowfullscreen/formnovalidate/ismap/nomodule/novalidate/readonly） |
| T5 | `stringify_static.dart:259-260` | 缺 `:hidden` number 隐藏分支 |
| T6 | `build_props.dart:355-356` | ref 常量判定顺序：`<div :ref="'x'">` 官方 512 NEED_PATCH，Dart 无 flag |
| T7 | `compile_template.dart:181-202` | transform 管线顺序与官方不同：`<script v-if>`/`<style v-for>` 官方先整体删除，Dart 会先被指令转换保留 |
| T8 | `slot_outlet.dart:99-102` | 错误 36 文案硬编码旧版文本 |
| T9 | `expression_cache.dart:82-86` | ffi/bin 模式下错误表达式被缓存且命中时不检查 ERROR 节点（默认 concat 模式无此问题） |
| T10 | `stringify_static.dart` | evaluateConstant 抛错无降级 → 整编译崩溃（同 S5） |

### style（lib/style/）
| # | 位置 | 问题 |
|---|---|---|
| Y4 | `sfc_compile_style.dart:34` | BOM 剥除后不回写（官方输出前重写 `\uFEFF`） |
| Y5 | `selector_parser.dart:558-580` | `_gobbleHex` 漏大写 A-F；surrogate/`\0`/超界应返 `\uFFFD` 而非空串 |
| Y6 | `plugins_css_vars.dart:42-50` | 单字符引号 `v-bind("'")` 与官方 normalize 结果不同（`length >= 2` 条件多余） |

### 基础设施
| # | 位置 | 问题 |
|---|---|---|
| I1 | `.gitignore:155`（6f6f37c） | 无结尾换行的 `.vscode` 行被拼成 `.vscodeprobe*` —— `.vscode` 不再被忽略 + 模式无意义，属损坏的编辑 |
| I2 | commit 6f6f37c | 提交信息声称"更新 HANDOFF.md"，实际该 commit 未改 HANDOFF.md |
| I3 | makefile / README / CHANGELOG | 范围内均未同步新架构；CHANGELOG.md:15 仍引用已删除的 `lib/sfc_script_codegen.dart` |
| I4 | `lib/template/html_attrs.dart` | "copied verbatim from shared.cjs.js" 未标注 Vue 版本与上游 MIT 版权声明；package.json `vue ^3.5.24` 未精确 pin 3.5.41，ground truth 可复现性依赖 lock 文件 |

---

## 五、轻微问题（摘要）

- **script**：script 内容以 `\n` 结尾时多补一个换行；`__returned__` 未按 `isImportUsed` 过滤（TS 场景）；`indexOf('>')` 推断 startOffset 在属性值含 `>` 时错位；`declare const/enum` 未排除出绑定；method_signature 可选标记恒 false；`css_vars.dart:76` 正则多转义 `\-`；`import { "x-y" as z }` 抛 StateError；`script_compile.dart:384` 边界条件 `i+1 < len` 应为 `i < len`；jsonEncode 助手在 destructure/runtime_decls 重复实现；错误前缀两套格式（`[vue/compiler-sfc]` vs `[@vue/compiler-sfc]`）；`__propsAliases` 扁平键与官方嵌套 JSON 形状不同。
- **template**：tokenizer 缺 `entityDecoder.end()`（文末截断实体不解码）；错误 29/46/62 的 loc 与官方不一致（仅影响定位）；`assertTmpl` 死代码且条件反向；错误码编号自 45 起与 3.5.41 整体错位一位（golden 不受影响，外部消费 code 会错）；`_genNullableArgs` `??` vs `||`（现不可达）。
- **style**：缺 `lastBadParen` 缓存分支（token 流可能不同，输出多数一致）；`_lineStarts` 未缓存（性能）；`plugins_trim.dart:1-2` 头注释失实；`SelRaws.partSpaces` 双份存储。
- **基础设施**：比较器不检测 `samples_*_dart/` 孤儿文件；`dump_tmpl_ast` 贪婪正则抽模板有错抽风险；v3 runs/ 记录是人工总结而非原始 stdout，无法独立复核。

---

## 六、专项核实结论（点名项）

1. **typeScope 跨 parse 隐患：已修复**（`type_infer.dart:31-48` 条目携带块级 SrcView），与 verifier/README 记录一致。
2. **options_bindings.dart 对照官方 analyzeScriptBindings.ts：无遗漏分支**。
3. **stringify_static cached-as-array：无 off-by-one**，坐标换算数学等价已推演证明。
4. **tokenizer/parser 主循环**：每字符必前进、无死循环/越界风险；`slice()` 正确模拟 JS 负索引/钳制。
5. **hash-sum/genVarName(isProd)**：int32 截断、负值 `*-2`、padLeft(8)、`v` 前缀，6 组对抗输入全部一致。
6. **错误体系**：postcss offset→行列二分、showSourceCode 帧（含 >160 长行 quirk）、selector-parser 全部错误文案逐字节一致。
7. **await_transform**：与官方 topLevelAwait.ts 逐行一致。
8. **旧文件删除**：sfc_macro / sfc_script_codegen / validate_usage 无功能残留引用（仅 `ts_ast.dart:2` 悬空注释）。
9. **样例数量一致性**：752b4ea 时 tmpl 89=89=89、style 75=75=75。
10. **`dart analyze` 干净**；dynamic 滥用不构成问题（以 `Object?` 为主）。

---

## 七、建议（按优先级）

1. **P0**：修 S1（mini_magic move×edit 语义，建议重构为"每个偏移的编辑归属唯一 chunk"）、S4（style catch-all）、S5+S10（const_eval 不支持即抛 + evaluateConstant 调用链加降级）——三者都是静默坏产物/崩溃。
2. **P0**：v3 比较器加错误文本路径归一（或生成时用固定占位目录），并在 v1 补退出码——两行代码换回跨机可复现性。
3. **P1**：S2（walk false 语义）、S3（scoped 升级到 3.5.41）、S6（v-memo key 双处理）；用现有 verifier 框架为每项补回归样例。
4. **P1**：偏移单位纪律——把 `_stripGetSet`、`_validateNormalScriptExports` 纳入 SrcView 层；补非 ASCII 源码样例（当前样例全 ASCII，M7/M8 完全隐形）。
5. **P2**：M9 解析失败立为显式错误通道；M10 对"defineProps 类型实参解析得零键"加告警；恢复 `.gitignore`；makefile 加 v2/v3/verify 目标；CHANGELOG/README 同步。
6. **P2**：钉死 `@vue/compiler-sfc@3.5.41` 精确版本；html_attrs 等逐字移植文件补上游版本与 MIT 版权声明。

---

## 八、结论

**可以合入/保留**：架构方向正确、验证方法论扎实、移植纪律严谨，EXACT 声明经实测属实。**但不建议当作"已对齐官方"直接投产**：在修复 S1–S6 之前，以下输入会产生损坏或错误输出——`<script>` 在 `<script setup>` 之后的 SFC、混合格式 CSS 的 scoped 处理、含 `:deep` 的 `:not/:is/:has` 选择器、空 `:global/:slotted`、v-memo+template v-for+动态 key、以及依赖常量折叠 loose-eq/`in`/大数运算的静态提升模板。另需知晓 75/75 的 v3 EXACT 目前仅在本机成立（H1）。
