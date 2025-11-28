import 'dart:convert';

// import 'package:vue_sfc_parser/code_printer/printer.dart';
// import 'package:vue_sfc_parser/comment_parser.dart' as cp;
import 'package:vue_sfc_parser/error_report.dart';
import 'package:vue_sfc_parser/ast.dart';
// merged: swc_ast types are now provided by ast

// removed legacy SWC Module→CompilationUnit adapter

/// Build a CompilationUnit from a Program while preserving order and metadata.
/// This function now also mirrors all `export` statements into the
/// `statements` list as `ExpressionStatement`s (with raw text), in addition
/// to populating the `exported` declarations list. Existing behaviors for
/// imports, variable declarations and call expressions remain unchanged.
CompilationUnit programToCompilationUnit(
  Program p,
  String src, {
  String? filename = './unknown',
  ErrorReportConfig? errConfig,
}) {
  // Build CompilationUnit from Program while preserving order and metadata.
  final statements = <ExpressionStatement>[];
  final imported = <Declaration>[];
  final exported = <Declaration>[];
  for (final st in p.body) {
    if (st is ImportDeclaration) {
      imported.add(st);
      final sByte = st.loc?.start.index ?? 0;
      final eByte = st.loc?.end.index ?? src.length;
      var rawText = _readStmtFullLine(src, sByte, eByte);
      if (rawText.isEmpty) {
        final parts = <String>[];
        String? defaultLocal;
        String? namespaceLocal;
        for (final s in st.specifiers) {
          if (s is ImportDefaultSpecifier) {
            defaultLocal = s.local.name;
          } else if (s is ImportNamespaceSpecifier) {
            namespaceLocal = s.local.name;
          } else if (s is ImportSpecifier) {
            String imported;
            if (s.imported is Identifier) {
              imported = (s.imported as Identifier).name;
            } else if (s.imported is StringLiteral) {
              imported = (s.imported as StringLiteral).stringValue;
            } else {
              imported = s.local.name;
            }
            parts.add(
              imported == s.local.name
                  ? imported
                  : '$imported as ${s.local.name}',
            );
          }
        }
        final srcStr = st.source.stringValue;
        if (namespaceLocal != null) {
          rawText = 'import * as $namespaceLocal from ${_quote(srcStr)};';
        } else if (defaultLocal != null && parts.isEmpty) {
          rawText = 'import $defaultLocal from ${_quote(srcStr)};';
        } else if (defaultLocal != null && parts.isNotEmpty) {
          rawText =
              'import $defaultLocal, { ${parts.join(', ')} } from ${_quote(srcStr)};';
        } else {
          rawText = 'import { ${parts.join(', ')} } from ${_quote(srcStr)};';
        }
      }
      statements.add(
        ExpressionStatement(
          text: rawText,
          expression: Identifier(text: rawText, name: rawText),
        ),
      );
    } else if (st is ExportNamedDeclaration) {
      exported.add(st);
      final sByte = st.loc?.start.index ?? 0;
      final eByte = st.loc?.end.index ?? src.length;
      var rawText = _readStmtFullLine(src, sByte, eByte);
      if (rawText.isEmpty) rawText = _buildExportNamedText(st);
      if (rawText.isNotEmpty && !rawText.trimLeft().startsWith('export')) {
        rawText = 'export $rawText';
      }
      statements.add(
        ExpressionStatement(
          text: rawText,
          expression: Identifier(text: rawText, name: rawText),
        ),
      );
    } else if (st is ExportAllDeclartion) {
      exported.add(st);
      final sByte = st.loc?.start.index ?? 0;
      final eByte = st.loc?.end.index ?? src.length;
      var rawText = _readStmtFullLine(src, sByte, eByte);
      statements.add(
        ExpressionStatement(
          text: rawText,
          expression: Identifier(text: rawText, name: rawText),
        ),
      );
    } else if (st is ExportDefaultDeclaration) {
      final sByte = st.loc?.start.index ?? 0;
      final idx = _findExportDefaultIndexIgnoringComments(src, sByte);

      Declaration target;

      // if (idx < 0) idx = src.indexOf(key); // fallback
      if (idx >= 0) {
        final tail = _readExportDefaultTail(src, idx);
        final expr = _parseExportDefaultExpr(tail, st.declaration);

        // target = expr;
        target = ExportDefaultDeclaration(declaration: expr);
        exported.add(ExportDefaultDeclaration(declaration: expr));
      } else {
        target = st.declaration as Declaration;
        exported.add(st);
      }
      // Mirror export default statement into statements with raw text
      final eByte = st.loc?.end.index ?? src.length;
      var rawText = _readStmtFullLine(src, sByte, eByte);
      if (rawText.isEmpty) {
        final idx2 = _findExportDefaultIndexIgnoringComments(src, sByte);
        final tail2 = idx2 >= 0 ? _readExportDefaultTail(src, idx2) : '';
        rawText = tail2.isNotEmpty ? 'export default $tail2' : 'export default';
      }
      statements.add(
        ExpressionStatement(
          text: rawText,
          declaration: target,
          expression: Identifier(name: 'export default', text: rawText),
        ),
      );
    } else if (st is FunctionDeclaration) {
      final raw = st.text;
      if (raw.isNotEmpty) {
        statements.add(
          ExpressionStatement(
            text: raw,
            expression: Identifier(text: raw, name: raw),
          ),
        );
      }
    } else if (st is ExpressionStatement) {
      final exp = st.expression;
      if (exp is VariableDeclaration) {
        final sByte = st.loc?.start.index ?? 0;
        final eByte = st.loc?.end.index ?? src.length;
        var rawText = _readStmtFullLine(src, sByte, eByte);
        final varDecl = VariableDeclaration(
          exp.init,

          text: rawText,
          name: exp.name,
          pattern: exp.pattern,
          declKind: exp.declKind,
        );
        statements.add(
          ExpressionStatement(
            text: rawText,
            expression: varDecl,
            declaration: varDecl,
          ),
        );
      } else if (exp is FunctionCallExpression) {
        List<PropSignature> parseTypeLiteralProps(String raw) {
          final out = <PropSignature>[];
          if (raw.isEmpty) return out;
          final bodyStart = raw.indexOf('{');
          final bodyEnd = raw.lastIndexOf('}');
          if (bodyStart < 0 || bodyEnd <= bodyStart) return out;
          final body = raw.substring(bodyStart + 1, bodyEnd);
          int i = 0;
          String readIdent() {
            final start = i;
            while (i < body.length) {
              final c = body.codeUnitAt(i);
              final ok =
                  (c >= 65 && c <= 90) ||
                  (c >= 97 && c <= 122) ||
                  (c >= 48 && c <= 57) ||
                  c == 95 ||
                  c == 36;
              if (!ok) break;
              i++;
            }
            return body.substring(start, i);
          }

          void skipWs() {
            while (i < body.length) {
              final c = body.codeUnitAt(i);
              if (c == 32 || c == 9 || c == 10 || c == 13) {
                i++;
              } else {
                break;
              }
            }
          }

          while (i < body.length) {
            skipWs();
            if (i >= body.length) break;
            final name = readIdent();
            if (name.isEmpty) break;
            skipWs();
            bool required = true;
            if (i < body.length && body[i] == '?') {
              required = false;
              i++;
            }
            // advance to ':'
            while (i < body.length && body[i] != ':') {
              i++;
            }
            if (i < body.length && body[i] == ':') i++;
            // read type token (basic word)
            skipWs();
            final typeStart = i;
            while (i < body.length &&
                body[i] != ';' &&
                body[i] != ',' &&
                body[i] != '\n' &&
                body[i] != '}') {
              i++;
            }
            final typeText = body.substring(typeStart, i).trim();
            out.add(
              PropSignature(
                name: name,
                type: typeText.isEmpty ? null : typeText,
                required: required,
              ),
            );
            // skip separators
            while (i < body.length &&
                (body[i] == ';' ||
                    body[i] == ',' ||
                    body[i] == '\n' ||
                    body[i] == ' ')) {
              i++;
            }
          }
          return out;
        }

        List<PropSignature> props = const [];
        if (exp.typeArgumentText != null &&
            exp.typeArgumentText!.contains('{')) {
          props = parseTypeLiteralProps(exp.typeArgumentText!);
        }
        final sByte2 = st.loc?.start.index ?? 0;
        final eByte2 = st.loc?.end.index ?? src.length;
        var rawText2 = _readStmtFullLine(src, sByte2, eByte2);
        if (rawText2.isEmpty && st.text.isNotEmpty) rawText2 = st.text;
        final newCall = FunctionCallExpression(
          methodName: exp.methodName,
          argumentList: exp.argumentList,
          typeArgumentText: exp.typeArgumentText,
          typeArgumentProps: props,

          text: rawText2,
        );
        final emitText = rawText2.trimRight().endsWith(';')
            ? rawText2.trimRight()
            : '${rawText2.trimRight()};';
        statements.add(
          ExpressionStatement(expression: newCall, text: emitText),
        );
      }
    }
  }
  if (statements.isNotEmpty) {
    statements.sort(
      (a, b) => (a.loc?.start.index ?? 0).compareTo(b.loc?.start.index ?? 0),
    );
    final seen = <String>{};
    final deduped = <ExpressionStatement>[];
    for (final s in statements) {
      final key =
          '${s.loc?.start.index ?? 0}:${s.loc?.end.index ?? src.length}:${s.text}';
      if (seen.add(key)) deduped.add(s);
    }
    statements
      ..clear()
      ..addAll(deduped);
  }
  return CompilationUnit(
    text: src,
    comments: p.comments,
    statements: statements,
    imported: imported,
    exported: exported,
  );
}

