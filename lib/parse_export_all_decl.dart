import 'package:vue_sfc_parser/sfc_ast.dart';

ExportAllDeclaration parseExportAllDecl(String line, int start, int end) {
  final text = line.trim();
  final fromIdx = text.indexOf(' from ');
  if (fromIdx < 0) throw StateError('Invalid ExportAllDeclaration');
  int q = text.indexOf('"', fromIdx);
  if (q < 0) q = text.indexOf("'", fromIdx);
  if (q < 0) throw StateError('Invalid ExportAllDeclaration: missing source');
  final q2 = text.indexOf(text[q], q + 1);
  if (q2 < 0) {
    throw StateError('Invalid ExportAllDeclaration: unterminated source');
  }
  final src = text.substring(q + 1, q2);
  return ExportAllDeclaration(source: StringLiteral(stringValue: src));
}
