// Port of compiler-sfc cssVarsPlugin: v-bind(...) in declarations becomes
// var(--<id>-<escaped>) (non-prod naming only for now).
import 'css_ast.dart';

final _vBindRE = RegExp(r'v-bind\s*\(');
final _escapeSymbolsRE =
    RegExp(r"""[ !"#$%&'()*+,./:;<=>?@\[\\\]^`{|}~]""");

/// shared.getEscapedCssVarName(key, doubleEscape=false).
String escapedCssVarName(String key) =>
    key.replaceAllMapped(_escapeSymbolsRE, (m) => '\\${m[0]}');

/// genVarName(id, raw, isProd=false) — prod hashing is not needed yet.
String genVarName(String id, String raw) => '$id-${escapedCssVarName(raw)}';

String _normalizeExpression(String exp) {
  final e = exp.trim();
  if (e.length >= 2 &&
      ((e[0] == "'" && e[e.length - 1] == "'") ||
          (e[0] == '"' && e[e.length - 1] == '"'))) {
    return e.substring(1, e.length - 1);
  }
  return e;
}

/// lexBinding: find the index of the `)` closing the binding that starts at
/// [start]; null when unbalanced.
int? _lexBinding(String content, int start) {
  var state = 0; // 0 inParens, 1 inSingleQuoteString, 2 inDoubleQuoteString
  var parenDepth = 0;
  for (var i = start; i < content.length; i++) {
    final char = content[i];
    switch (state) {
      case 0:
        if (char == "'") {
          state = 1;
        } else if (char == '"') {
          state = 2;
        } else if (char == '(') {
          parenDepth++;
        } else if (char == ')') {
          if (parenDepth > 0) {
            parenDepth--;
          } else {
            return i;
          }
        }
      case 1:
        if (char == "'") state = 0;
      case 2:
        if (char == '"') state = 0;
    }
  }
  return null;
}

/// cssVarsPlugin's Declaration visitor (isProd=false).
void applyCssVarsPlugin(CssRoot root, String id) {
  root.walkDecls((decl) {
    final value = decl.value;
    if (!_vBindRE.hasMatch(value)) return;
    var transformed = '';
    var lastIndex = 0;
    for (final match in _vBindRE.allMatches(value)) {
      final start = match.end;
      final end = _lexBinding(value, start);
      if (end != null) {
        final variable = _normalizeExpression(value.substring(start, end));
        transformed +=
            '${value.substring(lastIndex, match.start)}var(--${genVarName(id, variable)})';
        lastIndex = end + 1;
      }
    }
    decl.value = transformed + value.substring(lastIndex);
  });
}