String _readStmtFullLine(String src, int startByte, int endByte) {
  // backtrack to line start
  final bytes = utf8.encode(src);
  int ls = startByte;
  while (ls > 0) {
    final ch = String.fromCharCode(bytes[ls - 1]);
    if (ch == '\n') break;
    ls--;
  }
  var t = slice(src, ls, endByte).trimRight();
  // do NOT append semicolon; rely on raw slice content
  return t;
}

String _buildExportNamedText(ExportNamedDeclaration d) {
  final parts = d.specifiers
      .map((e) {
        if (e is ExportNamespaceSpecifier) return '* as ${e.exported.name}';
        if (e is ExportDefaultSpecifier) return e.exported.name;
        if (e is ExportSpecifier) {
          final exp = e.exported is Identifier
              ? (e.exported as Identifier).name
              : (e.exported as StringLiteral).stringValue;
          if (exp == e.local.name) return e.local.name;
          return '${e.local.name} as $exp';
        }
        return '';
      })
      .where((s) => s.isNotEmpty)
      .join(', ');
  final src = d.source?.stringValue;
  if (src != null) return 'export { $parts } from ${_quote(src)};';
  return 'export { $parts };';
}

String _quote(String s) => '"${s.replaceAll('"', '\\"')}"';

/// Find the index of the first occurrence of `export` + whitespace + `default`
/// that is not inside a comment block/line, starting from `startByte`.
int _findExportDefaultIndexIgnoringComments(String src, int startByte) {
  bool inComment(int pos) {
    // for (final c in comments) {
    //   if (pos >= c.startByte && pos < c.endByte) return true;
    // }
    return false;
  }

  int i = startByte;
  while (i + 6 <= src.length) {
    if (!inComment(i) && src.substring(i, i + 6) == 'export') {
      int lineStart = i;
      while (lineStart > 0 && src[lineStart - 1] != '\n') {
        lineStart--;
      }
      final before = src.substring(lineStart, i);
      final cmtIdx = before.indexOf('//');
      if (cmtIdx >= 0 && cmtIdx <= (i - lineStart)) {
        i++;
        continue;
      }
      int j = i + 6;
      while (j < src.length) {
        final cj = src.codeUnitAt(j);
        if (cj == 32 || cj == 9 || cj == 10 || cj == 13) {
          j++;
        } else {
          break;
        }
      }
      if (j + 7 <= src.length &&
          !inComment(j) &&
          src.substring(j, j + 7) == 'default') {
        return i;
      }
    }
    i++;
  }
  return -1;
}

