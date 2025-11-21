import 'package:test/test.dart';
import 'package:vue_sfc_parser/swc_ast.dart' as swc;

void main() {
  group('SWC FunctionDeclaration enhanced fields', () {
    test('async/generator/params/returnType parsed', () {
      final json = {
        'body': [
          {
            'type': 'FunctionDeclaration',
            'start': 0,
            'end': 10,
            'loc_start': {'line': 1, 'column': 0},
            'loc_end': {'line': 1, 'column': 10},
            'name': 'foo',
            'text': 'function foo(a=1,...rest): number {}',
            'async': true,
            'generator': true,
            'return_type': 'number',
            'params': [
              {'name': 'a', 'default_text': '1', 'is_rest': false, 'type_ann_text': null},
              {'name': 'rest', 'default_text': null, 'is_rest': true, 'type_ann_text': null},
            ],
          }
        ],
      };
      final m = swc.swcModuleFromJson(json);
      final fn = m.body.first as swc.FnDeclItem;
      expect(fn.name, 'foo');
      expect(fn.isAsync, isTrue);
      expect(fn.isGenerator, isTrue);
      expect(fn.returnTypeText, 'number');
      expect(fn.params!.length, 2);
      expect(fn.params![0].name, 'a');
      expect(fn.params![0].defaultText, '1');
      expect(fn.params![1].isRest, isTrue);
    });
  });
}