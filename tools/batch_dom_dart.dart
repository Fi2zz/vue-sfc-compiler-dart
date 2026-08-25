// compiler-dom batch runner (Dart side): mirror tools/batch_dom_official.mjs.
import 'dart:convert';
import 'dart:io';

import 'package:vue_sfc_parser/compiler_dom.dart';
import 'package:vue_sfc_parser/template/transform_context.dart';

void main(List<String> args) {
  final inputs = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final outDir = args[1];
  Directory(outDir).createSync(recursive: true);
  var n = 0;
  for (final input in inputs) {
    final id = input['id'] as String;
    final source = input['source'] as String;
    var out = '';
    try {
      final result = compile(source);
      out = '${result.code.trim()}\n';
    } catch (e) {
      out = 'THROW: ${_messageOf(e)}\n';
    }
    File('$outDir/${id.replaceAll('/', '__')}.txt').writeAsStringSync(out);
    n++;
  }
  stdout.writeln('done $n');
}

String _messageOf(Object e) => e is TmplCompileError ? e.message : '$e';
