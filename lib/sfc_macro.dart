import 'dart:convert';

import 'sfc_ast.dart';
import 'swc_ast.dart';

class ParseResult {
  final CompilationUnit unit;
  final Module module;
  ParseResult(this.unit, this.module);
}


List<MapLiteralEntry> _parseObjectElements(String objText) {
  final out = <MapLiteralEntry>[];
  int depth = 0;
  bool inStr = false;
  String quote = '';
  final parts = <String>[];
  final buf = StringBuffer();
  for (int i = 0; i < objText.length; i++) {
    final ch = objText[i];
    if (inStr) {
      buf.write(ch);
      if (ch == quote) inStr = false;
      continue;
    }
    if (ch == '\'' || ch == '"') {
      inStr = true;
      quote = ch;
      buf.write(ch);
      continue;
    }
    if (ch == '{') {
      depth++;
      buf.write(ch);
      continue;
    }
    if (ch == '}') {
      depth--;
      buf.write(ch);
      continue;
    }
    if (ch == ',' && depth == 1) {
      parts.add(buf.toString());
      buf.clear();
      continue;
    }
    buf.write(ch);
  }
  if (buf.isNotEmpty) parts.add(buf.toString());
  for (var p in parts) {
    final kv = p.trim();
    if (kv.isEmpty || kv == '{' || kv == '}') continue;
    final idx = kv.indexOf(':');
    if (idx <= 0) continue;
    var key = kv.substring(0, idx).trim();
    var val = kv.substring(idx + 1).trim();
    if (key.startsWith("'") && key.endsWith("'")) {
      key = key.substring(1, key.length - 1);
    }
    final vexp = _parseSimpleExpression(val.trim(), 0, 0);
    out.add(
      MapLiteralEntry(
        startByte: 0,
        endByte: 0,
        text: kv,
        keyText: key,
        value: vexp,
      ),
    );
  }
  return out;
}

Expression _parseSimpleExpression(String t, int start, int end) {
  if (t == 'null') {
    return NullLiteral(startByte: start, endByte: end, text: t);
  }
  if (t == 'true' || t == 'false') {
    return BooleanLiteral(
      startByte: start,
      endByte: end,
      text: t,
      value: t == 'true',
    );
  }
  if (t.endsWith('n')) {
    final body = t.substring(0, t.length - 1);
    final n = num.tryParse(body);
    if (n != null) {
      return BigIntLiteral(
        startByte: start,
        endByte: end,
        text: t,
        value: BigInt.parse(body),
      );
    }
  }
  if ((t.isNotEmpty) && (num.tryParse(t) != null)) {
    return NumberLiteral(
      startByte: start,
      endByte: end,
      text: t,
      value: num.parse(t),
    );
  }
  if (t.startsWith('"') || t.startsWith('\'')) {
    final sv = t.length >= 2 ? t.substring(1, t.length - 1) : t;
    return StringLiteral(
      startByte: start,
      endByte: end,
      text: t,
      stringValue: sv,
    );
  }
  if (t.startsWith('{') && t.endsWith('}')) {
    final elements = _parseObjectElements(t);
    return SetOrMapLiteral(
      startByte: start,
      endByte: end,
      text: t,
      elements: elements,
    );
  }
  if (t.startsWith('[') && t.endsWith(']')) {
    return ListLiteral(
      startByte: start,
      endByte: end,
      text: t,
      elements: const [],
    );
  }
  return Identifier(startByte: start, endByte: end, text: t);
}

List<PropSignature> _extractTypePropsFromSwc(
  List<String>? typeArgs,
  Map<String, List<PropSignature>> alias,
) {
  final out = <PropSignature>[];
  if (typeArgs == null || typeArgs.isEmpty) return out;
  final raw = typeArgs.first.trim();
  if (_isSimpleIdentifier(raw)) {
    final props = alias[raw];
    if (props != null) out.addAll(props);
    return out;
  }
  final body = _outerBracesBody(raw);
  if (body == null) return out;
  out.addAll(_parseTypeLiteralProps(body));
  return out;
}

