// Scratch probe: per-stage timing on large corpus (not part of bench suite).
import 'dart:io';
import 'package:vue_sfc_parser/sfc_parser.dart';
import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/script/script_compile.dart';
import 'package:vue_sfc_parser/template/compile_template.dart';
import 'package:vue_sfc_parser/sfc_compile_style.dart';

void main() {
  final src = File('bench/corpus/large_50.vue').readAsStringSync();
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

  late SfcDescriptor d;
  final tParse = timeStage(() {
    d = SfcParser(src, filename: './large_50.vue').parse();
  });
  final tScript = timeStage(() {
    compileScriptSetup(d);
  });
  final tTemplate = timeStage(() {
    compileTemplateSource(
      d.template!.content,
      filename: './large_50.vue',
      id: 'data-v-x',
    );
  });
  final tStyle = timeStage(() {
    for (final s in d.styles) {
      compileStyleSource(
        s.content,
        filename: './large_50.vue',
        id: 'data-v-x',
        scoped: s.scoped,
      );
    }
  });
  stdout.writeln(
    'parse=$tParse script=$tScript template=$tTemplate style=$tStyle (us/iter)',
  );
}
