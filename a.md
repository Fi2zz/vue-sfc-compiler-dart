AST 测试结果记录

目标

- 基于 `lib/parse_script.dart`、`lib/code_printer.dart`、`lib/ast.dart`，构建覆盖解析与打印的测试，要求打印结果与输入源码严格等值。

变更内容

- 新增测试文件：
  - `test/parse_program_roundtrip_test.dart`
  - `test/code_printer_nodes_test.dart`
  - `test/ast_classes_construction_test.dart`
- 端到端与节点级测试均按精确字符串比对进行校验，未使用正则。

关键行为与断言

- 打印回退：当节点存在 `text` 时，`CodePrinter`直接回退使用 `text`（`lib/code_printer.dart:408`）。
- 顶层导入/导出：为确保与输入严格等值，打印时仅输出 `CompilationUnit.imported/exported` 内容，避免重复（测试中通过重建 `CompilationUnit` 进行验证）。
- `Identifier(text)`：当 `name` 为空且提供 `text` 时，打印为末端标识符（例如 `some.token` → `token`），源于 `extractIdentifierName`（`lib/ast.dart:198`）。
- 典型用例等值：
  - 导入：`import Default, { A, B as C } from "mod";`、`import * as NS from "ns_mod";`、`import { X, Y as Z } from "pkg";`
  - 导出：`export { A, B as C };`、`export * as NS from "mod";`、`export * from "all";`、`export default null`
  - 变量与调用：`const x = 1;`、`doWork({ opt: 1 }, "x", 2);`
  - 注释与源映射：`printCompilationUnitWithSourceMap` 返回的映射区间数量与顺序合理（`lib/code_printer.dart:72`）。

测试运行

- 命令：`dart test -r compact`
- 当前结果：All tests passed。

参考位置

- 解析入口：`lib/parse_script.dart:13`
- 打印编译单元：`lib/code_printer.dart:16`
- 打印程序：`lib/code_printer.dart:99`
- 文本回退打印：`lib/code_printer.dart:408`
- SWC 解析器入口：`lib/swc_parser.dart:42`

后续建议

- 如需在生产路径中直接实现“导入/导出不重复”的等值打印，可在构建 `CompilationUnit` 时去除对应 `statements` 中的模块声明。
- 当 `CodePrinter` 增加新的节点分派逻辑时，补充相应的节点级等值测试用例。

CodePrinter 静态化重构记录

- 目标：`class CodePrinter` 改为纯静态 API，无需实例化，外部均通过静态方法调用。
- 主要改动：
  - 公共方法改为静态：`printCompilationUnit`（lib/code_printer.dart:10）、`printCompilationUnitWithSourceMap`（lib/code_printer.dart:62）、`printNode`（lib/code_printer.dart:80）、`print`（lib/code_printer.dart:86）、`printProgram`（lib/code_printer.dart:90）。
  - 私有分派与辅助改为静态并接收状态：`_printNode`（lib/code_printer.dart:139）、`_exprText`（lib/code_printer.dart:104）、`_patternText`（lib/code_printer.dart:128）、`_indentWrite`（lib/code_printer.dart:117）、`_newline`（lib/code_printer.dart:124）、`_endsWithNewline`（lib/code_printer.dart:99）。
  - 新增内部状态结构：`_PrinterState`（lib/code_printer.dart:451），用于管理缓冲与源映射；对外保持无状态静态调用。
  - 统一编译单元输出：新增内部流程函数用于生成代码与映射，`printCompilationUnitWithSourceMap` 与 `printCompilationUnit` 保持一致的生成路径。
- 测试与验证：
  - 所有测试已更新为静态调用，运行 `dart test -r compact` 结果为 All tests passed。
  - 源映射测试恢复计数正确，验证打印与输入的等值要求不变。
- 使用方式示例：
  - `CodePrinter.printCompilationUnit(unit)`
  - `CodePrinter.printNode(node)`
  - `CodePrinter.printProgram(program)`
