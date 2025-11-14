import 'package:vue_sfc_parser/sfc_compiler.dart';
import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/sfc_macro.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';
import 'package:vue_sfc_parser/ts_parser.dart';

String compileScript(SfcDescriptor descriptor) {
  final source = descriptor.scriptSetup?.content ?? '';
  final language = descriptor.scriptSetup?.lang ?? 'js';
  final compilation = MacrosParser.parse(
    source,
    language: language,
  );
  final rootAst = TSParser().parse(
    code: source,
    language: language,
    namedOnly: true,
  );
  final result = SetupResult(
    compilation: compilation,
    rootAst: rootAst,
    source: source,
    filename: descriptor.filename,
  );
  return ScriptCodegen.generate(result: result);
}

String scriptCodeGenerate({required SetupResult result}) =>
    ScriptCodegen.generate(result: result);
