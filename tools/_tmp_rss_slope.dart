import 'dart:io';
import 'package:vue_sfc_parser/sfc_parser.dart';
import 'package:vue_sfc_parser/template/compile_template.dart';

void main() {
  final src = File('bench/corpus/large_50.vue').readAsStringSync();
  final d = SfcParser(src, filename: './l.vue').parse();
  final content = d.template!.content;
  final scriptSrc = src;
  for (var w = 0; w < 20; w++) {
    SfcParser(scriptSrc, filename: './l.vue').parse();
    compileTemplateSource(content, filename: './l.vue', id: 'x');
  }
  const checkpoints = [100, 200, 300, 400, 600, 800];
  var done = 0;
  final sw = Stopwatch()..start();
  for (var i = 1; i <= 800; i++) {
    SfcParser(scriptSrc, filename: './l$i.vue').parse();
    compileTemplateSource(content, filename: './l$i.vue', id: 'x');
    done = i;
    if (checkpoints.contains(i)) {
      final mb = (ProcessInfo.currentRss / 1048576).round();
      stdout.writeln('round=$i rss=${mb}MB');
    }
  }
  stderr.writeln('done=$done elapsed=${sw.elapsedMilliseconds}ms');
}
