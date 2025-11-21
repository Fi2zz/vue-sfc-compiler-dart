import 'dart:convert';
import 'package:vue_sfc_parser/sfc_ast.dart';
import 'package:vue_sfc_parser/sfc_compiler.dart';
import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/sfc_script_parse.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';
import 'package:vue_sfc_parser/swc_ast.dart';
import 'package:vue_sfc_parser/validate_normal_script_exports.dart';

String compileScript(SfcDescriptor descriptor) {
  if (descriptor.scriptSetup == null && descriptor.script != null) {
    //  if only normal <script> exists, return its content as-is
    if (descriptor.script != null) {
      // validate normal script for multiple export default occurrences
      validateNormalScriptExports(
        descriptor.script!.content,
        descriptor.script!.lang ?? 'js',
        filename: descriptor.filename,
        sfcSource: descriptor.source,
        scriptStartOffset: descriptor.script!.locStart,
      );
      return descriptor.script!.content.trim();
    }
  }

  // If <script setup> exists, compile it into runtime code
  // if (descriptor.scriptSetup != null) {

  final source = descriptor.scriptSetup!.content;
  final language = descriptor.scriptSetup!.lang ?? 'js';
  // When a normal <script> also exists, parse it into AST (no pre-scan)
  final script = descriptor.script;
  CompilationUnit? normal;
  if (script != null) {
    String code = script.content;
    validateNormalScriptExports(
      code,
      language,
      filename: descriptor.filename,
      sfcSource: descriptor.source,
      scriptStartOffset: script.locStart,
    );
    final m = sfcParseScript(
      code,
      language: language,
      isScriptSetup: false,
      filename: descriptor.filename,
    );
    normal = m.unit;
  }
  final setup = sfcParseScript(
    source,
    language: language,
    isScriptSetup: true,
    filename: descriptor.filename,
  );
  final result = Prepared(
    setup: setup.unit,
    normal: normal,
    source: source,
    filename: descriptor.filename,
    language: language,
  );
  return ScriptCodegen.generate(prepared: result);
}

String getSlice(String src, int startByte, int endByte) {
  final bytes = utf8.encode(src);
  final safeStart = startByte.clamp(0, bytes.length);
  final safeEnd = endByte.clamp(0, bytes.length);
  if (safeEnd <= safeStart) return '';
  return utf8.decode(bytes.sublist(safeStart, safeEnd));
}
