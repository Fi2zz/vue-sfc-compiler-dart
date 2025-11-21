import 'package:test/test.dart';
import 'package:vue_sfc_parser/swc_ast.dart' as swc;

void main() {
  group('SWC new JSON shape', () {
    test('VariableDeclaration alignment', () {
      final json = {
        'body': [
          {
            'type': 'VariableDeclaration',
            'start': 0,
            'end': 20,
            'loc': {
              'start': {'line': 1, 'column': 0},
              'end': {'line': 1, 'column': 20},
              'filename': 'input.ts',
              'identifierName': null,
            },
            'decl_kind': 'const',
            'name': 'props',
            'name_span': {
              'start': 0,
              'end': 5,
              'loc_start': {'line': 1, 'column': 0},
              'loc_end': {'line': 1, 'column': 5},
            },
            'names': ['props'],
            'inited': true,
            'init_text': 'defineProps()',
            'init_callee_ident': 'defineProps',
            'type_parameters': null,
          },
        ],
      };
      final m = swc.swcModuleFromJson(json);
      final res = swc.analyzeSwcDeclarators(m);
      expect(res.length, 1);
      expect(res.first.declarationType, 'call');
      expect(res.first.initDetails['callee'], 'defineProps');
    });
  });
}
