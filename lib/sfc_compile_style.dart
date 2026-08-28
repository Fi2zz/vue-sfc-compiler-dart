// Port of compiler-sfc doCompileStyle (plain CSS only; preprocessors and
// CSS modules are out of scope for now).
import 'dart:io';

import 'style/css_error.dart';
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
  bool isProd = false,
}) {
  final shortId = id.replaceFirst(RegExp('^data-v-'), '');
  final longId = 'data-v-$shortId';
  // postcss Input 构造器会剥掉 BOM，后续偏移与输出都基于剥后的文本。
  var css = source;
  if (css.startsWith('\uFEFF') || css.startsWith('\uFFFE')) {
    css = css.substring(1);
  }
  try {
    final root = parseCss(css);
    applyCssVarsPlugin(root, shortId, isProd: isProd);
    if (trim) applyTrimPlugin(root);
    if (scoped) applyScopedPlugin(root, longId);
    return StyleCompileResult(stringifyCss(root), const []);
  } on CssSyntaxError catch (e) {
    final file = resolveStyleFilename(filename, Directory.current.path);
    return StyleCompileResult('', [formatCssSyntaxError(css, file, e)]);
  } on SelSyntaxError catch (e) {
    // selector 错误是原生 Error，String(e) = 'Error: <message>'
    return StyleCompileResult('', ['Error: ${e.message}']);
  } catch (e) {
    // Official doCompileStyle catches any plugin exception into
    // result.errors (postcss re-throws the original error object; its
    // String() carries the JS type name, e.g. 'TypeError: ...'). Match the
    // never-crash contract; the exact message text is JS-internal and not
    // byte-reproducible in Dart.
    return StyleCompileResult('', [e.toString()]);
  }
}
