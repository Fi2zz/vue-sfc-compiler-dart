import 'dart:io';
import 'package:vue_sfc_parser/sfc_parser.dart';
import 'package:vue_sfc_parser/script/script_compile.dart';
import 'package:vue_sfc_parser/template/compile_template.dart';
import 'package:vue_sfc_parser/ts_syntax/est_node.dart';

void main() {
  final src = File('bench/corpus/large_50.vue').readAsStringSync();
  final d = SfcParser(src, filename: './l.vue').parse();
  compileScriptSetup(d);
  final content = d.template!.content;
  for (var w = 0; w < 10; w++) {
    compileTemplateSource(content, filename: './l.vue', id: 'x');
  }
  int len() => JsonEstNode.canonicalLengthForTest;
  final a = len();
  for (var i = 0; i < 100; i++) {
    compileTemplateSource(content, filename: './l.vue', id: 'x');
  }
  final b = len();
  print('canonical entries: after-warmup=$a after-100-more=$b delta=${b - a}');
  print('per-compile retained entries ≈ ${(b - a) / 100}');
}
