import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';

void main() {
  group('FunctionDeclaration parsing', () {
    test('fromJson basic fields', () {
      final json = {
        'type': 'FunctionDeclaration',
        'id': {
          'type': 'Identifier',
          'name': 'foo',
        },
        'params': [
          {
            'type': 'Identifier',
            'name': 'x',
          },
        ],
        'body': {
          'type': 'BlockStatement',
          'body': [],
          'directives': [],
        },
        'generator': false,
        'async': false,
        'declare': false,
      };
      final node = TsAstFactory.fromJson(json) as FunctionDeclaration;
      expect(node.id?.name, 'foo');
      expect(node.params.length, 1);
      expect(node.generator, isFalse);
      expect(node.async, isFalse);
      expect(node.declare, isFalse);
    });
  });
}