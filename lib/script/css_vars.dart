// Port of compiler-sfc CSS v-bind script-side support: parseCssVars /
// lexBinding / genCssVarsCode. compileScript injects useCssVars registration
// when any <style> block references v-bind(...).
import '../template/js_nodes.dart';
import '../template/tmpl_ast.dart';
import '../template/transform_context.dart';
import '../template/transforms/transform_expression.dart';

final _vBindRE = RegExp(r'v-bind\s*\(');
final _styleCommentsRE = RegExp(r'/\*([\s\S]*?)\*\/|//.*');

/// 官方 parseCssVars：收集各 style 块内 v-bind(...) 的表达式（去重）。
List<String> parseCssVars(Iterable<String> styleContents) {
  final vars = <String>[];
  for (final raw in styleContents) {
    final content = raw.replaceAll(_styleCommentsRE, '');
    var from = 0;
    while (true) {
      final match = _vBindRE.firstMatch(content.substring(from));
      if (match == null) break;
      final start = from + match.end;
      final end = lexBinding(content, start);
      if (end != null) {
        final variable = _normalizeExpression(content.substring(start, end));
        if (!vars.contains(variable)) vars.add(variable);
      }
      from = start;
    }
  }
  return vars;
}

String _normalizeExpression(String exp) {
  exp = exp.trim();
  if (exp.length >= 2 &&
      ((exp.startsWith("'") && exp.endsWith("'")) ||
          (exp.startsWith('"') && exp.endsWith('"')))) {
    return exp.substring(1, exp.length - 1);
  }
  return exp;
}

/// 官方 lexBinding：从 start 起扫描至匹配的闭括号，返回其索引或 null。
int? lexBinding(String content, int start) {
  const inParens = 0, inSingleQuote = 1, inDoubleQuote = 2;
  var state = inParens;
  var parenDepth = 0;
  for (var i = start; i < content.length; i++) {
    final char = content[i];
    switch (state) {
      case inParens:
        if (char == "'") {
          state = inSingleQuote;
        } else if (char == '"') {
          state = inDoubleQuote;
        } else if (char == '(') {
          parenDepth++;
        } else if (char == ')') {
          if (parenDepth > 0) {
            parenDepth--;
          } else {
            return i;
          }
        }
      case inSingleQuote:
        if (char == "'") state = inParens;
      case inDoubleQuote:
        if (char == '"') state = inParens;
    }
  }
  return null;
}

/// 官方 getEscapedCssVarName（dev 路径，doubleEscape=false）。
String _escapeCssVarName(String key) => key.splitMapJoin(
  RegExp(r'''[ !"#$%&'()*+,./:;<=>?@\[\\\]^`{|}~]'''),
  onNonMatch: (m) => m,
  onMatch: (m) => '\\${m[0]}',
);

String _genVarName(String id, String raw) => '$id-${_escapeCssVarName(raw)}';

String _genCssVarsFromList(List<String> vars, String id) =>
    '{\n'
    '  ${vars.map((k) => '"${_genVarName(id, k)}": ($k)').join(',\n  ')}\n}';

/// 官方 genCssVarsCode：生成 `_useCssVars(_ctx => ({ ... }))` 注入代码，
/// 表达式经 processExpression 的 inline 模式改写（unref/.value 等）。
String genCssVarsCode(
  List<String> vars,
  Map<String, String>? bindings,
  String id,
) {
  final varsExp = _genCssVarsFromList(vars, id);
  final exp = createSimpleExp(varsExp, false, locStub());
  final options = TransformOptions()
    ..prefixIdentifiers = true
    ..inline = true
    ..bindingMetadata =
        (bindings != null && bindings['__isScriptSetup'] != 'false')
        ? bindings
        : const {};
  final context = TransformContext(RootNode([], locStub()), options);
  final transformed = processExpression(exp, context);
  final transformedString = transformed is SimpleExpression
      ? transformed.content
      : transformed is CompoundExpression
      ? transformed.children.map((c) {
          if (c is String) return c;
          if (c is SimpleExpression) return c.content;
          return '';
        }).join()
      : '';
  return '_useCssVars(_ctx => ($transformedString))';
}
