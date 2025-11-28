import 'dart:convert';
import 'package:vue_sfc_parser/ast.dart';
import 'package:vue_sfc_parser/sfc_compiler.dart';
import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/parse_script.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';
// merged: swc_ast types are now provided by ast

/// Compile `<script setup>` to final output, preserving exact TypeScript parity.
String compileScript(SfcDescriptor descriptor) {
  if (descriptor.scriptSetup == null && descriptor.script != null) {
    final script = descriptor.script!;
    final language = descriptor.scriptSetup?.lang ?? 'js';
    final normalParse = parseScript(
      script.content,
      language: language,
      filename: descriptor.filename,
    );
    final unit = normalParse.unit;
    final defaults = unit.exported.whereType<ExportDefaultDeclaration>().length;
    if (defaults > 1) {
      throw StateError('multiple export default');
    }
    return script.content.trim();
  }
  final language = descriptor.scriptSetup!.lang ?? 'js';
  final normalUnit = _parseNormalIfPresent(descriptor, language);

  final setupParse = parseScript(
    descriptor.scriptSetup!.content,
    language: language,
    filename: descriptor.filename,
  );

  final prepared = Prepared(
    setup: setupParse.unit,
    normal: normalUnit,
    filename: descriptor.filename,
    language: language,
  );
  return ScriptCodegen.generate(prepared: prepared);
}

CompilationUnit? _parseNormalIfPresent(
  SfcDescriptor descriptor,
  String language,
) {
  final script = descriptor.script;
  if (script == null) return null;
  return parseScript(
    script.content,
    language: language,
    filename: descriptor.filename,
  ).unit;
}

String getSlice(String src, int startByte, int endByte) {
  final bytes = utf8.encode(src);
  final safeStart = startByte.clamp(0, bytes.length);
  final safeEnd = endByte.clamp(0, bytes.length);
  if (safeEnd <= safeStart) return '';
  return utf8.decode(bytes.sublist(safeStart, safeEnd));
}
