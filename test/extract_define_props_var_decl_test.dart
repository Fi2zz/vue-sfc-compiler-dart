import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';
import 'package:vue_sfc_parser/sfc_script_codegen_helpers.dart';

CompilationUnit _unitWithVarDeclInit(String initText, {bool destructure = false}) {
  final id = Identifier(startByte: 0, endByte: 0, text: initText);
  final decl = VariableDeclaration(
    id,
    startByte: 0,
    endByte: 0,
    text: 'const x = $initText',
    name: Identifier(startByte: 0, endByte: 0, text: 'x'),
    pattern: destructure
        ? ObjectBindingPattern(
            startByte: 0,
            endByte: 0,
            text: '{ a, b }',
            properties: const [],
          )
        : null,
  );
  final st = ExpressionStatement(startByte: 0, endByte: 0, text: decl.text, expression: decl);
  return CompilationUnit(startByte: 0, endByte: 0, text: decl.text, statements: [st]);
}

void main() {
  group('extractDefineProps variable declaration fallback', () {
    test('const props = defineProps<...>() returns {}', () {
      final unit = _unitWithVarDeclInit('defineProps<{}>()');
      final props = CodegenHelpers.extractDefineProps(unit);
      expect(props, '{}');
    });
    test('const {a,b} = defineProps<...>() returns {}', () {
      final unit = _unitWithVarDeclInit('defineProps<{}>()', destructure: true);
      final props = CodegenHelpers.extractDefineProps(unit);
      expect(props, '{}');
    });
    test('const props = withDefaults(defineProps<...>(), {}) returns {}', () {
      final unit = _unitWithVarDeclInit('withDefaults(defineProps<{}>(), {})');
      final props = CodegenHelpers.extractDefineProps(unit);
      expect(props, '{}');
    });
  });
}