import 'package:test/test.dart';
import 'package:vue_sfc_parser/swc_ast.dart';

void main() {
  group('SWC Node location accessors and finders', () {
    test('node getters reflect locStart/locEnd', () {
      final json = {
        'body': [
          {
            'type': 'ImportDeclaration',
            'start': 0,
            'end': 10,
            'loc': {
              'start': {'line': 1, 'column': 0},
              'end': {'line': 1, 'column': 10}
            },
            'src': 'x',
            'specifiers': []
          }
        ]
      };
      final m = swcModuleFromJson(json);
      final it = m.body.first as ImportDecl;
      expect(it.node.lineNumber, 1);
      expect(it.node.columnNumber, 0);
      expect(it.node.endLineNumber, 1);
      expect(it.node.endColumnNumber, 10);
    });

    test('find items by start line', () {
      final json = {
        'body': [
          {
            'type': 'ImportDeclaration',
            'start': 0,
            'end': 10,
            'loc': {
              'start': {'line': 1, 'column': 0},
              'end': {'line': 1, 'column': 10}
            },
            'src': 'x',
            'specifiers': []
          },
          {
            'type': 'ExportDefaultDeclaration',
            'start': 11,
            'end': 20,
            'loc': {
              'start': {'line': 2, 'column': 0},
              'end': {'line': 2, 'column': 9}
            }
          }
        ]
      };
      final m = swcModuleFromJson(json);
      final line1 = findItemsByStartLine(m, 1);
      final line2 = findItemsByStartLine(m, 2);
      expect(line1.length, 1);
      expect(line2.length, 1);
      expect(printNodeWithLocation(line1.first).contains('1:0-1:10'), isTrue);
      expect(printNodeWithLocation(line2.first).contains('2:0-2:9'), isTrue);
    });
  });
}