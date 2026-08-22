// Port of compiler-sfc doCompileStyle (plain CSS only; preprocessors and
// CSS modules are out of scope for now).
import 'style/css_parser.dart';
import 'style/css_stringify.dart';
import 'style/css_tokenize.dart';
import 'style/plugins_css_vars.dart';
import 'style/plugins_scoped.dart';
import 'style/plugins_trim.dart';
import 'style/selector_tokenize.dart';

final class StyleCompileResult {
  final String code;
  final List<String> errors;
  StyleCompileResult(this.code, this.errors);
}

/// Mirrors doCompileStyle({source, filename, id, scoped, trim}).
/// Plugin order follows the official: cssVars -> trim -> scoped.
StyleCompileResult compileStyleSource(
  String source, {
  required String filename,
  required String id,
  bool scoped = false,
  bool trim = true,
}) {
  final shortId = id.replaceFirst(RegExp('^data-v-'), '');
  final longId = 'data-v-$shortId';
  try {
    final root = parseCss(source);
    applyCssVarsPlugin(root, shortId);
    if (trim) applyTrimPlugin(root);
    if (scoped) applyScopedPlugin(root, longId);
    return StyleCompileResult(stringifyCss(root), const []);
  } on CssSyntaxError catch (e) {
    return StyleCompileResult('', [e.reason]);
  } on SelSyntaxError catch (e) {
    return StyleCompileResult('', [e.message]);
  }
}
