# FFI 切换交接 —— tree-sitter → oxc（编译器对齐侧）

> 用途：替换 TS 解析后端时的对齐工作交接。与 HANDOFF.md（总体路线）、
> NODE_SHAPES.md（形状清单）互补；本文只写"上层编译器代码依赖了什么、
> 换库时什么会碎、怎么验收"。
> 基线：2026-08-25，master @ 2495a71，全部提交已备份 bundle。

## 一、当前基线（切换后必须逐项复原）

| 指标 | 数值 |
|---|---|
| v1 compileScript | 157/157 EXACT |
| v2 compileTemplate | 114/114 EXACT |
| v3 compileStyle | 75/75 EXACT |
| v4 inline+bindings | 12/12 EXACT |
| 批量官方语料 | 783/786（剩余 3 个为既定豁免：babel errorRecovery 措辞族） |
| source map 段级 | 700/700 |

## 二、必须保持的契约面

1. **`TSParser().parse(code:, language:)` → `AstNode` 树**
2. **`AstNode` 字段语义**：`type: String`；`startByte/endByte` 为 **UTF-8 字节偏移**
   （相对传入 code）；`children: List<AstNode>` 按源码顺序
3. **`SrcView` 字节切片**：`slice(startByte,endByte)` / `charOf(byte)→UTF-16 char`
   全链路假设输入是字节偏移。oxc 若给 char/UTF-16 偏移，所有转换会静默错位
   （中文注释/emoji 场景必炸，历史上踩过）
4. **错误节点约定**：`type == 'ERROR'` 表示语法错误（见第四节）
5. **`unwrapTSNode` 家族**：`as_expression / satisfies_expression /
   non_null_expression / type_assertion / parenthesized_expression` 的解包链
   （bindings.dart `unwrapForCall`、transform_expression `_unwrapTop`）

### TSParser 调用方清单（换库后逐一冒烟）
- `lib/template/transforms/transform_expression.dart`（表达式改写主路径 +
  isMemberExpressionOf / isFnExpression）
- `lib/script/script_compile.dart`（setup 与 normal script 双树）
- `lib/script/options_bindings.dart`（非 setup 脚本的 bindings 分析）
- `lib/sfc_compile_script.dart`
- `lib/template/transforms/const_eval.dart`(常量折叠求值)

## 三、形状硬编码清单（换库后逐条重验）

