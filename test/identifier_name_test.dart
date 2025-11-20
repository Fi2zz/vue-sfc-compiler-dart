import 'package:test/test.dart';
import 'package:vue_sfc_parser/ts_ast.dart';
import 'package:vue_sfc_parser/swc_ast.dart' as swc;

void main() {
  group('Identifier.name parsing', () {
    test('simple identifier', () {
      final id = Identifier(startByte: 0, endByte: 0, text: 'props');
      expect(id.name, 'props');
    });
    test('function call bare', () {
      final id = Identifier(startByte: 0, endByte: 0, text: 'defineProps()');
      expect(id.name, 'defineProps');
    });
    test('member call', () {
      final id = Identifier(startByte: 0, endByte: 0, text: 'Vue.defineEmits<{}>()');
      expect(id.name, 'defineEmits');
    });
    test('chained call uses current call', () {
      final id = Identifier(startByte: 0, endByte: 0, text: 'obj.method().another()');
      expect(id.name, 'method');
    });
    test('property access', () {
      final id = Identifier(startByte: 0, endByte: 0, text: 'ns.defineSlots');
      expect(id.name, 'defineSlots');
    });
  });

  group('SWC CallExpr calleeIdent extraction', () {
    test('fallback to parsed name from text', () {
      final json = {
        'body': [
          {
            'type': 'CallExpr',
            'span': {
              'start': 0,
              'end': 10,
              'loc_start': {'line': 1, 'column': 0},
              'loc_end': {'line': 1, 'column': 10}
            },
            'callee_ident': null,
            'args': [],
            'type_args': null,
            'text': 'Vue.defineProps()'
          }
        ]
      };
      final m = swc.moduleFromJson(json);
      final item = m.body.first as swc.CallExpr;
      expect(item.calleeIdent, 'defineProps');
    });
  });
}