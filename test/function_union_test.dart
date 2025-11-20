import 'package:test/test.dart';
import 'package:vue_sfc_parser/ts_ast.dart';
import 'package:vue_sfc_parser/swc_ast.dart' as swc;

void main() {
  group('TS Function union detection', () {
    test('ArrowFunctionExpression is function', () {
      final json = {
        'type': 'ArrowFunctionExpression',
        'params': [
          {'type': 'Identifier', 'name': 'x'},
        ],
        'body': {
          'type': 'BlockStatement',
          'body': [],
          'directives': [],
        },
        'async': true,
        'expression': false,
      };
      final node = TsAstFactory.fromJson(json) as ArrowFunctionExpression;
      expect(isFunctionNode(node), isTrue);
      expect(node.async, isTrue);
      expect(node.expression, isFalse);
    });
  });

  group('SWC FnDecl analysis', () {
    test('FnDeclItem recognized as function_declaration', () {
      final json = {
        'body': [
          {
            'type': 'FnDecl',
            'span': {
              'start': 0,
              'end': 10,
              'loc_start': {'line': 1, 'column': 0},
              'loc_end': {'line': 1, 'column': 10}
            },
            'name': 'foo',
            'text': 'function foo(){}',
          }
        ]
      };
      final m = swc.moduleFromJson(json);
      final res = swc.analyzeSwcDeclarators(m);
      expect(res.length, 1);
      expect(res.first.declarationType, 'function_declaration');
      expect(res.first.identifier, 'foo');
    });
  });
}