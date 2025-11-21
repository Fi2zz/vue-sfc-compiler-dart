import 'package:vue_sfc_parser/sfc_ast.dart';

ExportNamedDeclaration parseExportNamedDecl(String line, int start, int end) {
  final text = line.trim();
  int i = 'export'.length;
  void skipWs() {
    while (i < text.length) {
      final c = text.codeUnitAt(i);
      if (c == 32 || c == 9) {
        i++;
      } else {
        break;
      }
    }
  }

  skipWs();
  if (i >= text.length || text.codeUnitAt(i) != 123) {
    throw StateError('Invalid ExportNamedDeclaration');
  }
  i++;
  final specs = <Object>[];
  while (i < text.length && text.codeUnitAt(i) != 125) {
    skipWs();
    int j = i;
    while (j < text.length) {
      final c = text.codeUnitAt(j);
      final ok =
          (c >= 65 && c <= 90) ||
          (c >= 97 && c <= 122) ||
          (c >= 48 && c <= 57) ||
          c == 95 ||
          c == 36;
      if (!ok) break;
      j++;
    }
    final localName = text.substring(i, j);
    final local = Identifier(name: localName);
    i = j;
    skipWs();
    Object exported = local;
    if (text.startsWith('as ', i)) {
      i += 3;
      skipWs();
      j = i;
      while (j < text.length) {
        final c = text.codeUnitAt(j);
        final ok =
            (c >= 65 && c <= 90) ||
            (c >= 97 && c <= 122) ||
            (c >= 48 && c <= 57) ||
            c == 95 ||
            c == 36;
        if (!ok) break;
        j++;
      }
      final expName = text.substring(i, j);
      exported = Identifier(name: expName);
      i = j;
    }
    specs.add(ExportSpecifier(local: local, exported: exported));
    skipWs();
    if (i < text.length && text.codeUnitAt(i) == 44) i++;
  }
  if (i < text.length && text.codeUnitAt(i) == 125) i++;
  StringLiteral? source;
  final fromIdx = text.indexOf(' from ', i);
  if (fromIdx >= 0) {
    int q = text.indexOf('"', fromIdx);
    if (q < 0) q = text.indexOf("'", fromIdx);
    if (q >= 0) {
      final q2 = text.indexOf(text[q], q + 1);
      if (q2 > q) {
        source = StringLiteral(stringValue: text.substring(q + 1, q2));
      }
    }
  }
  return ExportNamedDeclaration(
    declaration: null,
    specifiers: specs,
    source: source,
  );
}
