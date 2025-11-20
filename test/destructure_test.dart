import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_parser.dart';
import 'package:vue_sfc_parser/sfc_compile_script.dart';

void main() {
  group('destructure support', () {
    test('object destructure with default', () {
      const sfc = '<script setup>\nconst { x, ok = true } = { x: 1, ok: true }\n</script>';
      final parser = SfcParser(sfc, filename: 'destructure.vue');
      final desc = parser.parse();
      final out = compileScript(desc);
      expect(out.contains('const { x, ok = true }'), isTrue);
    });

    test('array destructure with default and rest', () {
      const sfc = '<script setup>\nconst [a = 1, b, ...rest] = [1, 2, 3]\n</script>';
      final parser = SfcParser(sfc, filename: 'arr.vue');
      final desc = parser.parse();
      final out = compileScript(desc);
      expect(out.contains('const [a = 1, b, ...rest]'), isTrue);
    });

    test('object destructure with alias and nested', () {
      const sfc = '<script setup>\nconst { p1: newName = 1, p2: { nested } } = { p1: 1, p2: { nested: 2 } }\n</script>';
      final parser = SfcParser(sfc, filename: 'obj.vue');
      final desc = parser.parse();
      final out = compileScript(desc);
      expect(out.contains('{ p1: newName = 1, p2: { nested } }'), isTrue);
    });
  });
}