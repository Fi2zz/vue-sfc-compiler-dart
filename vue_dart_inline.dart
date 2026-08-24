// Dart-side generator mirroring gen_official_inline.mjs: compileScriptSetup
// with hoistStatic + inlineTemplate (the vite-plugin-vue build flow).
import 'dart:convert';
import 'dart:io';

import 'lib/sfc_parser.dart';
import 'lib/script/script_compile.dart';

void main(List<String> args) {
  final samples =
      (jsonDecode(File('samples_inline.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
  final outDir = args.isNotEmpty ? args[0] : 'samples_inline_dart';
  Directory(outDir).createSync(recursive: true);
  for (final s in samples) {
    final name = s['name'] as String;
    final sfc = s['sfc'] as String;
    final filename = './$name.vue';
    final md = StringBuffer('# $name\n\n');
    try {
      final descriptor = SfcParser(sfc, filename: filename).parse();
      final result = compileScriptSetup(descriptor,
          hoistStatic: true, inlineTemplate: true);
      md.writeln('```\n${result.code.trim()}\n```');
      if (result.bindings.isNotEmpty) {
        md.writeln('\nBINDINGS: ${jsonEncode(_withoutInternal(result.bindings))}');
      }
    } catch (e) {
      md.writeln('Vue Compile Error: $e');
    }
    File('$outDir/$name.md').writeAsStringSync(md.toString());
  }
  stdout.writeln('done ${samples.length}');
}

// 官方 bindings 不含内部键；Dart 侧的 __isScriptSetup 是普通键，输出时剥离。
Map<String, dynamic> _withoutInternal(Map<String, String> bindings) =>
    Map.fromEntries(bindings.entries
        .where((e) => e.key != '__isScriptSetup' && !e.key.startsWith('__propsAliases:'))
        .map((e) => MapEntry(e.key, e.value)));
