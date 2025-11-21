import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';
import 'package:vue_sfc_parser/swc_ast.dart' as swc;

void main() {
  group('TS Class union', () {
    test('ClassDeclaration isClassNode', () {
      final json = {
        'type': 'ClassDeclaration',
        'id': {'type': 'Identifier', 'name': 'Foo'},
        'body': {'type': 'ClassBody', 'body': []},
      };
      final node = TsAstFactory.fromJson(json) as ClassDeclaration;
      expect(isClassNode(node), isTrue);
      expect(node.id?.name, 'Foo');
    });

    test('ClassExpression isClassNode', () {
      final json = {
        'type': 'ClassExpression',
        'body': {'type': 'ClassBody', 'body': []},
      };
      final node = TsAstFactory.fromJson(json) as ClassExpression;
      expect(isClassNode(node), isTrue);
    });
  });

  group('SWC Class union', () {
    test('ClassDeclItem isSwcClassItem', () {
      final json = {
        'body': [
          {
            'type': 'ClassDecl',
            'span': {
              'start': 0,
              'end': 1,
              'loc_start': {'line': 1, 'column': 0},
              'loc_end': {'line': 1, 'column': 1},
            },
            'name': 'Foo',
          },
        ],
      };
      final m = swc.swcModuleFromJson(json);
      expect(m.body.length, 1);
      expect(swc.isSwcClassItem(m.body.first), isTrue);
    });
  });
}
