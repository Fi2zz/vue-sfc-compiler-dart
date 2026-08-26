// Scratch probe: RSS trajectory over 3000 large-tier rounds (leak check).
// Samples ProcessInfo.currentRss every 50 rounds; plateau = GC behavior,
// linear growth = leak. See PERF_BENCHMARK.md P0 action item.
import 'dart:io';
import '../bench/bench.dart' as bench;

void main() {
  final large10 = File('bench/corpus/large_10.vue').readAsStringSync();
  final large50 = File('bench/corpus/large_50.vue').readAsStringSync();
  const total = 3000;
  const sampleEvery = 50;
  final samples = <int>[];
  for (var i = 0; i < total; i++) {
    bench.compileOne(large10, 'large_10');
    bench.compileOne(large50, 'large_50');
    if (i % sampleEvery == 0) {
      samples.add(ProcessInfo.currentRss);
    }
  }
  samples.add(ProcessInfo.currentRss);
  final mb = samples.map((b) => (b / 1048576).toStringAsFixed(0)).join(',');
  stdout.writeln('rss_mb_every_50_rounds=[$mb]');
  stdout.writeln(
    'first=${samples.first} last=${samples.last} '
    'delta_mb=${((samples.last - samples.first) / 1048576).toStringAsFixed(1)}',
  );
}