/// Read the raw tail text following `export default` until `;` (supports multiline).
String _readExportDefaultTail(String src, int exportIndex) {
  const key = 'export default';
  int j = exportIndex + key.length;
  while (j < src.length) {
    final c = src.codeUnitAt(j);
    if (c == 32 || c == 9 || c == 10 || c == 13) {
      j++;
    } else {
      break;
    }
  }
  int k = j;
  int depth = 0;
  bool inS = false;
  bool inD = false;
  bool inBT = false;
  bool esc = false;
  while (k < src.length) {
    final ch = src[k];
    if (inS) {
      if (!esc && ch == '\\') {
        esc = true;
        k++;
        continue;
      } else if (esc) {
        esc = false;
        k++;
        continue;
      }
      if (ch == '\'') inS = false;
      k++;
      continue;
    }
    if (inD) {
      if (!esc && ch == '\\') {
        esc = true;
        k++;
        continue;
      } else if (esc) {
        esc = false;
        k++;
        continue;
      }
      if (ch == '"') inD = false;
      k++;
      continue;
    }
    if (inBT) {
      if (ch == '`') inBT = false;
      k++;
      continue;
    }
    if (ch == '\'') {
      inS = true;
      k++;
      continue;
    }
    if (ch == '"') {
      inD = true;
      k++;
      continue;
    }
    if (ch == '`') {
      inBT = true;
      k++;
      continue;
    }
    if (ch == '{') {
      depth++;
      k++;
      continue;
    }
    if (ch == '}') {
      depth--;
      k++;
      if (depth == 0) break;
      continue;
    }
    k++;
  }
  return src.substring(j, k).trimRight();
}

