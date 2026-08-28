# 合并审查报告：cb10acb..81692c4（全量）

- 合并日期：2026-08-28
- 合并来源：
  - 《Commit 审查报告：cb10acb..752b4ea》（三大域移植 + 旧架构删除，20 commits）
  - 《ox alpha 提交全面审查报告》（752b4ea..81692c4，63 commits）
- 审查方式：沿用两份原始报告的实测结论（逐行对照 pinned `@vue/compiler-sfc@3.5.41` / `postcss@8.5.26` dist + 双端探针 + verifier 独立复跑），并于 2026-08-28 在 HEAD（dc6457d）抽查关键项修复状态。
- 编号说明：本文使用**统一编号** C*/M*/m*/I*，原文编号以「原」标注。两份原报告的 M1/M2 指代完全不同的东西，引用历史报告时务必带报告前缀。

---

## 一、验证结果与可复现性

| 验证器 | 实测结果 | 说明 |
|---|---|---|
| v1 (script/SFC) | 159/159 EXACT | 比较器**无退出码**（I-C8b），无法接 CI |
| v2 (template) | 115/115 EXACT | 正常 |
| v3 (style) | 75/75 EXACT | golden 内嵌本机绝对路径（I-C8a），**跨机必然假 DIFF** |
| v4 (inline expr) | 12/12 EXACT | 样例只覆盖后缀 `count++`，左值家族盲区 |

重新生成全部输出后 `git status` 干净，EXACT 数字可信。但"全绿"的证明力边界：**样例集全 ASCII、单形态**，对非 ASCII、inline 左值、TS ambient、畸形 CSS、错误码数值均无覆盖。

### HEAD 抽查复核（2026-08-28，dc6457d）
以下关键项**确认仍未修复**：`bindings.dart` setupConst（C-关联 M 项）、`expression_cache.dart` 缓存命中无错误检查（M4）、`tokenizer._finish()` 无 `entityDecoder.end()`（M15）、`X_V_MODEL_ON_CONST` 缺失（m1）、`isDeepContainerPseudo` 缺失（M2）。

---

## 二、总体结论

63+20 个提交的主干质量高：所有提交信息中的对拍声明经独立复跑**全部属实且偏保守**；错误帧逐字节移植、官方 quirk 有意识保留并注释、旧架构删除干净、验证体系（官方输出作 ground truth + 逐字节 EXACT + runs/ 留痕）是本仓库最大优点。Rust/FFI 内存安全核验通过。

但合并去重后仍有 **8 个 critical、16 个 major**，集中特征是：**现有 verifier/样例集覆盖不到的场景**。门禁全绿对这些场景没有证明力。三个根因横跨两个阶段贯穿始终（见第七节）。

---

## 三、Critical（8）

### C1. concat 默认模式下，非 ASCII 表达式之后的所有 span 错位，产物损坏
（原 OX-C1；引入 56f3692 / 默认化 26d1561）
- 位置：`lib/template/transforms/expression_cache.dart:104-135`
- 单位混用：`cursor`/`len` 为 UTF-16 code unit，`el.startByte/endByte` 为 UTF-8 字节。任一靠前表达式含多字节字符时，后续 rebase delta 偏小、整棵子树 span 右移；`_lineStarts`/`_pointAt` 同错。
- 实证：`{{ '中' + a }}` + ≥8 表达式触发 concat → `_toDisplayString(v0_ctx. + 1)`；`TS_EXPR_BATCH=off` 输出正确。
- **当前默认配置下的活跃 bug，中文项目几乎必踩，两份报告共识最高优先级。**

### C2. mini_magic：移动区间内的 edit 被渲染两次，产物损坏
（原 COMMIT-S1；同族：原 COMMIT-M1/M2 —— `_takeOutro(from)` 位置错、重叠 edit 静默"先到先得"而 magic-string 会 throw）
- 位置：`lib/script/mini_magic.dart:96-125` 与 `:150-157`
- 触发：`script_compile.dart:437-441` 的 `export default` overwrite 落在移动区间 → 主循环重复写出，产物尾部出现非法 JS。
- 修复建议：重构为"每个偏移的编辑归属唯一 chunk"。

