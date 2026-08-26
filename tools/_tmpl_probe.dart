// Scratch probe: template sub-stage timing on large_50 (not part of bench).
import 'dart:io';
import 'package:vue_sfc_parser/sfc_parser.dart';
import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/template/tmpl_parser.dart';
import 'package:vue_sfc_parser/template/compile_template.dart';

void main() {
  final src = File('bench/corpus/large_50.vue').readAsStringSync();
  final d = SfcParser(src, filename: './large_50.vue').parse();
  final tpl = d.template!.content;
  const n = 60;
  int timeStage(void Function() f) {
    for (var i = 0; i < 5; i++) {
      f();
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      f();
    }
    return sw.elapsedMicroseconds ~/ n;
  }

  final tBaseParse = timeStage(() {
    baseParse(tpl, const TmplParserOptions());
  });
  final tFull = timeStage(() {
    compileTemplateSource(tpl, filename: './large_50.vue', id: 'data-v-x');
  });
  stdout.writeln(
    'baseParse=$tBaseParse full=$tFull transform+codegen=${tFull - tBaseParse} (us/iter)',
  );
}