bool _isSimpleIdentifier(String s) {
  if (s.isEmpty) return false;
  final c0 = s.codeUnitAt(0);
  final isAlpha =
      (c0 >= 65 && c0 <= 90) || (c0 >= 97 && c0 <= 122) || c0 == 95 || c0 == 36;
  if (!isAlpha) return false;
  for (int i = 1; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    final ok =
        (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        (c >= 48 && c <= 57) ||
        c == 95 ||
        c == 36;
    if (!ok) return false;
  }
  return true;
}

String? _outerBracesBody(String s) {
  int start = -1;
  int end = -1;
  int depth = 0;
  for (int i = 0; i < s.length; i++) {
    final ch = s[i];
    if (ch == '{') {
      if (depth == 0) start = i + 1;
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        end = i;
        break;
      }
    }
  }
  if (start >= 0 && end >= start) return s.substring(start, end);
  return null;
}

List<PropSignature> _parseTypeLiteralProps(String body) {
  final out = <PropSignature>[];
  int i = 0;
  while (i < body.length) {
    while (i < body.length && _isWhitespace(body.codeUnitAt(i))) {
      i++;
    }
    if (i >= body.length) break;
    final nameStart = i;
    while (i < body.length && _isIdentChar(body.codeUnitAt(i))) {
      i++;
    }
    final name = body.substring(nameStart, i);
    while (i < body.length && _isWhitespace(body.codeUnitAt(i))) {
      i++;
    }
    bool required = true;
    if (i < body.length && body[i] == '?') {
      required = false;
      i++;
      while (i < body.length && _isWhitespace(body.codeUnitAt(i))) {
        i++;
      }
    }
    if (i >= body.length || body[i] != ':') break;
    i++;
    while (i < body.length && _isWhitespace(body.codeUnitAt(i))) {
      i++;
    }
    final typeStart = i;
    int depthPar = 0, depthBrack = 0, depthAngle = 0;
    bool inStr = false;
    String quote = '';
    while (i < body.length) {
      final ch = body[i];
      if (inStr) {
        if (ch == quote) inStr = false;
        i++;
        continue;
      }
      if (ch == '\'' || ch == '"') {
        inStr = true;
        quote = ch;
        i++;
        continue;
      }
      if (ch == '(') {
        depthPar++;
        i++;
        continue;
      }
      if (ch == ')') {
        depthPar--;
        i++;
        continue;
      }
      if (ch == '[') {
        depthBrack++;
        i++;
        continue;
      }
      if (ch == ']') {
        depthBrack--;
        i++;
        continue;
      }
      if (ch == '<') {
        depthAngle++;
        i++;
        continue;
      }
      if (ch == '>') {
        depthAngle--;
        i++;
        continue;
      }
      if (ch == ';' && depthPar == 0 && depthBrack == 0 && depthAngle == 0) {
        break;
      }
      i++;
    }
    final typeText = body.substring(typeStart, i).trim();
    out.add(PropSignature(name: name, type: typeText, required: required));
    if (i < body.length && body[i] == ';') i++;
  }
  return out;
}

bool _isWhitespace(int c) {
  return c == 32 || c == 9 || c == 10 || c == 13;
}

