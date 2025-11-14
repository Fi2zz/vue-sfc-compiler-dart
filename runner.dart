import 'dart:io';
import 'lib/vue.dart';

void main(List<String> args) {
  final outFile = File('vue_compiler_output_dart.ts');
  if (outFile.existsSync()) outFile.deleteSync();
  final ts = File('vue.ts').readAsStringSync();
  final reg = RegExp(r'name:\s*"([^"]+)"\s*,\s*sfc:\s*`([\s\S]*?)`');
  final matches = reg.allMatches(ts).toList();
  final buf = StringBuffer();
  for (final m in matches) {
    final name = m.group(1)!;
    String sfc = m.group(2)!;
    sfc = sfc.replaceAll('\\n', '\n').replaceAll('\\"', '"');
    buf.writeln('// ==== $name ====');
    try {
      final res = Vue.compile(sfc, filename: './$name.vue');
      buf.writeln(res.script.trim());
    } catch (e) {
      buf.writeln('// ERROR: ' + e.toString());
    }
    buf.writeln();
  }
  outFile.writeAsStringSync(buf.toString());
}
