import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_script_parse.dart';

void main() {
  group('normal <script> duplicate export default forbidden', () {
    test('two export default throws', () {
      const code = 'export default function A(){}\nexport default 1';
      expect(
        () => sfcParseScript(
          code,
          language: 'ts',
          isScriptSetup: false,
          filename: './vue_complex.vue',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
