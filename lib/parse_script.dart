// import 'dart:convert';
import 'package:vue_sfc_parser/program_to_compilation_unit.dart';

import 'ast.dart';
import 'swc_parser.dart';

class ParseResult {
  final CompilationUnit unit;
  final Program program;
  ParseResult(this.unit, this.program);
}

/// Parse script content into Program and CompilationUnit with export validation.
ParseResult parseScript(
  String content, {
  required String language,
  String? filename,
}) {
  final program = _parseProgram(content, language);
  final unit = programToCompilationUnit(program, content, filename: filename);
  return ParseResult(unit, program);
}

Program _parseProgram(String content, String language) {
  final sp = SwcParser();
  return sp.parse(code: content, language: language);
}