### C3. style 异常捕获过窄，畸形输入直接崩溃
（原 COMMIT-S4）
- `lib/sfc_compile_style.dart:43-48` 只 catch `CssSyntaxError/SelSyntaxError`；官方 catch-all 进 `result.errors`。
- 实测 `:global{x:y}` / `:slotted{x:y}` 在 `plugins_scoped.dart:168/:203` 抛未捕获 `RangeError`，**穿透 `compileStyleSource` 使整个编译崩溃**。

### C4. const_eval 覆盖不到时给错值而非 bail，调用链无降级
（原 COMMIT-S5 + T10）
- `const_eval.dart:272-283`（`_looseEq` 不实现 ToPrimitive：`[] == ''` JS true / Dart false）；`:195`（`in` 只支持 Map）；`:238`（`math.pow(2,1024)` 回绕 vs Infinity）；`:163-165`（带符号 hex）；`:291`（超 int64 hex 直接 `FormatException`）。
- `stringify_static.dart:275-290` 调用链无兜底，`evaluateConstant` 抛错 → 整编译崩溃。
- 违反"不支持必须 bail"原则；官方 `new Function()` 对任意合法 JS 都正确。

### C5. TSDeclareFunction/TSModuleDeclaration 未实现，合法 TS 硬崩溃
（原 OX-M9②；引入 83b6c11）
- `oxc_mapper.dart:214-216` 登记进 dispatch 却路由到 `throw UnimplementedError`。实测 `declare function gtag(...): void`、`namespace N {}` 硬崩溃穿透 compileScript。旧 tree-sitter 后端可解析，属迁移回归。

### C6. inline 左值家族：复合赋值/前缀自增/解构赋值/new 产出非法或误编译 JS
（原 OX-M3/M4/M5/M7；同一源代码区域，建议一起修）
- `+=`：`transform_expression.dart:216-234` 不认 `augmented_assignment_expression` → `_unref(n) += 2`（SyntaxError）。
- `++n`：`:197-204` opText 固定从参数末尾切，前缀 `++` 彻底丢失；`_opStart`(:239) 另有 byte/char 二次转换隐患。
- 解构赋值左值：官方 `isInDestructureAssignment` 未移植 → `[_unref(a)] = [1]`。
- `new C()`：官方 `isInNewExpression` 未移植 → `new _unref(C)()`。
- 解构显式键值/默认值：`expression_walk.dart:492-507` 入口守卫缺 `pair_pattern`（新 case 成死分支）、`transform_expression.dart:354-360` 误入 shorthandKey → `({ x: y } = v)` 裸 `y` 解析为全局、`({ a = b } = v)` 多注入 `key: ` 前缀。
- v4 样例只覆盖后缀 `count++`，故全部未暴露。

### C7. tsx 脚本含 JSX 时静默整体降级为未编译透传
（原 OX-M9③；引入 00e433b）
- compile 层把 tsx 折叠为 ts（`script_compile.dart:67`），JSX 触发 oxc panic → errorTree → 脚本侧不检查 ERROR → bindings 为空、defineProps 不编译、整块原样透传且不报错。silent wrong output 比崩溃更隐蔽；修复后从 silent 变 fail loud 是质变。

### C8.（基础设施）跨机可复现性与 CI 门禁
（原 COMMIT-H1 + H2）
- **a**：v3 的 14 个语法错误样例 golden 内嵌本机绝对路径（22 个文件），`verifier/v3/compare.mjs` 纯字节比较无归一化——换机后 75/75 必出 11 个假 DIFF；用户目录已写进仓库历史。
- **b**：`verifier/v1/compare.mjs:36` 只打印不 `process.exit`，v2/v3 都有——DIFF 静默通过。
- 两行代码换回跨机可复现性，性价比最高的 P0。

---

## 四、Major（16）

