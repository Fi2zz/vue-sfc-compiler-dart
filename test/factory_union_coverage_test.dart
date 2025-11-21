import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_ast.dart' as ts;

void main() {
  group('TsAstFactory union coverage', () {
    test('TemplateLiteral dispatch', () {
      final json = {
        'type': 'TemplateLiteral',
        'quasis': [
          {
            'type': 'TemplateElement',
            'value': {'raw': 'a', 'cooked': 'a'},
            'tail': false,
          },
          {
            'type': 'TemplateElement',
            'value': {'raw': 'b', 'cooked': 'b'},
            'tail': true,
          }
        ],
        'expressions': [
          {'type': 'Identifier', 'name': 'x'}
        ],
      };
      final node = ts.TsAstFactory.fromJson(json);
      expect(node is ts.TemplateLiteral, isTrue);
    });

    test('TaggedTemplateExpression dispatch', () {
      final json = {
        'type': 'TaggedTemplateExpression',
        'tag': {'type': 'Identifier', 'name': 'tagFn'},
        'quasi': {
          'type': 'TemplateLiteral',
          'quasis': [
            {
              'type': 'TemplateElement',
              'value': {'raw': 'x', 'cooked': 'x'},
              'tail': true,
            }
          ],
          'expressions': [],
        }
      };
      final node = ts.TsAstFactory.fromJson(json);
      expect(node is ts.TaggedTemplateExpression, isTrue);
    });

    test('OptionalCallExpression dispatch', () {
      final json = {
        'type': 'OptionalCallExpression',
        'callee': {'type': 'Identifier', 'name': 'fn'},
        'arguments': [],
        'optional': true,
      };
      final node = ts.TsAstFactory.fromJson(json);
      expect(node is ts.OptionalCallExpression, isTrue);
    });

    test('OptionalMemberExpression dispatch', () {
      final json = {
        'type': 'OptionalMemberExpression',
        'object': {'type': 'Identifier', 'name': 'obj'},
        'property': {'type': 'Identifier', 'name': 'prop'},
        'computed': false,
        'optional': true,
      };
      final node = ts.TsAstFactory.fromJson(json);
      expect(node is ts.OptionalMemberExpression, isTrue);
    });
  });
}