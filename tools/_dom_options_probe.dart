// Options-surface differential probe (Dart side): mirror
// tools/_dom_options_probe.mjs exactly.
import 'package:vue_sfc_parser/compiler_dom.dart';
import 'package:vue_sfc_parser/template/transform_context.dart';

const templates = [
  '<div>{{ msg }}</div>',
  '<div v-if="ok">a</div><p v-else>b</p>',
  '<input v-model="x">',
  '<div @click="go">x</div>',
  '<!-- hi --><div>y</div>',
  '<div   class="a"   >  text  </div>',
  '<div>{{ count + 1 }}</div>',
];

void main() {
  final combos = <String, DomCompileOptions Function()>{
    'module': () => DomCompileOptions()..mode = 'module',
    'hoist': () => DomCompileOptions()..hoistStatic = true,
    'cache': () => DomCompileOptions()
      ..mode = 'module'
      ..cacheHandlers = true,
    'preserve': () => DomCompileOptions()..whitespace = 'preserve',
    'nocomments': () => DomCompileOptions()..comments = false,
    'ists': () => DomCompileOptions()..isTS = true,
    'custel': () => DomCompileOptions()..isCustomElement = (t) => t == 'input',
    'err49': () => DomCompileOptions()..cacheHandlers = true,
  };
  for (final entry in combos.entries) {
    for (final t in templates) {
      String out;
      try {
        out = compile(t, entry.value()).code;
      } catch (e) {
        out = 'THROW: ${e is TmplCompileError ? e.message : e}';
      }
      print('### ${entry.key} :: ${_jsonStr(t)}\n$out\n');
    }
  }
}

String _jsonStr(String s) => '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
