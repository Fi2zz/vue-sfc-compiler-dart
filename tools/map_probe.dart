// Dev probe: compile one template source with sourceMap and dump segments.
import 'dart:convert';
import 'dart:io';
import '../lib/template/compile_template.dart';
import '../lib/template/source_map.dart';

void main(List<String> args) {
  final r = compileTemplateSource(args[0],
      filename: './p.vue', id: './p.vue', sourceMap: true);
  print(r.code);
  print('--- segs:');
  for (final s in decodeMappings(r.map!['mappings'] as String)) {
    print(s.join(','));
  }
}
