// import 'dart:convert';
import 'package:vue_sfc_parser/sfc_module_to_compilation_unit.dart';

import 'sfc_ast.dart';
import 'swc_parser.dart';
import 'swc_ast.dart';

class ScriptParseResult {
  final CompilationUnit unit;
  final Module module;
  ScriptParseResult(this.unit, this.module);
}

ScriptParseResult sfcParseScript(
  String content, {
  required String language,
  bool isScriptSetup = false,
  String? filename,
}) {
  final sp = SwcParser();
  final Module module = sp.parse(code: content, language: language);
  final unit = swcModuleToCompilationUnit(
    module,
    content,
    isScriptSetup: isScriptSetup,
    filename: filename,
  );
  return ScriptParseResult(unit, module);
}
