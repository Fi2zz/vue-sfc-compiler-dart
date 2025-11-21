import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';
import 'package:vue_sfc_parser/sfc_script_codegen_helpers.dart';

CompilationUnit _unitVarInitIdentifier(String rhs) {
  final id = Identifier(startByte: 0, endByte: rhs.length, text: rhs);
  final decl = VariableDeclaration(
    id,
    startByte: 0,
    endByte: rhs.length,
    text: 'const x = $rhs',
    name: Identifier(startByte: 0, endByte: 1, text: 'x'),
  );
  final st = ExpressionStatement(startByte: 0, endByte: rhs.length, text: decl.text, expression: decl);
  return CompilationUnit(startByte: 0, endByte: rhs.length, text: decl.text, statements: [st]);
}

void main() {
  group('VariableDeclaration defineProps/withDefaults fallback', () {
    test('defineProps with type arg', () {
      final unit = _unitVarInitIdentifier('defineProps<{ msg: string }>()');
      final props = CodegenHelpers.extractDefineProps(unit);
      expect(props, isNotNull);
      expect(props!, contains('msg'));
      expect(props, contains('String'));
    });

    test('withDefaults + type arg', () {
      final unit = _unitVarInitIdentifier('withDefaults(defineProps<{ msg: string }>(), { msg: "hi" })');
      final props = CodegenHelpers.extractDefineProps(unit);
      expect(props, isNotNull);
      expect(props!, contains('msg'));
      expect(props, contains('default: "hi"'));
    });
  });
}