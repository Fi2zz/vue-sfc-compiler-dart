// Performance benchmark runner (see PERF_BENCHMARK.md).
// Usage: dart run bench/bench.dart [--tier=all] [--runs=100] [--warmup=15]
//                                   [--conc=1,2,4,8] [--out=bench/results/x.json]
// Aborts when TS_AST_CORPUS is set: the corpus recorder would poison data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:vue_sfc_parser/sfc_compile_style.dart';
import 'package:vue_sfc_parser/sfc_parser.dart';
import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/sfc_error.dart';
import 'package:vue_sfc_parser/script/script_compile.dart';
import 'package:vue_sfc_parser/template/compile_template.dart';
import 'package:vue_sfc_parser/template/transform_context.dart';
import 'package:vue_sfc_parser/ts_parser.dart';
import 'package:vue_sfc_parser/ts_syntax/oxc_ffi.dart';
import 'package:vue_sfc_parser/ts_syntax/oxc_mapper.dart';
import 'corpus_data.dart';

Future<void> main(List<String> args) async {
  if (Platform.environment['TS_AST_CORPUS']?.isNotEmpty ?? false) {
    stderr.writeln('TS_AST_CORPUS is set; unset it before benchmarking.');
    exitCode = 2;
    return;
  }
  final runs = _intArg(args, '--runs', 100);
  final warmup = _intArg(args, '--warmup', 15);
  final tiers = _strArg(args, '--tier', 'all');
  final concLevels = _intArg(args, '--conc', -1);
  final result = <String, dynamic>{'env': _env(), 'tiers': {}};

  final corpora = <String, List<({String name, String src})>>{
    'tiny': _named(tinyCorpus),
    'typical': _loadTypical(),
    'ts_heavy': _named(tsHeavyCorpus),
    'tmpl_heavy': _named(tmplHeavyCorpus),
    'large': _loadLarge(),
    'error': _named(errorCorpus),
  };
  for (final e in corpora.entries) {
    if (e.value.isEmpty ||
        !(tiers == 'all' || tiers.split(',').contains(e.key))) {
      continue;
    }
    final t = _timeTier(e.key, e.value, warmup, runs);
    result['tiers'][e.key] = t;
    if (e.key == 'ts_heavy') {
      result['segments'] = await _tsSegments(warmup, runs);
    }
  }
  final levels = concLevels > 0 ? [concLevels] : [1, 2, 4, 8];
  result['concurrency'] = await _concurrency(corpora['typical']!, levels, runs);
  final out = _strArg(args, '--out', '');
  if (out.isNotEmpty) {
    File(out).createSync(recursive: true);
    File(
      out,
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
    stdout.writeln('written $out');
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
}

Map<String, dynamic> _timeTier(
  String name,
  List<({String name, String src})> files,
  int warmup,
  int runs,
) {
  for (var i = 0; i < warmup; i++) {
    _compileAll(files.map((f) => f.src).toList());
  }
  final rssBefore = ProcessInfo.currentRss;
  final samples = <int>[];
  for (var i = 0; i < runs; i++) {
    final sw = Stopwatch()..start();
    _compileAll(files.map((f) => f.src).toList());
    samples.add(sw.elapsedMicroseconds);
  }
  final rssDelta = ProcessInfo.currentRss - rssBefore;
  samples.sort();
  final p50 = samples[samples.length ~/ 2];
  final p90 =
      samples[(samples.length * 0.9).floor().clamp(0, samples.length - 1)];
  final mean = samples.reduce((a, b) => a + b) ~/ samples.length;
  final stats = {
    'files': files.length,
    'bytes': files.fold<int>(0, (a, f) => a + f.src.length),
    'iter_us': {'p50': p50, 'p90': p90, 'mean': mean, 'min': samples.first},
    'files_per_s_p50': (files.length * 1e6 / p50).toStringAsFixed(1),
    'rss_delta_bytes': rssDelta,
  };
  stdout.writeln(
    '$name: p50=${(p50 / 1000).toStringAsFixed(2)}ms '
    '(${stats['files_per_s_p50']} files/s)',
  );
  return stats;
}

void _compileAll(List<String> sources) {
  for (var i = 0; i < sources.length; i++) {
    compileOne(sources[i], 'bench$i');
  }
}

/// Full SFC pipeline: parse -> script -> template -> styles.
/// Parse/compile errors count as completed work (the error tier measures
/// exactly this path); only unexpected crashes propagate.
void compileOne(String src, String name) {
  SfcDescriptor? d;
  try {
    d = SfcParser(src, filename: './$name.vue').parse();
  } on SfcError {
    return;
  }
  Map<String, String>? bindings;
  if (d.scriptSetup != null || d.script != null) {
    try {
      bindings = compileScriptSetup(d).bindings;
    } on SfcCompileError {
      return;
    } on TmplCompileError {
      return;
    }
  }
  final tpl = d.template;
  if (tpl != null) {
    try {
      compileTemplateSource(
        tpl.content,
        filename: './$name.vue',
        id: 'data-v-x',
        bindingMetadata: bindings,
      );
    } on TmplCompileError {
      return;
    }
  }
  for (final s in d.styles) {
    compileStyleSource(
      s.content,
      filename: './$name.vue',
      id: 'data-v-x',
      scoped: s.scoped,
    );
  }
}

/// FFI / mapper / full-chain segmentation over the ts_heavy scripts.
Future<Map<String, dynamic>> _tsSegments(int warmup, int runs) async {
  final scripts = <String>[];
  for (final s in tsHeavyCorpus) {
    final d = SfcParser(s, filename: './t.vue').parse();
    final code = d.scriptSetup?.content ?? '';
    if (code.isNotEmpty) scripts.add(code);
  }
  final oxc = OxcFFI.load();
  var payload = oxc.parseJson(scripts.first, 'ts');
  int ffiRun() {
    var n = 0;
    for (final s in scripts) {
      payload = OxcFFI.load().parseJson(s, 'ts');
      n += (payload['program']['body'] as List).length;
    }
    return n;
  }

  int mapperRun() {
    var n = 0;
    for (final s in scripts) {
      n += OxcMapper(s, language: 'ts').mapProgram(payload).children.length;
    }
    return n;
  }

  int chainRun() {
    var n = 0;
    final p = TSParser();
    for (final s in scripts) {
      n += p.parse(code: s, language: 'ts').children.length;
    }
    return n;
  }

  return {
    'scripts': scripts.length,
    'ffi_us': _micro(ffiRun, warmup, runs),
    'mapper_us': _micro(mapperRun, warmup, runs),
    'chain_us': _micro(chainRun, warmup, runs),
  };
}

Map<String, int> _micro(int Function() fn, int warmup, int runs) {
  for (var i = 0; i < warmup; i++) {
    fn();
  }
  final samples = <int>[];
  for (var i = 0; i < runs; i++) {
    final sw = Stopwatch()..start();
    fn();
    samples.add(sw.elapsedMicroseconds);
  }
  samples.sort();
  return {
    'p50': samples[samples.length ~/ 2],
    'mean': samples.reduce((a, b) => a + b) ~/ samples.length,
  };
}

/// Round-robin compilation across [levels] isolates; reports wall-clock
/// totals and speedup vs single-isolate.
Future<Map<String, dynamic>> _concurrency(
  List<({String name, String src})> files,
  List<int> levels,
  int runs,
) async {
  final sources = files.map((f) => f.src).toList();
  final out = <String, dynamic>{};
  final base = await _concOne(1, sources, runs);
  out['1'] = base;
  for (var i = 1; i < levels.length; i++) {
    final lvl = levels[i];
    final t = await _concOne(lvl, sources, runs);
    out['$lvl'] = t;
  }
  final t1 = out['1']['total_ms'] as num;
  for (final lvl in levels) {
    out['${lvl}_speedup'] = (t1 / (out['$lvl']['total_ms'] as num))
        .toStringAsFixed(2);
  }
  return out;
}

Future<Map<String, dynamic>> _concOne(
  int isolates,
  List<String> sources,
  int runs,
) async {
  // Warmup round absorbs isolate-spawn cost and JIT.
  await _fanOut(isolates, sources, 3);
  final sw = Stopwatch()..start();
  await _fanOut(isolates, sources, runs);
  sw.stop();
  return {'isolates': isolates, 'total_ms': sw.elapsedMilliseconds};
}

Future<void> _fanOut(int isolates, List<String> sources, int iters) async {
  await Future.wait([
    for (var k = 0; k < isolates; k++)
      Isolate.run(() {
        // Spawn once, loop inside: spawn cost must not drown the workload.
        for (var r = 0; r < iters; r++) {
          for (var i = k; i < sources.length; i += isolates) {
            compileOne(sources[i], 'c${k}_$i');
          }
        }
      }),
  ]);
}

List<({String name, String src})> _named(List<String> srcs) => [
  for (var i = 0; i < srcs.length; i++) (name: 'f$i', src: srcs[i]),
];

List<({String name, String src})> _loadTypical() {
  final raw = jsonDecode(File('batch_inputs.json').readAsStringSync()) as List;
  final sfcs = [
    for (final e in raw.cast<Map<String, dynamic>>())
      if (e['kind'] == 'sfc')
        (name: e['id'] as String, src: e['source'] as String),
  ]..sort((a, b) => b.src.length.compareTo(a.src.length));
  return sfcs.take(20).toList();
}

List<({String name, String src})> _loadLarge() {
  final out = <({String name, String src})>[];
  for (final m in [10, 50]) {
    final f = File('bench/corpus/large_$m.vue');
    if (f.existsSync()) {
      out.add((name: 'large_$m', src: f.readAsStringSync()));
    }
  }
  if (out.isEmpty) {
    stderr.writeln(
      'run `dart run bench/gen_large.dart` first for the large tier',
    );
  }
  return out;
}

Map<String, dynamic> _env() => {
  'dart': Platform.version,
  'os': Platform.operatingSystemVersion,
  'cores': Platform.numberOfProcessors,
  'mode': const bool.fromEnvironment('dart.vm.product') ? 'aot' : 'jit',
  'timestamp': DateTime.now().toIso8601String(),
};

int _intArg(List<String> args, String key, int def) {
  for (final a in args) {
    if (a.startsWith('$key=')) {
      return int.tryParse(a.split('=')[1]) ?? def;
    }
  }
  return def;
}

String _strArg(List<String> args, String key, String def) =>
    args.any((a) => a.startsWith('$key='))
    ? args.firstWhere((a) => a.startsWith('$key=')).split('=')[1]
    : def;
