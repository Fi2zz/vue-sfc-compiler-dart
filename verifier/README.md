# Verifier

比较 `samples/`（官方 ground truth，经 prettier 格式化）与 `samples_dart/`（本实现输出）的逐字节一致性。

## 版本索引（append-only）

- `v1/compare.mjs`：基线比较器。级别：EXACT（字节一致）/ NORMALIZED（prettier babel 归一后一致）/ MATCH_ERROR（错误文本一致）/ DIFF / MISSING。

## 运行方式

```sh
dart run ./vue_dart.dart && npx prettier samples_dart/*.md -w --log-level warn && node verifier/v1/compare.mjs
```

注意：samples/ 由官方编译器输出经 prettier(markdown) 格式化而来，因此 samples_dart 也必须过同样的 prettier 步骤才能字节对齐（错误帧的空行硬换行、前导空白折叠均依赖此步骤）。

## 运行记录（runs/）

- `2026-08-21T1325Z_v1_baseline.txt`：基线 11/155 EXACT。
- `2026-08-21T1553Z_v1_error-frames-unified.txt`：154/155 EXACT。本轮统一错误帧为官方 generateCodeFrame 逐字移植 + prettier 管线；删除旧 codegen（sfc_script_codegen/sfc_macro/validate_usage）；`_validateNormalScriptExports` 仅作用于 JS（TS 多样例直通）。剩余 DIFF：script_and_script_setup_typescript（normal script 中 interface 未进入 typeScope，`type: null` vs `type: Object`）。
- `2026-08-21T1559Z_v1_all-exact.txt`：155/155 EXACT。修复 `_referenceType`/`_fillFromReference` 对叶子 type_identifier 节点（如 `user: User`）查找子节点失败导致的 Unknown。已知隐患（未触发）：typeScope 条目跨 parse 时未携带各自 SrcView，若 setup 整体引用 normal script 声明的 interface 作为 props 类型，成员键提取会用错 view。
