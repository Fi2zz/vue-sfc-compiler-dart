// Phase B Dart-side batch runner: mirror tools/batch_official.mjs exactly.
import 'dart:convert';
import 'dart:io';

import '../lib/script/script_compile.dart';
import '../lib/vue.dart';
import '../lib/template/compile_template.dart';

void main(List<String> args) {
  final inputs =
      (jsonDecode(File(args[0]).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
  final outDir = args[1];
  Directory(outDir).createSync(recursive: true);
  var n = 0;
  for (final input in inputs) {
    final id = input['id'] as String;
    final kind = input['kind'] as String;
    final source = input['source'] as String;
    var out = '';
    try {
      if (kind == 'sfc') {
        final filename = './$id.vue';
        final outcome = Vue.parseCollecting(source, filename: filename);
        final descriptor = outcome.descriptor;
        if (outcome.errors.isNotEmpty) {
          out = 'PARSE_ERROR: ${outcome.errors.first}\n';
        } else if (descriptor!.scriptSetup == null &&
            descriptor.script == null) {
          out = 'NO_SCRIPT\n';
        } else if (descriptor.scriptSetup == null) {
          // 官方 compileScript 对纯外链 <script src> 原样透传（空内容）。
          out = '\n';
        } else {
          final result = compileScriptSetup(descriptor,
              hoistStatic: descriptor.script == null);
          out = '${result.code.trim()}\n';
          final bindings = result.bindings
            ..remove('__isScriptSetup')
            ..removeWhere((k, _) => k.startsWith('__propsAliases:'));
          if (bindings.isNotEmpty) {
            out += '\nBINDINGS: ${jsonEncode(bindings)}\n';
          }
        }
      } else {
        final filename = './$id.vue';
        final result = compileTemplateSource(
          source,
          filename: filename,
          id: filename,
        );
        out = '${result.code.trim()}\n';
        if (result.errors.isNotEmpty) {
          out +=
              '\nERRORS: ${result.errors.map((e) => e.message).join('; ')}\n';
        }
      }
    } catch (e) {
      out = 'THROW: $e\n';
    }
    final flat = id.replaceAll('/', '__');
    File('$outDir/$flat.txt').writeAsStringSync(out);
    n++;
  }
  stdout.writeln('done $n');
}
