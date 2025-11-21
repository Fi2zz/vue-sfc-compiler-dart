import 'dart:io';
import 'dart:async';

import 'package:vue_sfc_parser/sfc_compile_script.dart';
import 'package:vue_sfc_parser/sfc_parser.dart';

const filename = "./vue_complex.vue";
// ignore: non_constant_identifier_names
File vue_complex = File(filename);
File outfile = File("vue_complex_dart.ts");

class Sample {
  final String name;
  final String sfc;
  Sample({required this.name, required this.sfc});
  static Sample fromJson(Map<String, dynamic> json) {
    return Sample(name: json['name'] as String, sfc: json['sfc'] as String);
  }
}

/// Entry point for compiling the sample Vue SFC using the Dart compiler pipeline.
///
/// Stages:
/// 1. Read input SFC
/// 2. Parse into `SfcDescriptor`
/// 3. Compile script portion into TypeScript code
/// 4. Write output file
///
/// Debug logging is enabled to trace progress, timing, and basic resource usage.
Future<void> main() async {
  try {
    final sw = Stopwatch()..start();
    _log('start');
    _logResources('init');

    final raw = vue_complex.readAsStringSync();
    _log('read file ok: ${vue_complex.path} (${raw.length} chars)');
    _logResources('after-read');

    final parser = SfcParser(raw, filename: filename);
    _log('parser constructed');

    final descriptor = parser.parse();
    _log(
      'descriptor parsed: has scriptSetup=${descriptor.scriptSetup != null} has script=${descriptor.script != null}',
    );
    _logResources('after-parse');

    String code = compileScript(descriptor).trim();
    _log('compileScript done: ${code.length} chars');
    _logResources('after-compile');

    //     String md =
    //         """
    // ```ts\n$code\n```
    // """
    //             .trim();
    outfile.writeAsString(code.trim());
    _log('write ok: ${outfile.path}');
    _logResources('after-write');
    sw.stop();
    _log('done in ${sw.elapsedMilliseconds}ms');
    print('vue-compiler-dart ok');
  } catch (error) {
    _log('error: $error');
    stderr.writeln('error $error');
  }
}

/// Print a structured debug line with timestamp.
void _log(String msg) {}

/// Capture basic resource usage (RSS and CPU %) for the current process.
Future<void> _logResources(String stage) async {
  try {
    final rss = ProcessInfo.currentRss;
    final res = await Process.run('ps', [
      '-p',
      '$pid',
      '-o',
      '%cpu=,%mem=,rss=',
    ]);
    final cpuMem = (res.stdout is String)
        ? (res.stdout as String).trim()
        : '${res.stdout}';
    _log('resources [$stage] rss=${_fmtBytes(rss)} cpu/mem/rss=${cpuMem}');
  } catch (_) {
    // best-effort; ignore failures on platforms without ps
  }
}

String _fmtBytes(int n) {
  if (n < 1024) return '${n}B';
  final kb = n / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)}KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)}MB';
}
