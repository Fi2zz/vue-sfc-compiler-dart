// Dart counterpart of tools/batch_map_official.mjs.
import 'dart:convert';
import 'dart:io';
import '../lib/template/compile_template.dart';
import '../lib/template/source_map.dart';

void main(List<String> args) {
  final inputs = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final outDir = args[1];
  Directory(outDir).createSync(recursive: true);
  for (final input in inputs) {
    if (input['kind'] != 'template') continue;
    final id = input['id'] as String;
    final source = input['source'] as String;
    String out;
    try {
      final r = compileTemplateSource(source,
          filename: './$id.vue', id: './$id.vue', sourceMap: true);
      final m = r.map;
      if (m == null) {
        out = 'NOMAP';
      } else {
        final segs = decodeMappings(m['mappings'] as String);
        out = jsonEncode(segs);
      }
    } catch (_) {
      out = 'THROW';
    }
    File('$outDir/${id.replaceAll('/', '__')}.txt').writeAsStringSync('$out\n');
  }
  stdout.writeln('done');
}