| # | 位置 | 问题 | 原 |
|---|---|---|---|
| M1 | `css_ast.dart:138-144` | walk 的 `return false` 语义与 postcss 相反（终止遍历 vs 跳子树），波及 `css_stringify.dart` 全部 9 处 first-match raw 探测；实测 scoped 输出差异 | COMMIT-S2 |
| M2 | `plugins_scoped.dart` | 缺 3.5.x `isDeepContainerPseudo`/`hasNestedDeep`/`splitSelectorForNestedDeep`；`:not(:deep(.a))` 把 `:deep` 字面量泄漏进产物 | COMMIT-S3 |
| M3 | `v_for.dart:24-29, 89-94` | v-memo + `<template v-for>` + `:key` 双重处理（官方一次），key 为外部标识符时静默产出 `_ctx._ctx.foo` | COMMIT-S6 |
| M4 | `expression_cache.dart:82-86` + `transform_expression.dart:267-268` | ffi/bin 批量模式缓存命中直接 return，吞掉 `_hasErrorNode` 检查与 error 45；实测 `{{ a + % }}` + 8 表达式在 ffi 模式报错列表为空。与 PERF_BENCHMARK.md 把 ffi 列为可用回退路径相冲突 | OX-M1 ＝ COMMIT-T9（合并） |
| M5 | `est_node.dart:38,55-56` | `JsonEstNode._canonical` 进程级 static identity Map 无淘汰，长驻进程 RSS 单调增长（bench 佐证 tmpl_heavy ≈97MB / large ≈708MB）；全仓无身份依赖消费点，删或加淘汰 | OX-M2 |
| M6 | ast_diff / OXC_REFERENCE.md | oxc 切换后 `TSParser.parse` 内部已是 oxc 链，ast_diff EXACT 恒真（自比较），`ast_diff 449/452` 硬性回归门已无拦截能力 | OX-M9① |
| M7 | `ts_parser.dart:71-75` | oxc 解析异常 → 返回含 ERROR 节点的树继续编译，解析失败被静默吞掉（官方抛 SyntaxError） | COMMIT-M9 |
| M8 | `type_infer.dart:182-185` | interface extends 不解析、`Partial/Pick/Omit/Record` 不展开、不可解析引用不报错——官方报错处静默产出空 props | COMMIT-M10 |
| M9 | `script_compile.dart:431-441` | `export { default as X } from 'y'` 被 `head.contains('default')` 误判为 export default，改写出非法 JS | COMMIT-M3 |
| M10 | `script_compile.dart:453-463` | `export default function/class` 名字被错误登记进 `scriptBindings` | COMMIT-M4 |
| M11 | `script_compile.dart:685-687` vs `binding_metadata.dart:68-69` | propsDestructureRestId 两处绑定类型矛盾，靠事后覆盖"救回" | COMMIT-M6 |
| M12 | `type_infer.dart:104-113` | union/intersection 同名键 last-wins，官方 mergeElements 合并 | COMMIT-M11 |
| M13 | `script_compile.dart:188` | scopeId 用 filename 冒充 options.id，正则几乎永不匹配（死代码），v-bind CSS 变量名与官方不一致 | COMMIT-M12 |
| M14 | `compile_template.dart:181-202` | transform 管线顺序与官方不同：`<script v-if>`/`<style v-for>` 官方先整体删除，Dart 会先被指令转换保留 | COMMIT-T7 |
| M15 | `tokenizer.dart:658-662` | 缺官方 EOF 时 `entityDecoder.end()`：官方 `a &amp` → `a &`，Dart 原样保留；`EntityDecoder.end()` 成死代码且 doc 注释与官方行为相反（误导） | OX-M8 ＝ COMMIT 轻微（升格） |
| M16 | `macro_process.dart:377-388`、`sfc_compile_script.dart:71/92/67` | **偏移单位混用（script 侧）**：`_stripGetSet` UTF-8 字节差 vs UTF-16 substring（含中文切错/RangeError）；`_validateNormalScriptExports` 字节/字符偏移混用；自带 "todo 不应使用正则" | COMMIT-M7+M8 |

注：原 COMMIT-M5（`const props = defineProps` 应为 `setup-reactive-const`，`bindings.dart:205-208`）＝原 OX-M6，两份报告独立发现，HEAD 确认未修，一行级修复，归入 **m0**（见下表）。

---

## 五、Minor（合并去重）

