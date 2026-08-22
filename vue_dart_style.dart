// Dart-side generator mirroring gen_official_style.mjs: read
// samples_style.json, compileStyle each source, write
// samples_style_dart/<name>.md.
import 'dart:convert';
import 'dart:io';

import 'lib/sfc_compile_style.dart';

void main(List<String> args) {
  final samples =
      (jsonDecode(File('samples_style.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
  final outDir = args.isNotEmpty ? args[0] : 'samples_style_dart';
  Directory(outDir).createSync(recursive: true);
  for (final s in samples) {
    final name = s['name'] as String;
    final source = s['source'] as String;
    final options = s['options'] as Map<String, dynamic>?;
    final scoped = options?['scoped'] as bool? ?? false;
    final trim = options?['trim'] as bool? ?? true;
    final isProd = options?['isProd'] as bool? ?? false;
    final filename = './$name.vue';
    final result = compileStyleSource(source,
        filename: filename,
        id: filename,
        scoped: scoped,
        trim: trim,
        isProd: isProd);
    final md = StringBuffer('# $name\n\n```\n${result.code}\n```\n');
    if (result.errors.isNotEmpty) {
      md.writeln('ERRORS: ${result.errors.join('; ')}');
    }
    File('$outDir/$name.md').writeAsStringSync(md.toString());
  }
  stdout.writeln('done ${samples.length}');
}