bool _isIdentChar(int c) {
  return (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      (c >= 48 && c <= 57) ||
      c == 95 ||
      c == 36;
}

String _slice(String src, int startByte, int endByte) {
  final bytes = utf8.encode(src);
  final s = startByte.clamp(0, bytes.length);
  final e = endByte.clamp(0, bytes.length);
  if (e <= s) return '';
  return utf8.decode(bytes.sublist(s, e));
}

String _formatModuleLine(String line) {
  var t = line.trimRight();
  if (!t.endsWith(';')) t = '$t;';
  t = t.replaceAll("'", '"');
  return t;
}

Iterable<String> _collectReExportLines(String src) sync* {
  final bytes = src.codeUnits;
  bool inStr = false;
  int quote = 0;
  bool inLineComment = false;
  bool inBlockComment = false;
  int braceDepth = 0;
  int i = 0;
  while (i < bytes.length) {
    final c = bytes[i];
    if (inLineComment) {
      if (c == 10 || c == 13) inLineComment = false;
      i++;
      continue;
    }
    if (inBlockComment) {
      if (c == 42 && i + 1 < bytes.length && bytes[i + 1] == 47) {
        inBlockComment = false;
        i += 2;
        continue;
      }
      i++;
      continue;
    }
    if (inStr) {
      if (c == quote) {
        inStr = false;
      } else if (c == 92 && i + 1 < bytes.length) {
        i += 2;
        continue;
      }
      i++;
      continue;
    }
    if (c == 47 && i + 1 < bytes.length) {
      if (bytes[i + 1] == 47) {
        inLineComment = true;
        i += 2;
        continue;
      }
      if (bytes[i + 1] == 42) {
        inBlockComment = true;
        i += 2;
        continue;
      }
    }
    if (c == 34 || c == 39) {
      inStr = true;
      quote = c;
      i++;
      continue;
    }
    if (c == 123) {
      braceDepth++;
      i++;
      continue;
    }
    if (c == 125) {
      braceDepth--;
      i++;
      continue;
    }
    if (braceDepth == 0 && _matchKeyword(bytes, i, 'export')) {
      int start = i;
      i += 'export'.length;
      while (i < bytes.length) {
        final d = bytes[i];
        if (d == 32 || d == 9 || d == 10 || d == 13) {
          i++;
        } else {
          break;
        }
      }
      if (i < bytes.length && (bytes[i] == 123 || bytes[i] == 42)) {
        int localBrace = 0;
        while (i < bytes.length) {
          final d = bytes[i];
          if (d == 34 || d == 39) {
            inStr = true;
            quote = d;
            i++;
            while (i < bytes.length) {
              final s = bytes[i];
              if (s == quote) {
                inStr = false;
                i++;
                break;
              }
              if (s == 92) {
                i += 2;
                continue;
              }
              i++;
            }
            continue;
          }
          if (d == 123) {
            localBrace++;
            i++;
            continue;
          }
          if (d == 125) {
            localBrace--;
            i++;
            continue;
          }
          if (d == 59 && localBrace == 0) {
            final raw = String.fromCharCodes(bytes.sublist(start, i + 1));
            final line = _formatModuleLine(raw);
            if (line.contains(' from ')) yield line;
            i++;
            break;
          }
          i++;
        }
        continue;
      }
    }
    i++;
  }
}

bool _matchKeyword(List<int> bytes, int pos, String kw) {
  final k = kw.codeUnits;
  if (pos + k.length > bytes.length) return false;
  for (int i = 0; i < k.length; i++) {
    if (bytes[pos + i] != k[i]) return false;
  }
  return true;
}

bool _isAllowedModuleDecl(Declaration d) {
  return d is ImportDeclaration ||
      d is ExportAllDeclaration ||
      d is ExportNamedDeclaration ||
      d is ExportDefaultDeclaration;
}

ImportDeclaration _parseImportDecl(String line, int start, int end) {
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
  if (q2 < 0)
    throw StateError('Invalid ImportDeclaration: unterminated source');
  final src = text.substring(q + 1, q2);
  return ImportDeclaration(
    specifiers: specifiers,
    source: StringLiteral(stringValue: src),
    importKind: importKind,
  );
}

ExportNamedDeclaration _parseExportNamedDecl(String line, int start, int end) {
  final text = line.trim();
  int i = 'export'.length;
  void skipWs() {
    while (i < text.length) {
      final c = text.codeUnitAt(i);
      if (c == 32 || c == 9)
        i++;
      else
        break;
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
      if (q2 > q)
        source = StringLiteral(stringValue: text.substring(q + 1, q2));
    }
  }
  return ExportNamedDeclaration(
    declaration: null,
    specifiers: specs,
    source: source,
  );
}

ExportAllDeclaration _parseExportAllDecl(String line, int start, int end) {
  final text = line.trim();
  final fromIdx = text.indexOf(' from ');
  if (fromIdx < 0) throw StateError('Invalid ExportAllDeclaration');
  int q = text.indexOf('"', fromIdx);
  if (q < 0) q = text.indexOf("'", fromIdx);
  if (q < 0) throw StateError('Invalid ExportAllDeclaration: missing source');
  final q2 = text.indexOf(text[q], q + 1);
  if (q2 < 0)
    throw StateError('Invalid ExportAllDeclaration: unterminated source');
  final src = text.substring(q + 1, q2);
  return ExportAllDeclaration(source: StringLiteral(stringValue: src));
}

ExportDefaultDeclaration _parseExportDefaultDecl(
  String line,
  int start,
  int end,
) {
  final text = line.trim();
  final idx = text.indexOf('export default');
  if (idx < 0) throw StateError('Invalid ExportDefaultDeclaration');
  var body = text.substring(idx + 'export default'.length).trim();
  if (body.endsWith(';')) body = body.substring(0, body.length - 1);
  final expr = _parseSimpleExpression(body, start, end);
  return ExportDefaultDeclaration(declaration: expr);
}
