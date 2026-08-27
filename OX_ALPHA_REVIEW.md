# ox alpha 提交全面审查报告

- 审查范围：`752b4ea..81692c4`（63 个提交，2026-08-24 ~ 08-26，即 ox alpha 全部产出）
- 审查方式：5 组并行深审（逐 commit 完整 diff + 对照 `node_modules` 内官方 @vue/* 3.5.41 dist 逐条核对 + 双端实测探针 + verifier/batch 独立复跑）
- 审查日期：2026-08-27

## 总体结论

63 个提交的主干质量高：所有提交信息中的对拍声明经独立复跑**全部属实且偏保守**（v1 159/159、v2 115/115、v3 75/75、v4 12/12 EXACT；batch 实测 783/786，优于声明的 772；sourcemap 700/700；dom 对拍 53/53 + 438/438 SAME）。多处官方 quirk 级语义（对象身份匹配、JS 稀疏数组、`||=` falsy 语义、空 staticHelpers 怪癖等）逐条核对无误。Rust/FFI 内存安全（malloc/free 配对、catch_unwind、boxed slice 布局）核验通过。

但存在 **1 个 critical、9 个 major**，集中特征是：**现有 verifier/样例集覆盖不到的场景**——非 ASCII 模板、inline 左值家族、未闭合实体 EOF、TS declare/namespace、错误码数值、ffi/bin 错误路径。门禁全绿对这些场景没有证明力。

## Critical（1）

### C1. concat 默认模式下，非 ASCII 表达式之后的所有表达式 span 错位，生成代码直接损坏

- 引入：56f3692；26d1561 将 concat 设为默认策略
- 位置：`lib/template/transforms/expression_cache.dart:104-135`（`fillExpressionCacheConcat`）
- 问题：单位混用。`cursor`/`len` 是 UTF-16 code unit 索引，`el.startByte`/`endByte` 是 UTF-8 字节偏移。任一靠前表达式含多字节字符（中文字符串/标识符）时，后续所有元素的 rebase delta 偏小，整棵子树 span 右移；`_lineStarts`/`_pointAt` 也按 char 建表，row/column 同样错。
- 实证（HEAD 复现）：模板 `{{ '中' + a }}{{ v0 + 1 }}…{{ v7 + 1 }}`（≥8 表达式触发 concat），默认模式输出 `_toDisplayString(v0_ctx. + 1)`（标识符拼接位置错乱）；`TS_EXPR_BATCH=off` 输出正确的 `_toDisplayString($setup.v0 + 1)`。
- verifier 全绿仅因样例集无"≥8 表达式且靠前含非 ASCII"的组合。
- 修复方向：cursor/len 全程改 UTF-8 字节单位；同时补一条非 ASCII + ≥8 表达式的 v2 门禁样例。在该样例补上之前，这是**当前默认配置下的活跃 bug**，最高优先级。

## Major（9）

### M1. ffi/bin 批量模式吞掉表达式语法错误（error 45 不报告）

- 引入：56f3692；dfd2ecf 后同样适用于 bin
- 位置：`expression_cache.dart:82-86` + `transform_expression.dart:267-268`：缓存命中直接 return，跳过 `_hasErrorNode` 检查与 `context.onError(45)`
- 实证：`{{ a + % }}` + 8 个正常表达式，off/concat 报 error 45，`TS_EXPR_BATCH=ffi` 报错列表为空。PERF_BENCHMARK.md 仍把 ffi 列为可用回退路径，与此行为冲突。

### M2. `JsonEstNode._canonical` 进程级静态 Map 无淘汰，长驻进程内存只涨不降

- 引入：dfd2ecf；位置：`lib/ts_syntax/est_node.dart:38,55-56`
- 每次解析的每个 payload 子 Map 进 static identity map 永不释放。佐证：本区间 bench 数据 tmpl_heavy（5 文件）rss_delta ≈97MB、large ≈708MB。且全仓无任何依赖 wrapper 身份的消费点——只有驻留成本，没有可辨认收益。watch/server 场景是实打实的泄漏。

### M3. inline 复合赋值（`n += 2`）产出非法 JS

- 引入：bfa94d1；位置：`transform_expression.dart:216-234`（`_lvalKind`）
- tree-sitter 中 `+=` 是 `augmented_assignment_expression`，`_lvalKind` 不认，走普通读取分支。实测 `@click="n += 2"` → Dart 输出 `_unref(n) += 2`（函数调用作赋值目标，加载即 SyntaxError）；官方 `_isRef(n) ? n.value += 2 : n += 2`。

### M4. inline 前缀自增（`++n`）操作符被静默丢弃

- 引入：bfa94d1；位置：`transform_expression.dart:197-204` 与 `_opStart`(:239)
- update 分支 opText 固定从参数末尾切，前缀形式切到空串，`++` 彻底丢失：`++n` → `_isRef(n) ? n.value : n`（官方 `_isRef(n) ? ++n.value : ++n`）。另 `_opStart` 存在 byte/char 偏移二次转换隐患，表达式前有多字节字符时切片错位。v4 样例只覆盖后缀 `count++`，故未暴露。

### M5. inline 解构赋值左值未移植 + new 表达式 unref 缺括号

- 引入：98dbb99/bfa94d1；位置：`transform_expression.dart:152-212, 170-175`
- 官方 `isInDestructureAssignment` 分支未移植：`[a] = [1]` → Dart `[_unref(a)] = [1]`（非法 JS），官方原样。
- 官方 `isInNewExpression` 分支未移植：`{{ new C() }}` → Dart `new _unref(C)()`（把 `_unref` 当构造器），官方 `new (_unref(C))()`。

### M6. `const props = defineProps(...)` 绑定 kind 应为 setup-reactive-const

- 引入：0e388a5；位置：`lib/script/bindings.dart:205-208`
- `_isMacroCall` 命中即返回 setupConst；官方对 DEFINE_PROPS 特判 `setup-reactive-const`。模板 codegen 对两 kind 处理相同故不引起代码差异，但 bindingMetadata 是公开输出契约；v4 现有 12 个样例恰好都是无接收者的 defineProps()，未覆盖。一行级修复。

### M7. 解构赋值显式键值不改写 + 带默认值解构多注入 `key: ` 前缀

- 引入：6af6043；位置：`expression_walk.dart:492-507`（入口守卫缺 `pair_pattern`，新增 case 成死分支）、`transform_expression.dart:354-360`（`object_assignment_pattern` 误入 shorthandKey）
- 实测：`({ x: y } = v)` → Dart `({ x: y } = _ctx.v)`（裸 y 运行时解析为全局，语义误编译），官方 `({ x: _ctx.y } = _ctx.v)`；`({ a = b } = v)` → Dart `({ a: _ctx.a = _ctx.b } = _ctx.v)`，官方 `({ _ctx.a = _ctx.b } = _ctx.v)`。

### M8. tokenizer 漏掉官方 EOF 时的 `entityDecoder.end()`，尾部未闭合实体不解码

- 引入：9b56dc8；位置：`lib/template/tokenizer.dart:658-662`（`_finish`）
- 官方 `finish()` 在 InEntity 状态时先调 `entityDecoder.end()`。实测：官方 `a &amp` → `a &`、`a &#65` → `a A`；Dart 原样保留。次生问题：`EntityDecoder.end()` 成死代码，且其 doc 注释的理由与官方行为相反，属误导性注释。触发条件苛刻（未闭合实体恰在输入末尾），但对逐字对齐契约是真实缺口。

### M9. oxc 切换后的三个结构性缺口（一个报告内合并三条）

- **ast_diff/ast_probe 变成自比较，回归门失效**（00e433b）：`TSParser.parse` 内部已是 oxc 链，ast_diff 的 EXACT 恒真（同义反复），而 OXC_REFERENCE.md 的 oxc bump 流程第 3 步把 `ast_diff 449/452` 写成硬性回归门——该门已无任何拦截能力。（区间外 0def5e2 换 golden gate 部分缓解，但 golden 防回归不防漂移。）
- **`TSDeclareFunction`/`TSModuleDeclaration` 登记了但未实现，合法 TS 直接崩溃**（83b6c11）：`oxc_mapper.dart:214-216` 登记进 dispatch 却路由到 `throw UnimplementedError`。实测 `declare function gtag(...): void`、`namespace N {}` 硬崩溃穿透 compileScript。旧 tree-sitter 后端可解析，属迁移回归。
- **tsx 脚本含 JSX 时静默整体降级为未编译透传**（00e433b）：compile 层把 tsx 折叠为 ts（`script_compile.dart:67`），JSX 触发 oxc panic → errorTree → 脚本侧不检查 ERROR → bindings 为空、defineProps 不编译、整块原样透传且不报错。silent wrong output，比崩溃更隐蔽。

## Minor（8）

| # | 引入 | 位置 | 问题 |
|---|---|---|---|
| m1 | ecaa912 等 | `tmpl_error_messages.dart:53-70` 等 6 处 + 2 处测试 | 模板错误码缺官方 45（v-model on const binding），45 起整体偏移 1（cacheHandlers 用 49 应为 50 等）。verifier 只比对 message 不比 code，故静默偏离。文件头注释自称 "extracted verbatim" 与实际不符 |
| m2 | cb898f5 | `type_infer.dart:91-113` | `@vue-ignore` 只覆盖 intersection/union 首成员；单类型情形未按官方返回 `{ props: {} }`（实测 `/* @vue-ignore */ { foo: string }` Dart 仍产出 props 声明） |
| m3 | 373ac82 | `stringify_utils.dart:196-206` 等双份实现 | parseStringStyle 首冒号切分与官方 `split(/:([^]+)/)` 边界不等价：`color:` 官方 `{}` Dart `{color:''}`；`:red` 官方 `{"":"red"}` Dart `{}` |
| m4 | 6f259fd | `sfc_compile_script.dart:23-39` | normal script（无 setup）+ style v-bind 缺 useCssVars 注入（官方有 genNormalScriptCssVarsCode 路径）。功能缺口非回归，但 HANDOFF 未标注边界 |
| m5 | 42beeb3 | `yarn.lock` | Linux 平台二进制条目被替换成 darwin-arm64 而非并存，跨平台 install 可复现性下降 |
| m6 | 9b56dc8 | `tools/gen_entity_decode_data.mjs` | entities 数据来自 4.5.0，但 node_modules 固定为 7.0.1（trie 格式已变），生成脚本原样运行直接失败，数据无法再生成。当前行为无影响 |
| m7 | 83b6c11 | `mapper_stmt.dart:46-52`、`mapper_expr.dart:147-160` | do-while 漏 `extendStatementEnd`（区间少含尾分号）；转义字符串恒产单个 string_fragment（tree-sitter 会拆 escape_sequence）。语料对两者零覆盖，暂未观察到输出影响 |
| m8 | 70b946f | `makefile:84-91`、`oxc_ffi.dart:96-107` | build-worker 与 _candidates 硬编码 `.dylib`，Linux 构建/探测不可用 |

## Info（设计权衡/流程问题，无需立即动作）

- **dfd2ecf 把全仓格式化噪音混入功能提交**：71 文件 +18662 行中绝大多数是纯 dart format 重排（entity_decode_data 重排经 md5 核验无数值变化），功能 diff 被淹没，bisect/回滚粒度变差。
- **文档/注释漂移**：FFI_MIGRATION.md 引用的切换提交 `b6d19aa` 不存在（实为 00e433b）；`ts_parser.dart` 注释提到已被本提交删除的 ts_ffi.dart；oxc_ffi/oxc_mapper 头部"purely additive"迁移期注记已失实；`bin_est_node.dart:213` 有自注 "DEBUG helper" 的无调用方函数；`tools/diff_transport.dart` 有恒 false 死调试分支；`worker/oxc_ts/src/lib.rs` doc 注释停留在 OXB1 旧格式。
- **错误消息前缀双轨**：`sfc_error.dart` 用 `[vue/compiler-sfc]`、`script_error.dart` 用 `[@vue/compiler-sfc]`，且 gen_official.mjs 的 `Vue Compile Error: ` 前缀是项目历史约定而非官方产物——验证的是"与历史 ground truth 一致"。
- **gen_official.mjs 修改参照侧**（7c3a0dd）：给官方 ground truth 加前缀属改参照而非改实现。
- **`namedOnly`/`maxDepth` 已成死参数**（00e433b 后实现完全忽略，仅签名兼容）；**oxc 可恢复 diagnostics 被静默丢弃**（残余风险类：若存在"babel 抛错而 oxc 仅恢复"的表达式，输出会静默偏离）。
- **tools/ 下 `_` 前缀临时探针取舍不一致**：e40d1a4/5cf2ce6 专门清理了两个 `_tmp` 文件，但 `_seg_probe`、`_rss_probe` 等留在仓库。
- **7c3a0dd 的 samples.json 整文件缩进重排**（600+ 行纯格式 churn），掩盖了当次实际新增的回归样例。
- **README 能力矩阵未随 cb898f5 更新**（写 157/114，实际基线 159/115）。
- **AST dump 白名单盲区**：不含 forParseResult/nameLoc，错误路径只输出裸 THROW；目前 438/438 SAME 说明现实风险低。
- **`tmpl_parser.slice` 负数下标语义只对齐 JS 一半**（当前无调用方传负数）；**`_isCallOfName` 会把 tagged template 误判为调用**（极偏门输入，存量问题）。
- **`source_map.dart` toJSON 循环内 `buf.toString()` 为 O(n²)**；sourcemap 起止映射守卫与官方 locStub 对象身份判定有代理差异，可能是 596/700 之外部分差异的来源。

## 已排除的疑似问题（核查后确认无偏差）

- walkDeclaration/canNeverBeRef/isStaticNode 全规则、hoistStatic 默认值语义、cacheStatic 对象身份匹配、_maybeUnblock 返回值传播、enum 字面量判定——与官方逐条一致。
- codegen with-block、_injectSlotKey、vForMemoKeyedNodes 条件、_cached.el 守卫、@vue:* camelize、defineModel template literal、.prop locStub 怪癖、delimiters 构造注入——与官方 3.5.41 一致。
- pointAt 二分与原线性扫描同语义；be6421a SrcView ASCII 快路、26f3a53 缓存键/复位修复核验无回归。
- EntityDecoder 算法本体（determineBranch 三分支、legacy 最长匹配、多码点发射、C1 替换表）与 entities 4.5.0 逐项一致。
- tree-sitter 拆除完整性：无 package:tree_sitter 导入残留。
- Rust FFI：oxc_parse/oxc_free 配对、条目级 catch_unwind 隔离、OXB2 boxed slice 布局一致、异常路径 malloc/free 完整。

## 修复优先级建议

1. **C1**（concat 非 ASCII span 错位）——当前默认配置下的活跃 bug，修单位 + 补门禁样例。
2. **M3/M4/M5/M7**（inline/解构左值家族）——同一源代码区域，建议一起修并各补 v4/v2 样例；产物是非法或误编译 JS。
3. **M1**（ffi/bin 吞 error 45）——修缓存命中路径的错误检查，或在文档中降级 ffi/bin 为实验路径。
4. **M9 前三条**（oxc 切换遗留）——回归门失效需先修（否则后续 oxc bump 无保护）；declare/namespace 崩溃与 tsx 静默透传按需补 mapper 或显式报错。
5. **M8**（EOF 实体解码）——补上 `entityDecoder.end()` 调用与误导性注释。
6. **M2**（JsonEstNode 驻留）——确认无身份依赖后删除该缓存或加淘汰。
7. **M6、m1、m2**——一行级到十行级的官方对齐修复，顺手做。

## 修复收益评估（2026-08-27 补充）

### 性能收益：几乎没有

报告里的问题全是正确性/健壮性缺陷，不是性能缺陷：

- C1 修的是坐标单位，产出从"错"变"对"，速度不变（UTF-8 换算开销在微秒量级，测不出来）。
- M3/M4/M5/M7、M6、M8、m1、m2 都是分支判定修补，对热路径零影响；M1 补的错误检查量级可忽略；M9 只影响之前崩溃/静默透传的输入。
- 两个例外，但都不体现在 benchmark 得分上：
  - **M2（删 `_canonical`）是内存收益不是速度收益**：bench 实测 tmpl_heavy 5 文件 RSS delta ≈97MB、large ≈708MB，相当部分是该 identity map 驻留；删除后长驻场景内存单调增长消失、GC 压力减轻，但单次编译耗时基本不变。注意需先确认无隐藏身份依赖。
  - info 级 `source_map.dart` toJSON 的 O(n²)（循环内 `buf.toString()`）修成状态标记后对大型文件 sourcemap 生成有真实收益，但 sourcemap 默认不开。
- 性能路线在 20e58f6 已收尾（AOT 全六档领先官方，transport 层优化关闭），剩余 headroom 需格式重设计，与本报告的修复无关。

### 健壮性收益：本报告的真正价值，补齐生产可用的最后短板

按影响形态分四档：

1. **消除硬崩溃**（从抛异常到正常编译）：M9 的 `TSDeclareFunction`/`TSModuleDeclaration`（`declare function gtag(...)`、`namespace N {}` 在真实项目不罕见，目前 UnimplementedError 穿透 compileScript）；M7 的解构形态、M8 的 EOF 未闭合实体。
2. **消除静默错误输出**（收益最大的一类——崩溃会被发现，静默错误会流进产物）：C1（非 ASCII 模板在默认配置下产出错乱代码且无任何报错，中文项目几乎必然触发）；M3/M4/M5（`+=`/`++`/解构赋值/`new` 产出非法或语义错误 JS）；M9 的 tsx 静默透传（修复后从 silent wrong output 变 fail loud，是质变）；M1（ffi/bin 吞 error 45）。
3. **长驻稳定性**：M2 修复前 watch/server 模式内存单调增长、越久越接近 OOM；修复后这条路径才能支撑真实开发服务器——行与不行的差别。
4. **错误契约可信度**：m1 错误码偏移修复后 ErrorCodes 成为可依赖的公开契约；M6/M8/m2 让"字节级对齐官方"在边缘场景真正成立。

**总评**：当前状态是主路径（样例覆盖场景）非常稳，但边缘输入的行为是未经验证的开区间——中文模板、TS ambient 声明、inline 左值、watch 长驻，每一个都是真实项目会踩的雷。性能已经达标，健壮性是目前离生产可用最远的短板；本报告的问题全修完后，项目才从"对拍全绿的移植品"变成"可以交给别人用的编译器"。
