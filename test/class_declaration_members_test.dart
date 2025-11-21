import 'package:test/test.dart';
import 'package:vue_sfc_parser/swc_ast.dart' as swc;

void main() {
  group('SWC ClassDeclaration enhanced fields', () {
    test('super/implements/decorators/members parsed', () {
      final json = {
        'body': [
          {
            'type': 'ClassDeclaration',
            'start': 0,
            'end': 10,
            'loc_start': {'line': 1, 'column': 0},
            'loc_end': {'line': 1, 'column': 10},
            'name': 'Foo',
            'super_class': 'Base',
            'implements': ['IFoo', 'IBar'],
            'decorators': ['@dec'],
            'members': [
              {'kind': 'Constructor'},
              {'kind': 'Method', 'key': 'm', 'is_static': false, 'async': true, 'generator': false},
              {'kind': 'Getter', 'key': 'n', 'is_static': true},
              {'kind': 'Setter', 'key': 'p', 'is_static': false},
              {'kind': 'Property', 'key': 'x', 'is_static': true},
              {'kind': 'StaticBlock'},
            ],
          }
        ],
      };
      final m = swc.swcModuleFromJson(json);
      final cls = m.body.first as swc.ClassDeclItem;
      expect(cls.name, 'Foo');
      expect(cls.superClass, 'Base');
      expect(cls.implements, ['IFoo', 'IBar']);
      expect(cls.decorators, ['@dec']);
      expect(cls.members!.length, 6);
      expect(cls.members![1].kind, 'Method');
      expect(cls.members![1].isAsync, isTrue);
      expect(cls.members![2].kind, 'Getter');
      expect(cls.members![2].isStatic, isTrue);
    });
  });
}