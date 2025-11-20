import 'package:test/test.dart';
import 'package:vue_sfc_parser/ts_ast.dart';
import 'package:vue_sfc_parser/swc_ast.dart' as swc;

void main() {
  group('TS FunctionParent union detection', () {
    test('StaticBlock is function parent', () {
      final json = {
        'type': 'StaticBlock',
        'body': [],
      };
      final node = TsAstFactory.fromJson(json) as StaticBlock;
      expect(isFunctionParentNode(node), isTrue);
      expect(isFunctionNode(node), isFalse);
    });

    test('TSModuleBlock is function parent', () {
      final json = {
        'type': 'TSModuleBlock',
        'body': [],
      };
      final node = TsAstFactory.fromJson(json) as TSModuleBlock;
      expect(isFunctionParentNode(node), isTrue);
      expect(isFunctionNode(node), isFalse);
    });
  });

  group('SWC StaticBlock/TSModuleBlock parsing', () {
    test('StaticBlockItem parsed with bodyLen', () {
      final json = {
        'body': [
          {
            'type': 'StaticBlock',
            'span': {
              'start': 0,
              'end': 0,
              'loc_start': {'line': 1, 'column': 0},
              'loc_end': {'line': 1, 'column': 0}
            },
            'body_len': 3,
          }
        ]
      };
      final m = swc.moduleFromJson(json);
      expect(m.body.length, 1);
      final it = m.body.first as swc.StaticBlockItem;
      expect(it.bodyLen, 3);
    });

    test('TSModuleBlockItem parsed with bodyLen', () {
      final json = {
        'body': [
          {
            'type': 'TSModuleBlock',
            'span': {
              'start': 0,
              'end': 0,
              'loc_start': {'line': 1, 'column': 0},
              'loc_end': {'line': 1, 'column': 0}
            },
            'body_len': 2,
          }
        ]
      };
      final m = swc.moduleFromJson(json);
      expect(m.body.length, 1);
      final it = m.body.first as swc.TSModuleBlockItem;
      expect(it.bodyLen, 2);
    });
  });
}