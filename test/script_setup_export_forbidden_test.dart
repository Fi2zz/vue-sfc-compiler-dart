import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_script_parse.dart';

void main() {
  group('<script setup> export forbidden', () {
    test('export named in setup throws', () {
      const code = 'export { a }';
      expect(
        () => sfcParseScript(
          code,
          language: 'ts',
          isScriptSetup: true,
          filename: './vue_complex.vue',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('export default in setup throws', () {
      const code = 'export default 1';
      expect(
        () => sfcParseScript(
          code,
          language: 'ts',
          isScriptSetup: true,
          filename: './vue_complex.vue',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
