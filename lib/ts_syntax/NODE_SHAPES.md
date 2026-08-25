# tree-sitter 节点形状权威清单

> 生成：tools/ast_diff.dart census + rg 全量扫描消费端。mapper 实现的对照表。
> 覆盖语料 tools/ast_corpus.jsonl（452 条：samples 全管线 + batch_inputs 786）。

## 关键形状约定（消费端硬编码的结构假设）

- `binary_expression` / `logical_expression` / `assignment_expression`：`children[0]`=左，`children[1]`=右（const_eval、bindings 按下标取）
- `ternary_expression`：`children[0..2]` = test/consequent/alternate
- `pair`（对象字面量）：`children[0]`=key，末子=value；`pair_pattern` 同构
- `export_statement`：包装 export 的声明，类型收集需解包（type_infer / script_compile）
- `for_in_statement` / `for_of_statement`：循环头压平，无 `lexical_declaration` 包裹，首个具名子节点即左值模式（expression_walk）
- `switch_statement`：声明收集须下钻 `switch_body` → `switch_case`/`switch_default`
- `comment`：作为 named child 编排在树内原位置（hoistNode trailingComments 依赖）
- `ERROR`：tree-sitter 错误恢复节点（语料中 3 处，均为已豁免的 babel errorRecovery 家族；唯一消费点 transform_expression `_hasErrorNode`，只要布尔信号）
- `undefined` 是**专用节点类型**（非 identifier）；`true/false/null` 是各自字面量节点（babel Literal，不作为标识符访问）
- `type_annotation` 是标识符的**紧邻兄弟节点**（vOn 注解剥离靠 WalkedIdent 区间扩到注解尾）
- 解包链家族：`as_expression` / `satisfies_expression` / `non_null_expression` / `type_assertion` / `parenthesized_expression`（bindings.unwrapForCall、transform_expression._unwrapTop 依赖）
- `assignment_pattern` / `object_assignment_pattern`：首子节点=绑定名（默认值是外层引用）
- catch 参数三种形态：identifier / 模式 / formal_parameter 包裹
- tagged template：`call_expression` 末子节点为 template_string（无 arguments）
- member_expression 末子节点=属性（property_identifier），其余=object
- union_type / intersection_type 左深嵌套；`as const` 无类型子节点；签名类节点（property/method/call/construct signature）区间截到注解尾不含 `;`
- js 语法差异：无 `required_parameter` 包装、class 名用 `identifier`、`field_definition`、heritage 无 `extends_clause`（ts 侧为 type_identifier / public_field_definition / extends_clause+implements_clause）

## 全量节点清单（103 种，按字母序）

