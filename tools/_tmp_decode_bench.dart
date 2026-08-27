import 'dart:io';
import 'package:vue_sfc_parser/sfc_parser.dart';
import 'package:vue_sfc_parser/script/script_compile.dart';
import 'package:vue_sfc_parser/template/dom_options.dart';
import 'package:vue_sfc_parser/template/tmpl_parser.dart';
import 'package:vue_sfc_parser/ts_syntax/oxc_ffi.dart';
import 'package:vue_sfc_parser/template/transforms/expression_cache.dart';

void main() {
  final src = File('bench/corpus/large_50.vue').readAsStringSync();
  final d = SfcParser(src, filename: './l.vue').parse();
  compileScriptSetup(d);
  final ast =
      baseParse(d.template!.content, domParserOptions(prefixIdentifiers: true));
  final sources = collectExpressionSources(ast);
  stdout.writeln('expressions: ${sources.length}');
  final oxc = OxcFFI.load();
  for (var w = 0; w < 10; w++) {
    oxc.parseJsonBatch(sources, 'ts');
    oxc.parseBinBatch(sources, 'ts');
  }
  var tJson = 0, tBin = 0;
  const n = 200;
  for (var i = 0; i < n; i++) {
    var sw = Stopwatch()..start();
    oxc.parseJsonBatch(sources, 'ts');
    tJson += sw.elapsedMicroseconds;
    sw = Stopwatch()..start();
    oxc.parseBinBatch(sources, 'ts');
    tBin += sw.elapsedMicroseconds;
  }
  print('transport+decode: json=${tJson ~/ n}us bin=${tBin ~/ n}us '
      '(bin ${(tBin * 100 / tJson).toStringAsFixed(0)}% of json)');
}