/// Convert raw tail text to an Expression; fallback to declaration when tail is empty.
Expression _parseExportDefaultExpr(String tail, Object declaration) {
  if (tail.isEmpty) {
    if (declaration is Expression) return declaration;
    return NullLiteral();
  }
  if (tail.startsWith('{')) {
    return Identifier(text: tail, name: '');
  }
  if (tail == 'true' || tail == 'false') {
    return BooleanLiteral(value: tail == 'true', text: tail);
  }
  final numVal = num.tryParse(tail);
  if (numVal != null) return NumberLiteral(value: numVal, text: tail);
  if (tail.startsWith("'") || tail.startsWith('"')) {
    final sv = tail.length >= 2 ? tail.substring(1, tail.length - 1) : tail;
    return StringLiteral(stringValue: sv, text: tail);
  }
  return Identifier(text: tail, name: tail);
}

bool isSimpleIdentifier(String s) {
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

String? outerBracesBody(String s) {
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

bool isWhitespace(int c) {
  return c == 32 || c == 9 || c == 10 || c == 13;
}

bool isIdentChar(int c) {
  return (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      (c >= 48 && c <= 57) ||
      c == 95 ||
      c == 36;
}

String slice(String src, int startByte, int endByte) {
  final bytes = utf8.encode(src);
  final s = startByte.clamp(0, bytes.length);
  final e = endByte.clamp(0, bytes.length);
  if (e <= s) return '';
  return utf8.decode(bytes.sublist(s, e));
}
