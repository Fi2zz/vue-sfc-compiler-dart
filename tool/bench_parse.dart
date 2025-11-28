import 'dart:io';
import 'dart:convert';

import 'package:vue_sfc_parser/swc_ffi.dart';

void main(List<String> args) async {
  final lib = SwcFFI.load();
  final file = File('vue_complex_official.ts');
  if (!file.existsSync()) {
    stderr.writeln('vue_complex_official.ts not found');
    exit(1);
  }
  final src = file.readAsStringSync();
  final rounds = 10;
  final times = <int>[];
  for (int i = 0; i < rounds; i++) {
    final sw = Stopwatch()..start();
    final jsonStr = lib.parse(src, language: 'ts', keepComments: true);
    // decode to simulate Dart side cost
    json.decode(jsonStr);
    sw.stop();
    times.add(sw.elapsedMilliseconds);
  }
  final avg = times.reduce((a, b) => a + b) / times.length;
  stdout.writeln(
    'bench_parse: rounds=$rounds avg_ms=${avg.toStringAsFixed(2)} times=$times',
  );
}