| # | 位置 | 问题 | 原 |
|---|---|---|---|
| m0 | `bindings.dart:205-208` | `const props = defineProps(...)` 绑定 kind 应为 `setup-reactive-const`（模板 codegen 不受影响，但 bindingMetadata 是公开契约）；v4 样例恰好全未覆盖 | COMMIT-M5 ＝ OX-M6（合并） |
| m1 | `tmpl_error_messages.dart` 等 6 处 | 缺官方错误码 45（X_V_MODEL_ON_CONST），45 起整体偏移一位；verifier 只比 message 不比 code，静默偏离；文件头 "extracted verbatim" 失实 | COMMIT 轻微 ＝ OX-m1（合并）；含 COMMIT-T3 |
| m2 | `type_infer.dart:91-113` | `@vue-ignore` 只覆盖 intersection/union 首成员；单类型情形未按官方返回 `{props:{}}` | OX-m2 |
| m3 | `stringify_utils.dart:196-206` 双份实现 | parseStringStyle 首冒号切分与官方 `split(/:([^]+)/)` 边界不等价 | OX-m3 |
| m4 | `sfc_compile_script.dart:23-39` | normal script（无 setup）+ style v-bind 缺 useCssVars 注入；HANDOFF 未标注边界 | OX-m4 |
| m5 | `yarn.lock` | Linux 平台二进制条目被替换成 darwin-arm64 | OX-m5 |
| m6 | `tools/gen_entity_decode_data.mjs` | entities 数据 4.5.0 vs node_modules 7.0.1，脚本原样运行失败 | OX-m6 |
| m7 | `mapper_stmt.dart:46-52`、`mapper_expr.dart:147-160` | do-while 漏 `extendStatementEnd`；转义字符串恒产单个 string_fragment；语料零覆盖 | OX-m7 |
| m8 | `makefile:84-91`、`oxc_ffi.dart:96-107` | build-worker 与 `_candidates` 硬编码 `.dylib`，Linux 不可用 | OX-m8 |
| m9 | `html_attrs.dart:10-12` | `isBooleanAttr` 缺 7 属性（itemscope/allowfullscreen/formnovalidate/ismap/nomodule/novalidate/readonly） | COMMIT-T4 |
| m10 | `stringify_static.dart:259-260` | 缺 `:hidden` number 隐藏分支 | COMMIT-T5 |
| m11 | `build_props.dart:355-356` | ref 常量判定顺序：`<div :ref="'x'">` 官方 512 NEED_PATCH，Dart 无 flag | COMMIT-T6 |
| m12 | `slot_outlet.dart:99-102` | 错误 36 文案硬编码旧版文本 | COMMIT-T8 |
| m13 | `sfc_compile_style.dart:34` | BOM 剥除后不回写 | COMMIT-Y4 |
| m14 | `selector_parser.dart:558-580` | `_gobbleHex` 漏大写 A-F；surrogate/`\0`/超界应返 `\uFFFD` | COMMIT-Y5 |
| m15 | `plugins_css_vars.dart:42-50` | 单字符引号 `v-bind("'")` normalize 结果不同（`length >= 2` 条件多余） | COMMIT-Y6 |

**未编号轻微项（摘要，保留原报告措辞）**
- script：`\n` 结尾多补换行；`__returned__` 未按 `isImportUsed` 过滤；`indexOf('>')` 推断 startOffset 属性值含 `>` 时错位；`declare const/enum` 未排除出绑定；method_signature 可选标记恒 false；`css_vars.dart:76` 正则多转义；`import { "x-y" as z }` 抛 StateError；`script_compile.dart:384` 边界条件；jsonEncode 助手重复实现；`__propsAliases` JSON 形状不同。
- template：错误 29/46/62 的 loc 不一致；`assertTmpl` 死代码且条件反向；`_genNullableArgs` `??` vs `||`（现不可达）。
- style：缺 `lastBadParen` 缓存分支；`_lineStarts` 未缓存；`plugins_trim.dart` 头注释失实；`SelRaws.partSpaces` 双份存储。
- infra：比较器不检测 `samples_*_dart/` 孤儿文件；`dump_tmpl_ast` 贪婪正则有错抽风险；v3 runs/ 是人工总结非原始 stdout。

---

## 六、Info / 基础设施卫生

