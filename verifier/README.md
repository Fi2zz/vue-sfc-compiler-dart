# Verifier

比较 `samples/`（官方 ground truth，经 prettier 格式化）与 `samples_dart/`（本实现输出）的逐字节一致性。

## 版本索引（append-only）

- `v1/compare.mjs`：基线比较器。级别：EXACT（字节一致）/ NORMALIZED（prettier babel 归一后一致）/ MATCH_ERROR（错误文本一致）/ DIFF / MISSING。
- `v2/compare.mjs`：compileTemplate 比较器。直接字节对比 `samples_tmpl/`（官方 compileTemplate 输出，gen_official_tmpl.mjs 生成，无 prettier 步骤）与 `samples_tmpl_dart/`（vue_dart_tmpl.dart 生成）。级别：EXACT / DIFF / MISSING。

## 运行方式

```sh
dart run ./vue_dart.dart && npx prettier samples_dart/*.md -w --log-level warn && node verifier/v1/compare.mjs
```

```sh
# v2 (template)
dart vue_dart_tmpl.dart && node verifier/v2/compare.mjs
```

注意：samples/ 由官方编译器输出经 prettier(markdown) 格式化而来，因此 samples_dart 也必须过同样的 prettier 步骤才能字节对齐（错误帧的空行硬换行、前导空白折叠均依赖此步骤）。

## 运行记录（runs/）

- `2026-08-21T1325Z_v1_baseline.txt`：基线 11/155 EXACT。
- `2026-08-21T1553Z_v1_error-frames-unified.txt`：154/155 EXACT。本轮统一错误帧为官方 generateCodeFrame 逐字移植 + prettier 管线；删除旧 codegen（sfc_script_codegen/sfc_macro/validate_usage）；`_validateNormalScriptExports` 仅作用于 JS（TS 多样例直通）。剩余 DIFF：script_and_script_setup_typescript（normal script 中 interface 未进入 typeScope，`type: null` vs `type: Object`）。
- `2026-08-21T1559Z_v1_all-exact.txt`：155/155 EXACT。修复 `_referenceType`/`_fillFromReference` 对叶子 type_identifier 节点（如 `user: User`）查找子节点失败导致的 Unknown。已知隐患（未触发）：typeScope 条目跨 parse 时未携带各自 SrcView，若 setup 整体引用 normal script 声明的 interface 作为 props 类型，成员键提取会用错 view。
- `2026-08-21T2353Z_v2_all-exact.txt`：v2 基线 20/20 EXACT（template 样例首批全量通过）。修复要点：单根元素 doNotHoist（官方 walk 入口对孤根元素禁提升）、genNode 字符串遇 helper 名需 `_` 前缀（Symbol 身份以 helper 名建模）、v-if 分支键循环的 JS 负下标语义、transformIf 注册顺序（createCommentVNode 在 alternate 构造时才注册）、DOM parserOptions.parseMode=html。stringifyStatic（transformHoist）暂未移植——仅当静态文本节点 ≥20 或静态元素 ≥5 时才影响输出，当前样例不触发。

```sh
# v3 (style)
dart vue_dart_style.dart && node verifier/v3/compare.mjs
```

- `2026-08-22T_style-v3-errors.txt`：v3 扩充 14 个语法错误样例，72/72 EXACT。补齐 postcss 错误定位（偏移→行列二分、path.resolve 文件名、showSourceCode 帧逐字节移植）与 selector 错误的 `Error: ` 前缀；修复属性选择器等号先于属性名的报错文案。错误文本内嵌机器绝对路径，换机需重生成 ground truth。

- `v3/compare.mjs`：compileStyle 比较器。直接字节对比 `samples_style/`（官方 compileStyle 输出，gen_official_style.mjs 生成）与 `samples_style_dart/`（vue_dart_style.dart 生成）。级别：EXACT / DIFF / MISSING。