| 节点类型 | 语料出现次数 | 消费文件 |
|---|---|---|
| `ERROR` | 3 | `template/transforms/transform_expression.dart` |
| `arguments` | 350 | `script/destructure_transform.dart`, `script/macro_process.dart`, `script/script_compile.dart`, `template/transforms/expression_walk.dart` |
| `array` | 28 | `script/bindings.dart`, `script/macro_process.dart`, `script/node_utils.dart`, `script/options_bindings.dart`, `template/transforms/const_eval.dart` |
| `array_pattern` | 6 | `script/bindings.dart`, `script/destructure_transform.dart`, `script/node_utils.dart`, `template/transforms/expression_walk.dart` |
| `array_type` | 4 | `script/type_infer.dart`, `template/transforms/expression_walk.dart` |
| `arrow_function` | 109 | `script/bindings.dart`, `script/node_utils.dart`, `template/transforms/expression_walk.dart`, `template/transforms/transform_expression.dart` |
| `as_expression` | 6 | `script/bindings.dart`, `script/node_utils.dart`, `template/transforms/const_eval.dart`, `template/transforms/transform_expression.dart` |
| `assignment_expression` | 34 | `script/destructure_transform.dart`, `template/transforms/expression_walk.dart`, `template/transforms/transform_expression.dart` |
| `assignment_pattern` | 1 | `script/bindings.dart`, `script/macro_process.dart`, `script/node_utils.dart`, `template/transforms/expression_walk.dart` |
| `augmented_assignment_expression` | 4 | `script/destructure_transform.dart`, `template/transforms/expression_walk.dart` |
| `await_expression` | 15 | `script/await_transform.dart` |
| `binary_expression` | 61 | `script/bindings.dart`, `template/transforms/const_eval.dart` |
| `call_expression` | 339 | `script/bindings.dart`, `script/destructure_transform.dart`, `script/macro_process.dart`, `script/script_compile.dart`, `template/transforms/transform_expression.dart` |
| `call_signature` | 5 | `script/type_infer.dart` |
| `catch_clause` | 5 | `script/destructure_transform.dart`, `template/transforms/expression_walk.dart` |
| `class_body` | 2 | —（仅出现在子树中） |
| `class_declaration` | 2 | `script/bindings.dart`, `script/destructure_transform.dart`, `script/script_compile.dart`, `script/type_infer.dart`, `template/transforms/expression_walk.dart` |
| `comment` | 11 | —（仅出现在子树中） |
| `computed_property_name` | 1 | —（仅出现在子树中） |
| `conditional_type` | 1 | `template/transforms/expression_walk.dart` |
| `enum_body` | 1 | `script/bindings.dart` |
| `enum_declaration` | 1 | `script/bindings.dart`, `script/destructure_transform.dart`, `script/script_compile.dart`, `script/type_infer.dart` |
| `escape_sequence` | 2 | —（仅出现在子树中） |
| `export_clause` | 1 | `script/script_compile.dart` |
| `export_specifier` | 1 | `script/destructure_transform.dart`, `script/script_compile.dart` |
| `export_statement` | 45 | `script/options_bindings.dart`, `script/script_compile.dart`, `script/type_infer.dart` |
| `expression_statement` | 409 | `script/await_transform.dart`, `script/script_compile.dart`, `template/transforms/const_eval.dart`, `template/transforms/transform_expression.dart` |
| `false` | 6 | `script/bindings.dart`, `script/css_vars.dart`, `script/node_utils.dart`, `script/options_bindings.dart`, `script/type_infer.dart`, `template/transforms/const_eval.dart`, `template/transforms/stringify_static.dart`, `template/transforms/transform_element.dart`, `template/transforms/transform_expression.dart` |
| `field_definition` | 2 | —（仅出现在子树中） |
| `finally_clause` | 1 | —（仅出现在子树中） |
| `for_in_statement` | 4 | `script/destructure_transform.dart`, `template/transforms/expression_walk.dart` |
| `for_statement` | 5 | `template/transforms/expression_walk.dart` |
| `formal_parameters` | 155 | `script/destructure_transform.dart`, `script/runtime_decls.dart`, `template/transforms/expression_walk.dart` |
| `function_declaration` | 17 | `script/bindings.dart`, `script/destructure_transform.dart`, `script/node_utils.dart`, `script/script_compile.dart`, `template/transforms/expression_walk.dart` |
| `function_expression` | 5 | `script/bindings.dart`, `script/node_utils.dart`, `template/transforms/expression_walk.dart`, `template/transforms/transform_expression.dart` |
| `function_type` | 1 | `script/runtime_decls.dart`, `script/type_infer.dart`, `template/transforms/expression_walk.dart` |
| `generic_type` | 2 | `script/type_infer.dart`, `template/transforms/expression_walk.dart` |
| `identifier` | 1169 | `script/bindings.dart`, `script/destructure_transform.dart`, `script/macro_process.dart`, `script/node_utils.dart`, `script/runtime_decls.dart`, `script/script_compile.dart`, `script/type_infer.dart`, `template/transforms/const_eval.dart`, `template/transforms/expression_walk.dart`, `template/transforms/transform_expression.dart` |
| `if_statement` | 1 | —（仅出现在子树中） |
| `import` | 1 | —（仅出现在子树中） |
| `import_clause` | 85 | `script/script_compile.dart` |
| `import_specifier` | 129 | `script/destructure_transform.dart`, `script/script_compile.dart` |
| `import_statement` | 86 | `script/destructure_transform.dart`, `script/script_compile.dart` |
| `interface_body` | 4 | `script/type_infer.dart` |
| `interface_declaration` | 4 | `script/destructure_transform.dart`, `script/script_compile.dart`, `script/type_infer.dart` |
| `intersection_type` | 1 | `script/type_infer.dart`, `template/transforms/expression_walk.dart` |
| `lexical_declaration` | 203 | `script/bindings.dart`, `script/destructure_transform.dart`, `script/script_compile.dart`, `template/transforms/expression_walk.dart` |
| `literal_type` | 15 | `script/runtime_decls.dart`, `script/type_infer.dart`, `template/transforms/expression_walk.dart` |
| `member_expression` | 128 | `template/transforms/expression_walk.dart`, `template/transforms/transform_expression.dart` |
| `meta_property` | 1 | `template/transforms/expression_walk.dart` |
| `method_definition` | 26 | `script/destructure_transform.dart`, `script/macro_process.dart`, `script/node_utils.dart`, `script/options_bindings.dart`, `script/script_compile.dart`, `template/transforms/expression_walk.dart` |
| `method_signature` | 4 | `script/type_infer.dart` |
| `named_imports` | 79 | `script/script_compile.dart` |
| `namespace_import` | 1 | `script/destructure_transform.dart`, `script/script_compile.dart` |
| `new_expression` | 11 | `template/transforms/transform_expression.dart` |
| `null` | 4 | `script/bindings.dart`, `script/node_utils.dart`, `script/runtime_decls.dart`, `script/type_infer.dart`, `template/transforms/const_eval.dart`, `template/transforms/transform_expression.dart`, `template/transforms/v_model_core.dart` |
| `number` | 136 | `script/bindings.dart`, `script/node_utils.dart`, `script/options_bindings.dart`, `script/runtime_decls.dart`, `script/type_infer.dart`, `template/transforms/const_eval.dart` |
| `object` | 159 | `script/bindings.dart`, `script/macro_process.dart`, `script/node_utils.dart`, `script/options_bindings.dart`, `script/runtime_decls.dart`, `script/script_compile.dart`, `script/type_infer.dart`, `template/transforms/const_eval.dart`, `template/transforms/transform_expression.dart` |
| `object_assignment_pattern` | 7 | `script/bindings.dart`, `script/macro_process.dart`, `script/node_utils.dart`, `template/transforms/expression_walk.dart`, `template/transforms/transform_expression.dart` |
| `object_pattern` | 36 | `script/bindings.dart`, `script/destructure_transform.dart`, `script/macro_process.dart`, `script/node_utils.dart`, `template/transforms/expression_walk.dart`, `template/transforms/transform_expression.dart` |
| `object_type` | 34 | `script/type_infer.dart`, `template/transforms/expression_walk.dart` |
| `optional_chain` | 5 | —（仅出现在子树中） |
| `pair` | 172 | `script/destructure_transform.dart`, `script/macro_process.dart`, `script/options_bindings.dart`, `script/runtime_decls.dart`, `script/script_compile.dart`, `template/transforms/const_eval.dart`, `template/transforms/expression_walk.dart` |
| `pair_pattern` | 6 | `script/bindings.dart`, `script/macro_process.dart`, `script/node_utils.dart`, `template/transforms/expression_walk.dart` |
| `parenthesized_expression` | 182 | `script/bindings.dart`, `script/macro_process.dart`, `template/transforms/const_eval.dart`, `template/transforms/transform_expression.dart` |
| `parenthesized_type` | 2 | `script/type_infer.dart`, `template/transforms/expression_walk.dart` |
| `predefined_type` | 75 | `script/type_infer.dart`, `template/transforms/expression_walk.dart` |
| `private_property_identifier` | 1 | —（仅出现在子树中） |
| `program` | 452 | `template/transforms/const_eval.dart`, `template/transforms/transform_expression.dart` |
| `property_identifier` | 378 | `script/bindings.dart`, `script/macro_process.dart`, `script/options_bindings.dart`, `script/runtime_decls.dart`, `script/script_compile.dart`, `script/type_infer.dart`, `template/transforms/const_eval.dart`, `template/transforms/expression_walk.dart` |
| `property_signature` | 44 | `script/type_infer.dart` |
| `required_parameter` | 52 | `script/destructure_transform.dart`, `script/node_utils.dart`, `template/transforms/expression_walk.dart` |
| `return_statement` | 32 | `script/options_bindings.dart` |
| `satisfies_expression` | 1 | `script/bindings.dart`, `script/node_utils.dart`, `template/transforms/const_eval.dart`, `template/transforms/transform_expression.dart` |
| `sequence_expression` | 1 | `script/bindings.dart`, `template/transforms/const_eval.dart` |
| `shorthand_property_identifier` | 36 | `script/destructure_transform.dart`, `template/transforms/expression_walk.dart` |
| `shorthand_property_identifier_pattern` | 43 | `script/bindings.dart`, `script/macro_process.dart`, `script/node_utils.dart`, `template/transforms/expression_walk.dart` |
| `spread_element` | 1 | `script/macro_process.dart`, `script/runtime_decls.dart`, `template/transforms/const_eval.dart` |
| `statement_block` | 140 | `script/await_transform.dart`, `script/destructure_transform.dart`, `script/options_bindings.dart`, `template/transforms/expression_walk.dart` |
| `string` | 278 | `script/bindings.dart`, `script/macro_process.dart`, `script/node_utils.dart`, `script/options_bindings.dart`, `script/runtime_decls.dart`, `script/script_compile.dart`, `script/type_infer.dart`, `template/transforms/const_eval.dart` |
| `string_fragment` | 281 | `script/macro_process.dart`, `script/options_bindings.dart`, `script/runtime_decls.dart`, `script/script_compile.dart` |
| `subscript_expression` | 9 | `template/transforms/expression_walk.dart`, `template/transforms/transform_expression.dart` |
| `switch_body` | 3 | `template/transforms/expression_walk.dart` |
| `switch_case` | 3 | `template/transforms/expression_walk.dart` |
| `switch_statement` | 3 | `template/transforms/expression_walk.dart` |
| `template_string` | 10 | `script/bindings.dart`, `script/node_utils.dart`, `template/transforms/const_eval.dart` |
| `template_substitution` | 13 | `script/bindings.dart`, `template/transforms/const_eval.dart` |
| `ternary_expression` | 3 | `script/bindings.dart`, `template/transforms/const_eval.dart` |
| `this` | 2 | `template/transforms/transform_expression.dart` |
| `throw_statement` | 3 | —（仅出现在子树中） |
| `true` | 19 | `script/binding_metadata.dart`, `script/bindings.dart`, `script/node_utils.dart`, `script/type_infer.dart`, `template/transforms/build_props.dart`, `template/transforms/const_eval.dart`, `template/transforms/slot_outlet.dart`, `template/transforms/transform_expression.dart`, `template/transforms/v_if.dart` |
| `try_statement` | 5 | —（仅出现在子树中） |
| `type_alias_declaration` | 6 | `script/destructure_transform.dart`, `script/script_compile.dart`, `script/type_infer.dart` |
| `type_annotation` | 83 | `script/bindings.dart`, `script/destructure_transform.dart`, `script/runtime_decls.dart`, `script/script_compile.dart`, `script/type_infer.dart`, `template/transforms/expression_walk.dart` |
| `type_arguments` | 36 | `script/destructure_transform.dart`, `script/macro_process.dart` |
| `type_identifier` | 32 | `script/bindings.dart`, `script/destructure_transform.dart`, `script/type_infer.dart` |
| `type_parameter` | 2 | —（仅出现在子树中） |
| `type_parameters` | 2 | `script/destructure_transform.dart`, `script/type_infer.dart` |
| `undefined` | 1 | `script/type_infer.dart`, `template/transforms/build_slots.dart`, `template/transforms/const_eval.dart`, `template/transforms/expression_walk.dart`, `template/transforms/slot_outlet.dart`, `template/transforms/transform_expression.dart` |
| `union_type` | 9 | `script/type_infer.dart`, `template/transforms/expression_walk.dart` |
| `update_expression` | 28 | `script/bindings.dart`, `script/destructure_transform.dart`, `template/transforms/transform_expression.dart` |
| `variable_declaration` | 2 | `script/bindings.dart`, `script/destructure_transform.dart`, `script/script_compile.dart`, `template/transforms/expression_walk.dart` |
| `variable_declarator` | 205 | `script/bindings.dart`, `script/destructure_transform.dart`, `script/script_compile.dart`, `template/transforms/expression_walk.dart` |
