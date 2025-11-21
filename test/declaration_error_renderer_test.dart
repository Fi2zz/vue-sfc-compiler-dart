import 'package:test/test.dart';
import 'package:vue_sfc_parser/error_report.dart';

void main() {
  group('Declaration error renderer', () {
    test('single position with context and caret', () {
      const src = '''
line 1
line 2
//@ts-ignore line 3
line 4 with error
line 5
''';
      final err = DeclarationParseError(
        filename: './vue_complex.vue',
        message: 'Syntax error in export default',
        positions: [ErrorPos(4, 10)],
        contextLines: 1,
        kind: 'export',
      );
      final out = ErrorRenderer.render(err, src);
      expect(out.contains('```'), isTrue);
      expect(out.contains('./vue_complex.vue:4:10'), isTrue);
      expect(out.contains('line 4 with error'), isTrue);
      expect(out.contains('          ^'), isTrue);
    });

    test('multi-position caret and ts-ignore annotation', () {
      const src = '''
line a
//@ts-ignore line b
line c problematic
line d
''';
      final err = DeclarationParseError(
        filename: './vue_complex.vue',
        message: 'Multiple errors',
        positions: [ErrorPos(2, 3), ErrorPos(3, 5)],
        contextLines: 1,
        kind: 'import',
      );
      final out = ErrorRenderer.render(err, src);
      expect(out.contains('line b'), isTrue);
      expect(out.contains('   ^'), isTrue);
    });
  });
}
