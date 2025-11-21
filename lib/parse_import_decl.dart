import 'package:vue_sfc_parser/sfc_ast.dart';

ImportDeclaration parseImportDecl(String line, int start, int end) {
  final text = line.trim();
  int i = 'import'.length; // after 'import'
  String? importKind;
  List<Object> specifiers = [];
  Identifier readIdent() {
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
    final name = text.substring(i, j);
    i = j;
    return Identifier(name: name);
  }

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
  // side-effect import: import "module";
  if (i < text.length &&
      (text.codeUnitAt(i) == 34 || text.codeUnitAt(i) == 39)) {
    final quote = text[i];
    int j = i + 1;
    while (j < text.length && text[j] != quote) {
      j++;
    }
    if (j >= text.length) {
      throw StateError('Invalid ImportDeclaration: unterminated source');
    }
    final srcVal = text.substring(i + 1, j);
    return ImportDeclaration(
      specifiers: const [],
      source: StringLiteral(stringValue: srcVal),
      importKind: importKind,
    );
  }
  if (text.startsWith('import type')) {
    importKind = 'type';
    i = 'import type'.length;
    skipWs();
  }
  if (i < text.length && text.codeUnitAt(i) == 123) {
    i++;
    int guard = 0;
    while (i < text.length && text.codeUnitAt(i) != 125) {
      skipWs();
      final imported = readIdent();
      if (imported.name.isEmpty) {
        throw StateError('Invalid ImportDeclaration: empty imported name');
      }
      Identifier local = imported;
      skipWs();
      if (text.startsWith('as ', i)) {
        i += 3;
        skipWs();
        final alias = readIdent();
        if (alias.name.isEmpty) {
          throw StateError('Invalid ImportDeclaration: empty alias name');
        }
        local = alias;
      }
      specifiers.add(
        ImportSpecifier(
          local: local,
          imported: imported,
          importKind: importKind,
        ),
      );
      skipWs();
      if (i < text.length && text.codeUnitAt(i) == 44) {
        i++;
      } else if (i < text.length && text.codeUnitAt(i) == 125) {
        break;
      } else {
        throw StateError('Invalid ImportDeclaration: expected "," or "}"');
      }
      guard++;
      if (guard > text.length) {
        throw StateError('Invalid ImportDeclaration: overflow');
      }
    }
    if (i < text.length && text.codeUnitAt(i) == 125) i++;
  } else if (i < text.length && text.codeUnitAt(i) == 42) {
    i++;
    skipWs();
    if (text.startsWith('as ', i)) {
      i += 3;
      skipWs();
      final ns = readIdent();
      if (ns.name.isEmpty) {
        throw StateError('Invalid ImportDeclaration: empty namespace');
      }
      specifiers.add(ImportNamespaceSpecifier(local: ns));
    } else {
      throw StateError('Invalid ImportDeclaration: expected "as" after *');
    }
  } else {
    final def = readIdent();
    if (def.name.isEmpty) {
      throw StateError('Invalid ImportDeclaration: empty default');
    }
    specifiers.add(ImportDefaultSpecifier(local: def));
    skipWs();
    if (i < text.length && text.codeUnitAt(i) == 44) {
      i++;
      skipWs();
      if (i < text.length && text.codeUnitAt(i) == 123) {
        i++;
        int guard = 0;
        while (i < text.length && text.codeUnitAt(i) != 125) {
          skipWs();
          final imported = readIdent();
          if (imported.name.isEmpty) {
            throw StateError('Invalid ImportDeclaration: empty imported');
          }
          Identifier local = imported;
          skipWs();
          if (text.startsWith('as ', i)) {
            i += 3;
            skipWs();
            final alias = readIdent();
            if (alias.name.isEmpty) {
              throw StateError('Invalid ImportDeclaration: empty alias');
            }
            local = alias;
          }
          specifiers.add(
            ImportSpecifier(
              local: local,
              imported: imported,
              importKind: importKind,
            ),
          );
          skipWs();
          if (i < text.length && text.codeUnitAt(i) == 44) {
            i++;
          } else if (i < text.length && text.codeUnitAt(i) == 125) {
            break;
          } else {
            throw StateError('Invalid ImportDeclaration: expected "," or "}"');
          }
          guard++;
          if (guard > text.length) {
            throw StateError('Invalid ImportDeclaration: overflow');
          }
        }
        if (i < text.length && text.codeUnitAt(i) == 125) i++;
      }
    }
  }
  final fromIdx = text.indexOf(' from ', i);
  if (fromIdx < 0) throw StateError('Invalid ImportDeclaration: missing from');
  int q = text.indexOf('"', fromIdx);
  if (q < 0) q = text.indexOf("'", fromIdx);
  if (q < 0) throw StateError('Invalid ImportDeclaration: missing source');
  int q2 = text.indexOf(text[q], q + 1);
  if (q2 < 0) {
    throw StateError('Invalid ImportDeclaration: unterminated source');
  }
  final src = text.substring(q + 1, q2);
  return ImportDeclaration(
    specifiers: specifiers,
    source: StringLiteral(stringValue: src),
    importKind: importKind,
  );
}
