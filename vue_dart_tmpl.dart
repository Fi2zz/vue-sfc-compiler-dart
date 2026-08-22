// Dart-side generator mirroring gen_official_tmpl.mjs: read samples_tmpl.json,
// compileTemplate each SFC's template block, write samples_tmpl_dart/<name>.md.
import 'dart:convert';
import 'dart:io';

import 'lib/template/compile_template.dart';
import 'lib/template/transform_context.dart';
import 'lib/vue.dart';

void main(List<String> args) {
  final samples =
      (jsonDecode(File('samples_tmpl.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
  final outDir = args.isNotEmpty ? args[0] : 'samples_tmpl_dart';
  Directory(outDir).createSync(recursive: true);
  for (final s in samples) {
    final name = s['name'] as String;
    final sfc = s['sfc'] as String;
    final filename = './$name.vue';
    final md = StringBuffer('# $name\n\n');
    final descriptor = Vue.parse(sfc, filename: filename);
    final template = descriptor.template;
    if (template == null) {
      md.writeln('Vue Compile Error: missing template block');
    } else {
      try {
        final scoped = descriptor.styles.any((st) => st.scoped);
        final result = compileTemplateSource(template.content,
            filename: filename, id: filename, scoped: scoped);
        md.writeln('```\n${result.code.trim()}\n```');
        if (result.errors.isNotEmpty) {
          md.writeln(
              "ERRORS: ${result.errors.map((e) => 'SyntaxError: ${e.message}').join('; ')}");
        }
      } catch (e) {
        md.writeln(
            'Vue Compile Error: ${e is TmplCompileError ? e.message : '$e'}');
      }
    }
    File('$outDir/$name.md').writeAsStringSync(md.toString());
  }
  stdout.writeln('done ${samples.length}');
}
