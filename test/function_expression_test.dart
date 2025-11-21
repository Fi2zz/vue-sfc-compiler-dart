import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';

void main() {
  group('FunctionExpression parsing and analysis', () {
    test('fromJson matches ast.ts shape', () {
      final json = {
        'type': 'FunctionExpression',
        'id': {
          'type': 'Identifier',
          'name': 'fn',
        },
        'params': [
          {
            'type': 'Identifier',
            'name': 'x',
          }
        ],
        'body': {
          'type': 'BlockStatement',
          'body': [],
          'directives': [],
        },
        'generator': false,
        'async': true,
      };
      final node = TsAstFactory.fromJson(json) as FunctionExpression;
      expect(node.id?.name, 'fn');
      expect(node.params.length, 1);
      expect(node.async, isTrue);
      expect(node.generator, isFalse);
    });

    test('analyzeTsDeclarators recognizes FunctionExpression init', () {
      final func = FunctionExpression(
        id: Identifier(name: 'fn'),
        params: [Identifier(name: 'x')],
        body: BlockStatement(body: const [], directives: const []),
        generator: false,
        async: true,
      );
      final decl = VariableDeclaration(
        func,
        name: Identifier(name: 'f'),
      );
      final unit = CompilationUnit(
        startByte: 0,
        endByte: 0,
        text: 'const f = function fn(x) {}',
        statements: [
          ExpressionStatement(expression: decl),
        ],
      );
      final res = analyzeTsDeclarators(unit);
      expect(res.length, 1);
      expect(res.first.declarationType, 'function_expression');
      expect(res.first.initDetails['paramsCount'], 1);
      expect(res.first.initDetails['async'], true);
    });
  });
}