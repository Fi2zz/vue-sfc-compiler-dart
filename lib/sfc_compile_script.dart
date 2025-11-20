import 'dart:convert';

import 'package:vue_sfc_parser/sfc_compiler.dart';
import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/sfc_macro.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';
import 'package:vue_sfc_parser/swc_ast.dart';
import 'package:vue_sfc_parser/validate_normal_script_exports.dart';

String compileScript(SfcDescriptor descriptor) {
  // If <script setup> exists, compile it into runtime code
  if (descriptor.scriptSetup != null) {
    final source = descriptor.scriptSetup!.content;
    final language = descriptor.scriptSetup!.lang ?? 'js';

    // When a normal <script> also exists, parse its default export object and merge
    String? normalSpread;
    List<String>? normalImports;
    final script = descriptor.script;
    if (script != null) {
      String code = script.content;
      validateNormalScriptExports(
        code,
        language,
        filename: descriptor.filename,
        sfcSource: descriptor.source,
        scriptStartOffset: script.locStart,
      );
      final m = Parser.parse(code, language: language);
      normalSpread = walkNormalScriptExportDefault(m.rootModule, code);
      normalImports = walkImports(m.rootModule, code);
    }

    final compilation = Parser.parse(source, language: language);
    final setupImports = walkImports(compilation.rootModule, source);

    final setup = SetupResult(
      compilation: compilation.compilationUnit,
      rootModule: compilation.rootModule,
      source: source,
      filename: descriptor.filename,
      normalScriptSpreadText: normalSpread,
      normalScriptImportLines: normalImports,
      setupImportLines: setupImports,
      language: language,
    );
    return ScriptCodegen.generate(setup: setup);
  }
  // Fallback: if only normal <script> exists, return its content as-is
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

  // No <script> blocks
  return '';
}

String? walkNormalScriptExportDefault(Module root, String content) {
  for (final item in root.body) {
    if (item is ExportDefaultExpr) {
      if (item.objSpan != null) {
        final t = getSlice(
          content,
          item.objSpan!.start,
          item.objSpan!.end,
        ).trim();
        return t;
      }
    }
  }
  return null;
}

List<String> walkImports(Module root, String content) {
  final out = <String>[];
  for (final item in root.body) {
    if (item is ImportDecl) {
      print(item.node.start);
      final text = getSlice(content, item.node.start, item.node.end);
      out.add(formatImportLine(text));
    }
  }
  return out;
}

String getSlice(String src, int startByte, int endByte) {
  final bytes = utf8.encode(src);
  final safeStart = startByte.clamp(0, bytes.length);
  final safeEnd = endByte.clamp(0, bytes.length);
  if (safeEnd <= safeStart) return '';
  return utf8.decode(bytes.sublist(safeStart, safeEnd));
}

String formatImportLine(String line) {
  var t = line.trimRight();
  if (!t.endsWith(';')) t = '$t;';
  t = t.replaceAll("'", '"');
  return t;
}
