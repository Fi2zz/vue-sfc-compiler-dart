import 'package:vue_sfc_parser/parse_simple_expression.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';

ExportDefaultDeclaration parseExportDefaultDecl(
  String line,
  int start,
  int end,
) {
  final text = line.trim();
  final idx = text.indexOf('export default');
  if (idx < 0) throw StateError('Invalid ExportDefaultDeclaration');
  var body = text.substring(idx + 'export default'.length).trim();
  if (body.endsWith(';')) body = body.substring(0, body.length - 1);
  final expr = parseSimpleExpression(body, start, end);
  return ExportDefaultDeclaration(declaration: expr);
}
