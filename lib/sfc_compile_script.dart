import 'dart:convert';
import 'package:vue_sfc_parser/sfc_compiler.dart';
import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/sfc_macro.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';
import 'package:vue_sfc_parser/ts_parser.dart';
import 'package:vue_sfc_parser/sfc_error.dart';

String compileScript(SfcDescriptor descriptor) {
  // If <script setup> exists, compile it into runtime code
  if (descriptor.scriptSetup != null) {
    final source = descriptor.scriptSetup!.content;
    final language = descriptor.scriptSetup!.lang ?? 'js';
    final compilation = MacrosParser.parse(source, language: language);
    // When a normal <script> also exists, parse its default export object and merge
    String? normalSpread;
    List<String>? normalImports;
    final script = descriptor.script;
    if (script != null) {
      String code = script.content;
      _validateNormalScriptExports(
        code,
        language,
        filename: descriptor.filename,
        sfcSource: descriptor.source,
        scriptStartOffset: script.locStart,
      );
      final parser = TSParser();
      final AstNode root = parser.parse(
        code: code,
        language: language,
        namedOnly: false,
      );
      normalSpread = _walkNormalScriptExportDefault(root, code);
      normalImports = _walkImports(root, code);
    }
    // collect setup import lines directly from source (support multi-line imports)
    final setupImports = _collectSetupImports(source, compilation.rootAst);
    final setup = SetupResult(
      compilation: compilation.compilationUnit,
      rootAst: compilation.rootAst,
      source: source,
      filename: descriptor.filename,
      normalScriptSpreadText: normalSpread,
      normalScriptImportLines: normalImports,
      setupImportLines: setupImports,
    );
    return ScriptCodegen.generate(setup: setup);
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
    return descriptor.script!.content.trim();
  }

  // No <script> blocks
  return '';
}

// todo 使用 ast，而不是正则匹配
List<String> _collectSetupImports(String src, AstNode root) {
  final out = <String>[];
  // final parser = TSParser();
  // final AstNode root = parser.parse(code: src, language: 'ts', namedOnly: false);
  void walk(AstNode n) {
    if (n.type == 'import_declaration') {
      final text = _slice(src, n.startByte, n.endByte);
      out.add(_fmtImportLine(text));
      return;
    }
    for (final c in n.children) {
      walk(c);
    }
  }

  walk(root);
  return out;
}

String scriptCodeGenerate({required SetupResult result}) =>
    ScriptCodegen.generate(setup: result);

AstNode? _findChildByType(AstNode n, String type) {
  for (final c in n.children) {
    if (c.type == type) return c;
    final r = _findChildByType(c, type);
    if (r != null) return r;
  }
  return null;
}

String? _walkNormalScriptExportDefault(AstNode root, String content) {
  String? objText;
  void walk(AstNode n) {
    // Find `export default { ... }`
    if (n.type.contains('export')) {
      final text = _slice(content, n.startByte, n.endByte);
      // todo 改成 ast 模式，而不是字符串匹配
      if (RegExp(r'export\s+default').hasMatch(text)) {
        final obj = _findChildByType(n, 'object');
        if (obj != null) {
          objText = _slice(content, obj.startByte, obj.endByte).trim();
          return;
        }
      }
    }
    for (final c in n.children) {
      if (objText != null) return;
      walk(c);
    }
  }

  walk(root);
  return objText;
}

// todo 使用 ast，而不是正则匹配
List<String> _walkImports(AstNode root, String content) {
  final out = <String>[];
  void walk(AstNode n) {
    if (n.type == 'import_declaration') {
      final text = _slice(content, n.startByte, n.endByte);
      out.add(_fmtImportLine(text));
      return;
    }
    for (final c in n.children) {
      walk(c);
    }
  }

  walk(root);
  return out;
}

void _validateNormalScriptExports(
  String content,
  String language, {
  required String filename,
  String? sfcSource,
  int? scriptStartOffset,
}) {
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
    final absEnd = baseOffset + loc[1];
    final frame = _renderCodeFrame(sfcSource ?? content, absStart, absEnd);
    final fullBefore = (sfcSource ?? content).substring(0, absStart);
    final lineNum = '\n'.allMatches(fullBefore).length + 1;
    final lastNl = fullBefore.lastIndexOf('\n');
    final colNum = lastNl == -1 ? 0 : fullBefore.length - lastNl - 1;
    throw SfcCompileError(
      filename: filename,
      reason: 'Only one default export allowed per module. ($lineNum:$colNum)',
      line1: frame[0],
      caret1: frame[1],
      line2: frame[2],
      caret2: frame[3],
      line3: frame[4],
      locStart: absStart,
      locEnd: absEnd,
    );
  }
}

List<String> _renderCodeFrame(String src, int start, int end) {
  int lineStartIdx = src.lastIndexOf('\n', start - 1);
  if (lineStartIdx == -1) {
    lineStartIdx = 0;
  } else {
    lineStartIdx += 1;
  }
  int lineEndIdx = src.indexOf('\n', end);
  if (lineEndIdx == -1) lineEndIdx = src.length;

  int prevStartIdx = src.lastIndexOf('\n', lineStartIdx - 2);
  if (prevStartIdx == -1) {
    prevStartIdx = 0;
  } else {
    prevStartIdx += 1;
  }
  int prevEndIdx = src.indexOf('\n', prevStartIdx);
  if (prevEndIdx == -1) prevEndIdx = src.length;

  int nextStartIdx = lineEndIdx + 1;
  int nextEndIdx = src.indexOf('\n', nextStartIdx);
  if (nextEndIdx == -1) nextEndIdx = src.length;

  final before = src.substring(0, lineStartIdx);
  final currLineNum = '\n'.allMatches(before).length + 1;
  final prevLineNum = currLineNum - 1;
  final nextLineNum = currLineNum + 1;

  final prevLine = src.substring(prevStartIdx, prevEndIdx);
  final currLine = src.substring(lineStartIdx, lineEndIdx);
  final nextLine = src.substring(nextStartIdx, nextEndIdx);

  final caretStartCol = start - lineStartIdx;
  final caret = '|  ' + ' ' * caretStartCol + '^';

  final l1 = '$prevLineNum  |  ${prevLine.trimRight()}';
  final c1 = '|  ';
  final l2 = '$currLineNum  |  ${currLine.trimRight()}';
  final c2 = caret;
  final l3 = '$nextLineNum  |  ${nextLine.trimRight()}';
  return [l1, c1, l2, c2, l3];
}

String _slice(String src, int startByte, int endByte) {
  final bytes = utf8.encode(src);
  final safeStart = startByte.clamp(0, bytes.length);
  final safeEnd = endByte.clamp(0, bytes.length);
  if (safeEnd <= safeStart) return '';
  return utf8.decode(bytes.sublist(safeStart, safeEnd));
}

String _fmtImportLine(String line) {
  var t = line.trimRight();
  if (!t.endsWith(';')) t = '$t;';
  t = t.replaceAll("'", '"');
  return t;
}
