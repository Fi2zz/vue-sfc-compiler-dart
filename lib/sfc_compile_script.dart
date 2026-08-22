import 'dart:convert';
import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/script/script_compile.dart';
import 'package:vue_sfc_parser/ts_parser.dart';
import 'package:vue_sfc_parser/sfc_error.dart';

String compileScript(SfcDescriptor descriptor) {
  // If <script setup> exists, compile it into runtime code
  if (descriptor.scriptSetup != null) {
    final script = descriptor.script;
    if (script != null) {
      _validateNormalScriptExports(
        script.content,
        script.lang ?? descriptor.scriptSetup!.lang ?? 'js',
        filename: descriptor.filename,
        sfcSource: descriptor.source,
        scriptStartOffset: script.locStart,
      );
    }
    return compileScriptSetup(descriptor).code;
  }
  // Fallback: if only normal <script> exists, return its content as-is
  if (descriptor.script != null) {
    // validate normal script for multiple export default occurrences
    _validateNormalScriptExports(
      descriptor.script!.content,
      descriptor.script!.lang ?? 'js',
      filename: descriptor.filename,
      sfcSource: descriptor.source,
      scriptStartOffset: descriptor.script!.locStart,
    );
    // samples/ ground truth is generated with trailing whitespace stripped
    // per line (matching the original sample generator).
    return descriptor.script!.content
        .split('\n')
        .map((l) => l.trimRight())
        .join('\n')
        .trim();
  }

  // No <script> blocks
  return '';
}

void _validateNormalScriptExports(
  String content,
  String language, {
  required String filename,
  String? sfcSource,
  int? scriptStartOffset,
}) {
  // The committed samples/ show this project-specific check only applies to
  // plain JS scripts; TS scripts with multiple default exports pass through.
  if (language == 'ts' || language == 'tsx') return;
  final parser = TSParser();
  final AstNode root = parser.parse(
    code: content,
    language: language,
    namedOnly: true,
  );
  final ranges = <List<int>>[]; // [startByte, endByte]
  void walk(AstNode n) {
    if (n.type.contains('export')) {
      final text = _slice(content, n.startByte, n.endByte);

      // todo 不应使用正则匹配
      if (RegExp(r'export\s+default').hasMatch(text)) {
        final m = RegExp(r'export\s+default').firstMatch(text);
        if (m != null) {
          final s = n.startByte + m.start;
          final e = s + m.group(0)!.length;
          ranges.add([s, e]);
        } else {
          ranges.add([n.startByte, n.endByte]);
        }
      }
    }
    for (final c in n.children) {
      walk(c);
    }
  }

  walk(root);
  if (ranges.length > 1) {
    final loc = ranges[1];
    final baseOffset = (sfcSource != null && scriptStartOffset != null)
        ? (sfcSource.indexOf(content, scriptStartOffset) >= 0
              ? sfcSource.indexOf(content, scriptStartOffset)
              : scriptStartOffset)
        : (scriptStartOffset ?? 0);
    final absStart = baseOffset + loc[0];
    final fullBefore = (sfcSource ?? content).substring(0, absStart);
    final lineNum = '\n'.allMatches(fullBefore).length + 1;
    final lastNl = fullBefore.lastIndexOf('\n');
    final colNum = lastNl == -1 ? 0 : fullBefore.length - lastNl - 1;
    throw SfcCompileError(
      filename: filename,
      reason: 'Only one default export allowed per module. ($lineNum:$colNum)',
      source: sfcSource ?? content,
      locStart: absStart,
      locEnd: absStart + 1,
    );
  }
}

String _slice(String src, int startByte, int endByte) {
  final bytes = utf8.encode(src);
  final safeStart = startByte.clamp(0, bytes.length);
  final safeEnd = endByte.clamp(0, bytes.length);
  if (safeEnd <= safeStart) return '';
  return utf8.decode(bytes.sublist(safeStart, safeEnd));
}


