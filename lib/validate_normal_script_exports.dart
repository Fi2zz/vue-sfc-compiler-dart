import 'package:vue_sfc_parser/generate_code_frame.dart';
import 'package:vue_sfc_parser/sfc_compile_script.dart';
import 'package:vue_sfc_parser/sfc_error.dart';
import 'package:vue_sfc_parser/swc_ast.dart';
import 'package:vue_sfc_parser/swc_parser.dart';

void validateNormalScriptExports(
  String content,
  String language, {
  required String filename,
  String? sfcSource,
  int? scriptStartOffset,
}) {
  final sp = SwcParser();
  final Module root = sp.parse(code: content, language: language);
  final ranges = <List<int>>[]; // [startByte, endByte]
  for (final item in root.body) {
    if (item is ExportDefaultExpr || item is ExportDefaultDecl) {
      final span = item is ExportDefaultExpr
          ? item.node
          : (item as ExportDefaultDecl).node;
      final text = getSlice(content, span.start, span.end);
      final m = RegExp(r'export\s+default').firstMatch(text);
      if (m != null) {
        final s = span.start + m.start;
        final e = s + m.group(0)!.length;
        ranges.add([s, e]);
      } else {
        ranges.add([span.start, span.end]);
      }
    }
  }
  if (ranges.length > 1) {
    final loc = ranges[1];
    final baseOffset = (sfcSource != null && scriptStartOffset != null)
        ? (sfcSource.indexOf(content, scriptStartOffset) >= 0
              ? sfcSource.indexOf(content, scriptStartOffset)
              : scriptStartOffset)
        : (scriptStartOffset ?? 0);
    final absStart = baseOffset + loc[0];
    final absEnd = baseOffset + loc[1];
    final frame = generateCodeFrame(sfcSource ?? content, absStart, absEnd);
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
