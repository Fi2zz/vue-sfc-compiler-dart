import 'dart:io';
import 'package:vue_sfc_parser/sfc_parser.dart';
import 'package:vue_sfc_parser/template/compile_template.dart';
import 'package:vue_sfc_parser/template/dom_options.dart';
import 'package:vue_sfc_parser/template/tmpl_ast.dart';
import 'package:vue_sfc_parser/template/transform_context.dart';
import 'package:vue_sfc_parser/script/script_compile.dart';
import 'package:vue_sfc_parser/template/tmpl_parser.dart';
// import 'package:vue_sfc_parser/template/transform_options.dart';
// phase-level mirror of compileTemplateSource; options copied from
// compile_template.dart private builders (diagnostic only).

void main() {
  final src = File('bench/corpus/large_50.vue').readAsStringSync();
  final d = SfcParser(src, filename: './l.vue').parse();
  final content = d.template!.content;
  final b = compileScriptSetup(
    SfcParser(src, filename: './l.vue').parse(),
  ).bindings;

  TmplCompileResult run() => compileTemplateSource(
    content,
    filename: './l.vue',
    id: 'data-v-x',
    bindingMetadata: b,
  );
  for (var w = 0; w < 5; w++) {
    run();
  }
  var tFull = 0;
  const n = 30;
  var tParse = 0, tTransform = 0, tGen = 0;
  for (var i = 0; i < n; i++) {
    final errors = <TmplCompileError>[];
    final warnings = <TmplCompileError>[];
    var sw = Stopwatch()..start();
    final ast = baseParse(
      content,
      domParserOptions(prefixIdentifiers: true, onError: (e) {}),
    );
    tParse += sw.elapsedMicroseconds;
    sw..reset();
    // transform options replicated minimally but completely for timing parity
    final opts = TransformOptions()
      ..filename = './l.vue'
      ..prefixIdentifiers = true
      ..hoistStatic = true
      ..cacheHandlers = true
      ..hmr = true
      ..bindingMetadata = b!
      ..nodeTransforms = const []
      ..onError = errors.add
      ..onWarn = warnings.add;
    // full transform needs the real preset; fall back to timing via public API:
    sw.reset();
    final r2 = run();
    tTransform += 0; // placeholder, replaced below
    tGen += sw.elapsedMicroseconds;

    Stopwatch watch = Stopwatch()..start();

    watch.stop();
    int ms = watch.elapsedMicroseconds;
    tFull += ms;
    if (i == 0) {
      // count nodes for context
      var nodes = 0;
      void walk(TmplNode x) {
        nodes++;
        if (x is ElementNode) {
          for (final c in x.children) walk(c);
        }
      }

      for (final c in ast.children) walk(c);
      stdout.writeln(
        'template chars=${content.length} top-children=${ast.children.length} walked=$nodes result-code=${r2.code.length}',
      );
    }
  }
  stdout.writeln('full=${tFull ~/ n}us (parse-only=${tParse ~/ n}us)');
}
