// Ports of the vue-sfc postcss plugins: trim (always on) and scoped.
// cssVars (v-bind in CSS) lives in css_vars_plugin.dart.
import 'css_ast.dart';

/// vue-sfc-trim: normalize rule/atrule raws.before/after to a single \n.
void applyTrimPlugin(CssRoot root) {
  root.walk((node) {
    if (node.type == 'rule' || node.type == 'atrule') {
      if (node.raws.before != null && node.raws.before!.isNotEmpty) {
        node.raws.before = '\n';
      }
      if (node is CssContainer) {
        final after = node.raws.after;
        if (after != null && after.isNotEmpty) {
          node.raws.after = '\n';
        }
      }
    }
    return true;
  });
}