- **I1** `.gitignore:155`（6f6f37c）：无结尾换行的 `.vscode` 行被拼成 `.vscodeprobe*`——`.vscode` 不再被忽略，属损坏的编辑（原 COMMIT-I1）。
- **I2** commit 6f6f37c：提交信息声称"更新 HANDOFF.md"实际未改（原 COMMIT-I2）。
- **I3** makefile/README/CHANGELOG 未同步新架构；CHANGELOG.md:15 仍引用已删除的 `lib/sfc_script_codegen.dart`（原 COMMIT-I3）。
- **I4** `html_attrs.dart` "copied verbatim" 未标注 Vue 版本与 MIT 版权；`vue ^3.5.24` 未精确 pin 3.5.41（原 COMMIT-I4）。
- **I5** dfd2ecf 把全仓 dart format 噪音（71 文件 +18662 行）混入功能提交，bisect/回滚粒度变差（原 OX-info）。
- **I6** 文档/注释漂移：FFI_MIGRATION.md 引用不存在的 `b6d19aa`；`ts_parser.dart` 注释提及已删除的 ts_ffi.dart；oxc_ffi/oxc_mapper "purely additive" 注记失实；`bin_est_node.dart:213` 自注 DEBUG 无调用方；`diff_transport.dart` 恒 false 死分支；worker lib.rs doc 停留 OXB1（原 OX-info）。
- **I7** 错误消息前缀双轨：`[vue/compiler-sfc]` vs `[@vue/compiler-sfc]`；gen_official.mjs 的 `Vue Compile Error: ` 是项目历史约定而非官方产物（两报告各提一次，合并）。
- **I8** 7c3a0dd 修改参照侧（给官方 ground truth 加前缀）+ samples.json 600+ 行纯缩进 churn 掩盖实际新增回归样例（原 OX-info）。
- **I9** `namedOnly`/`maxDepth` 死参数；oxc 可恢复 diagnostics 被静默丢弃（残余风险类）（原 OX-info）。
- **I10** tools/ `_` 前缀临时探针取舍不一致；README 能力矩阵未更新（写 157/114 实际 159/115）（原 OX-info）。
- **I11** AST dump 白名单盲区（438/438 SAME 说明现实风险低）；`tmpl_parser.slice` 负下标只对齐一半；`_isCallOfName` 误判 tagged template（原 OX-info）。
- **I12** `source_map.dart` toJSON 循环内 `buf.toString()` O(n²)；起止映射守卫与官方 locStub 对象身份判定有代理差异（可能是 596/700 差异来源）（原 OX-info）。

---

## 七、共性根因（横跨两个阶段）

1. **偏移单位纪律缺失**：C1（concat span）、C6（_opStart）、M16（script 侧）、m14 全是同一类病。修单点不如把 SrcView 层立为强制规范，并补非 ASCII 门禁样例（当前样例全 ASCII，M16/C1 完全隐形）。
2. **静默错误 > 崩溃 > 报错 的倒挂**：C7（tsx 透传）、M4（吞 error 45）、M7（oxc 吞解析失败）、M8（静默空 props）、C4（const_eval 给错值不 bail）——全部是"该报错的地方产出了错误产物"。统一修复方向：**失败必须走显式错误通道**。
3. **门禁盲区一致**：两份报告独立得出同一结论——全绿样例集是全 ASCII、单形态的；每修一项必须配回归样例，否则门禁对复发无证明力。

---

## 八、已排除的疑似问题（核查确认无偏差）

- walkDeclaration/canNeverBeRef/isStaticNode 全规则、hoistStatic 默认值、cacheStatic 对象身份匹配、_maybeUnblock 传播、enum 字面量判定——与官方一致。
- codegen with-block、_injectSlotKey、vForMemoKeyedNodes、_cached.el 守卫、@vue:* camelize、defineModel template literal、.prop locStub 怪癖、delimiters 构造注入——与官方 3.5.41 一致。
- pointAt 二分与线性扫描同语义；SrcView ASCII 快路、缓存键/复位修复无回归。
- EntityDecoder 算法本体与 entities 4.5.0 逐项一致；tree-sitter 拆除无残留。
- Rust FFI：oxc_parse/oxc_free 配对、catch_unwind 隔离、boxed slice 布局、异常路径 malloc/free 完整。
- typeScope 跨 parse 隐患已修复；options_bindings.dart 无遗漏分支；stringify_static cached-as-array 无 off-by-one；tokenizer/parser 主循环无死循环/越界；hash-sum/genVarName 6 组对抗输入一致；错误体系（postcss 行列、showSourceCode 帧、selector-parser 文案）逐字节一致；await_transform 逐行一致；旧文件删除无功能残留；`dart analyze` 干净。