### 模板侧 expression_walk.dart（sourcemap 子表达式 + 改写全压在这里）
| 假设 | 用途 |
|---|---|
| `identifier`、`shorthand_property_identifier` 是标识符 | 引用判定/改写 |
| `undefined` 是**专用节点类型**（babel 中为 Identifier，须访问） | compound 拆分；注释尾随文本不滞留 SimpleExpression |
| `true/false/null` **不是**标识符节点（babel Literal，不访问） | 同上，反向 |
| `property_identifier` = 成员属性 & 对象字面量键 | a.b 的 b 产生子表达式；pair/method_definition 首子节点=键须跳过 |
| `shorthand_property_identifier_pattern` 直接挂在 object_pattern 下 | 解构绑定登记 + 非引用子表达式 |
| `pair`：children[0]=key，last=value；`pair_pattern` 同构 | 键跳过、值改写 |
| `assignment_pattern`/`object_assignment_pattern` 首子节点=绑定名 | ({ foo = bar } 的 foo 是局部量、bar 是外层引用 |
| `required_parameter/optional_parameter`：首个模式子节点=绑定，其后=默认值表达式 | 参数作用域；默认值须改写 |
| `member_expression` 末子节点=属性（其余=object） | isReferenced 判定 |
| `type_annotation` 是标识符的**紧邻兄弟节点** | 注解剥离靠 WalkedIdent 区间扩到注解尾（babel Identifier 含注解区间的语义对齐） |
| `formal_parameters > required_parameter` 包装层级；箭头函数单参数可为裸 identifier | 参数收集 |
| for-in/of 头**压平**（无 lexical_declaration 包裹），首个具名子节点即左值 | 循环变量作用域 |
| `switch_body > switch_case/switch_default` 两层下钻 | 块级声明收集 |
| catch 参数三种形态：identifier / 模式 / formal_parameter 包裹 | catch 作用域 |
| TS 类型空间跳过表（type* 前缀 + predefined_type 等 19 种） | 不把类型当引用 |
| `template_string > template_substitution` 结构 | _isStaticNode |

### 脚本侧 bindings.dart（BindingKind 粒度判定）
- `declarationKind`：取声明节点首 named child 前的关键字（let/const/var）
- `variable_declarator`：children.first=id；init 取末子节点且需排除 `type_annotation` 尾缀
- 枚举：`enum_declaration > enum_body > enum_assignment`（成员初始化器取 children.last）
- 函数/类/抽象类声明的名字提取：childOfType('identifier'|'type_identifier')
- `_isStaticNode`：unary/binary/logical/ternary/sequence/template_string/
  string/number/true/false/null
- `_neverRef`：unary/binary/array/object/function/arrow/update/class/**全部
  *Literal 字面量含 template_string**/tagged template（无 call_arguments 且
  末子为 template_string 的 call_expression）/sequence 递归末项

### 其他
- `_spliceChildren` 在**包装后的源串** `(rawExp)=>{}` 上做 char 偏移拼接——
  偏移单位错了这里最先爆
- `hoistStatic` 默认值语义（官方 `!== false && !script`）勿动

## 四、错误恢复行为（影响有限，量化如下）

- **唯一消费点**：transform_expression `_parseExpression` 的 `_hasErrorNode`
  → code 45 + 表达式原文透传（ExpAst.failed）。只依赖布尔信号，不用部分树结构
- 语料触发面：786 例中仅 **3 处**出现 ERROR 节点，全部属于已豁免的 babel
  措辞族（transformExpressions_193/209、cssVars_751）
- **脚本侧完全不检查错误节点**：残缺脚本靠宽容恢复走完声明收集。
  ⚠️ 若 oxc 硬错误时拒绝出树，脚本侧行为会变——FFI 层需保证
  "带错误的完整树"，或补等价降级
- **真正的风险是检测口径差**：校准目标是**官方 babel 的接受/拒绝边界**，
  不是两个解析器互相一致。口径差会新增/消失 ERRORS 行 → 输出字节变化。
  切换后跑非法表达式差分探针（复用 tools/entity_fuzz_* 模式）：
  `|>`、`a(`、未闭合括号、TS 语法混入 js、regex/除号歧义等十几条即可

## 五、切换后回归套件（一条都不能省）

```bash
# 四 verifier
dart run ./vue_dart.dart && npx prettier samples_dart/*.md -w --log-level warn \
  && node verifier/v1/compare.mjs          # 157/157
dart vue_dart_tmpl.dart && node verifier/v2/compare.mjs    # 114/114
dart vue_dart_style.dart && node verifier/v3/compare.mjs   # 75/75
dart vue_dart_inline.dart && node verifier/v4/compare.mjs  # 12/12

# 批量文本（official 侧无需重跑，inputs 未变时）
dart tools/batch_compile.dart batch_inputs.json ../batch_out/dart
node tools/batch_compare.mjs ../batch_out/official ../batch_out/dart   # 783/786

# map 段级（两侧都要重跑——映射对解析器敏感）
node tools/batch_map_official.mjs batch_inputs.json ../batch_out/maps_official
dart tools/batch_map_dart.dart batch_inputs.json ../batch_out/maps_dart
# 逐文件 diff 两个目录                                                  # 700/700

# 实体/表达式差分探针
node tools/entity_fuzz_official.mjs '<div>&amp;&cups;</div>'
dart run tools/entity_fuzz_dart.dart '<div>&amp;&cups;</div>'

dart analyze                              # 零 error/warning（info 可忽略）
```

## 六、建议的切换顺序

1. 先补全 NODE_SHAPES.md：把第三节清单合并进去（尤其 undefined 专用类型、
   type_annotation 兄弟位、object_assignment_pattern、tagged template）
2. FFI 层先做**字节偏移适配**并单测多字节样例（中文注释 + emoji 夹在
   表达式里），再谈接 oxc
3. 双后端并存期用 ast_diff.dart 全语料对比树的 type/offset 序列，
   归零后再切默认
4. 跑第五节全套；map 700/700 是最灵敏的偏移正确性指标——它过了，
   偏移链路基本就是对的
