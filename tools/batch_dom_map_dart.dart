// Dart counterpart of tools/batch_dom_map_official.mjs: decode function-mode
// maps from lib/compiler_dom.dart into canonical segment lines for diffing.
import 'dart:convert';
import 'dart:io';
import 'package:vue_sfc_parser/compiler_dom.dart';
import 'package:vue_sfc_parser/template/source_map.dart';

void main(List<String> args) {
  final inputs = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final outDir = args[1];
  Directory(outDir).createSync(recursive: true);
  final combos = <String, void Function(DomCompileOptions)>{
    'fn': (_) {},
    'fn_hoist': (opt) => opt.hoistStatic = true,
  };
  for (final input in inputs) {
    final id = input['id'] as String;
    final source = input['source'] as String;
    for (final entry in combos.entries) {
      String out;
      try {
        final opt = DomCompileOptions()..sourceMap = true;
        entry.value(opt);
        final m = compile(source, opt).map;
        out = m == null
            ? 'NOMAP'
            : jsonEncode(decodeMappings(m['mappings'] as String));
      } catch (_) {
        out = 'THROW';
      }
      File(
        '$outDir/${id.replaceAll('/', '__')}__${entry.key}.txt',
      ).writeAsStringSync('$out\n');
    }
  }
  stdout.writeln('done');
}