---

## 九、统一修复优先级（更新版）

### P0 —— 活跃产出损坏代码/崩溃/不可复现（合并后 8 项）
1. **C1** concat 非 ASCII span 错位（修单位 + 补非 ASCII + ≥8 表达式 v2 门禁样例）
2. **C2** mini_magic move×edit 双渲染（重构为偏移→chunk 唯一归属）
3. **C3** style catch-all
4. **C4** const_eval 不支持即抛 + evaluateConstant 调用链降级
5. **C5** declare/namespace 补 mapper 或显式报错
6. **C6** inline 左值家族（同区域一起修，各补 v4/v2 样例）
7. **C7** tsx 静默透传改 fail loud
8. **C8** v3 路径归一（或生成时固定占位目录）+ v1 退出码——两行代码，先做

### P1 —— 边缘场景错误产物与门禁修复
- M1（walk false 语义）、M2（scoped 3.5.41 嵌套 :deep）、M3（v-memo key）、M14（管线顺序）——每项配回归样例
- M4（ffi/bin 吞错，或文档降级 ffi/bin 为实验路径）、M15（EOF 实体）、M5（_canonical 删缓存/加淘汰，先确认无身份依赖）
- M6（重建 oxc 回归门，否则后续 bump 无保护）
- **偏移单位纪律专项**：M16 纳入 SrcView 层；与 C1 同批补非 ASCII 样例

### P2 —— 显式错误通道与契约对齐
- M7/M8/M9/M10/M11/M12/M13（script/type_infer 家族，多为报错与登记正确性）
- m0（setup-reactive-const，一行）、m1（错误码偏移，修完 ErrorCodes 才是可依赖契约）、m2–m15
- I1 恢复 `.gitignore`；I3 makefile 加 v2/v3/verify 目标；I4 pin 3.5.41 + 补版权声明；I6/I7 文档专项清理

### 收益评估摘要（沿用 OX 报告 2026-08-27 结论）
- **性能收益几乎没有**：全部是正确性/健壮性缺陷。两个例外——M5 是内存收益（watch/server 场景 RSS 单调增长消失），I12 对大文件 sourcemap 有真实收益（默认不开）。性能路线已在 20e58f6 收尾（AOT 全六档领先官方）。
- **健壮性收益是本批修复的真正价值**，分四档：消除硬崩溃（C3/C5/C6 部分形态）；消除静默错误输出（收益最大——C1/C6/C7/M4，崩溃会被发现，静默错误会流进产物）；长驻稳定性（M5）；错误契约可信度（m1/m0/M15）。

---

## 十、结论

**可以合入/保留**：架构方向正确、验证方法论扎实、移植纪律严谨，全部 EXACT 声明经实测属实。

**但不建议当作"已对齐官方"直接投产**。在 P0 八项修复前，以下真实输入会产生损坏/错误输出或崩溃：含中文的 ≥8 表达式模板（默认配置）、`<script>` 在 `<script setup>` 之后的 SFC、混合格式 CSS 的 scoped、含 `:deep` 的 `:not/:is/:has`、空 `:global/:slotted`、`declare function`/`namespace`、inline `+=`/`++`/解构赋值/`new`、v-memo+template v-for+动态 key、依赖常量折叠 loose-eq/`in`/大数的静态提升模板、含 JSX 的 tsx。另需知晓 v3 的 75/75 目前仅在本机成立（C8a）、v1 无 CI 门禁（C8b）。

**合并后工作量评估**：C6/M4/M15/m0/m1 均为两报告重复发现或同区域收敛项；三个根因（偏移单位、静默吞错、门禁盲区）各自一次专项即可收敛大部分条目。P0 清单修完 + 每项配回归样例后，项目才从"对拍全绿的移植品"变成"可以交给别人用的编译器"。
