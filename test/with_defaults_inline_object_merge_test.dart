import 'package:test/test.dart';
import 'package:vue_sfc_parser/ts_ast.dart';
import 'package:vue_sfc_parser/sfc_script_codegen_helpers.dart';

void main() {
  test('withDefaults merges defaults into inline object props', () {
    // defineProps({ msg: String })
    final typeEntry = MapLiteralEntry(
      startByte: 0,
      endByte: 0,
      text: 'msg: String',
      keyText: 'msg',
      value: Identifier(startByte: 0, endByte: 0, text: 'String'),
    );
    final inlineObj = SetOrMapLiteral(
      startByte: 0,
      endByte: 0,
      text: '{ msg: String }',
      elements: [typeEntry],
    );
    final definePropsCall = FunctionCallExpression(
      startByte: 0,
      endByte: 0,
      text: 'defineProps({ msg: String })',
      methodName: Identifier(startByte: 0, endByte: 0, text: 'defineProps'),
      argumentList: ArgumentList(
        startByte: 0,
        endByte: 0,
        text: '',
        arguments: [inlineObj],
      ),
    );

    // defaults: { msg: 'hi' }
    final defEntry = MapLiteralEntry(
      startByte: 0,
      endByte: 0,
      text: "msg: 'hi'",
      keyText: 'msg',
      value: StringLiteral(
        startByte: 0,
        endByte: 0,
        text: "'hi'",
        stringValue: 'hi',
      ),
    );
    final defaultsObj = SetOrMapLiteral(
      startByte: 0,
      endByte: 0,
      text: "{ msg: 'hi' }",
      elements: [defEntry],
    );

    final withDefaultsCall = FunctionCallExpression(
      startByte: 0,
      endByte: 0,
      text: "withDefaults(defineProps({ msg: String }), { msg: 'hi' })",
      methodName: Identifier(startByte: 0, endByte: 0, text: 'withDefaults'),
      argumentList: ArgumentList(
        startByte: 0,
        endByte: 0,
        text: '',
        arguments: [definePropsCall, defaultsObj],
      ),
    );

    final st = ExpressionStatement(
      startByte: 0,
      endByte: 0,
      text: withDefaultsCall.text,
      expression: withDefaultsCall,
    );
    final unit = CompilationUnit(
      startByte: 0,
      endByte: 0,
      text: withDefaultsCall.text,
      statements: [st],
    );

    final props = CodegenHelpers.extractDefineProps(unit);
    expect(props, contains('msg'));
    expect(props, contains('type: String'));
    expect(props, contains('default: "hi"'));
  });
}
