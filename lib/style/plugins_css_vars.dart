// Port of compiler-sfc cssVarsPlugin: v-bind(...) in declarations becomes
// var(--<id>-<escaped>)，isProd 时变量名为 hash-sum 哈希。
import 'css_ast.dart';

final _vBindRE = RegExp(r'v-bind\s*\(');
final _escapeSymbolsRE =
    RegExp(r"""[ !"#$%&'()*+,./:;<=>?@\[\\\]^`{|}~]""");

/// shared.getEscapedCssVarName(key, doubleEscape=false).
String escapedCssVarName(String key) =>
    key.replaceAllMapped(_escapeSymbolsRE, (m) => '\\${m[0]}');

/// genVarName(id, raw, isProd)：prod 下为 hash-sum 的 8 位十六进制，
/// 首字符是数字时换成 'v'+该数字（replace(/^\d/, r => 'v\$r')）。
String genVarName(String id, String raw, {bool isProd = false}) {
  if (!isProd) return '$id-${escapedCssVarName(raw)}';
  final hex = hashSum(id + raw);
  final first = hex.codeUnitAt(0);
  final digit = first >= 0x30 && first <= 0x39;
  return digit ? 'v${hex[0]}${hex.substring(1)}' : hex;
}

/// hash-sum 包对字符串的 sum()：
/// pad(fold(fold(fold(0, '[object String]'), 'string'), s).toString(16), 8)。
String hashSum(String s) {
  var h = _fold(0, '');
  h = _fold(h, '[object String]');
  h = _fold(h, 'string');
  return _fold(h, s).toRadixString(16).padLeft(8, '0');
}

/// hash-sum 的 fold：JS 位运算按 int32 截断，末尾负值乘 -2。
int _fold(int hash, String text) {
  if (text.isEmpty) return hash;
  for (var i = 0; i < text.length; i++) {
    hash = (((hash << 5).toSigned(32) - hash) + text.codeUnitAt(i))
        .toSigned(32);
  }
  return hash < 0 ? hash * -2 : hash;
}

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

/// cssVarsPlugin's Declaration visitor.
void applyCssVarsPlugin(CssRoot root, String id, {bool isProd = false}) {
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
            '${value.substring(lastIndex, match.start)}var(--${genVarName(id, variable, isProd: isProd)})';
        lastIndex = end + 1;
      }
    }
    decl.value = transformed + value.substring(lastIndex);
  });
}
