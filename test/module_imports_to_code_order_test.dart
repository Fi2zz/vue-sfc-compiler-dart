import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_script_parse.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';

void main() {
  group('moduleImportsToCode preserves order', () {
    test(
      'namespace then default from same source in separate declarations',
      () {
        const code = """
import * as bug from 'vue'
import vue from 'vue'
""";
        final res = sfcParseScript(code, language: 'js');
        final lines = moduleImportsToCode(res.unit.imported);
        expect(lines, [
          'import * as bug from "vue";',
          'import vue from "vue";',
        ]);
      },
    );

    test('default + named in one declaration', () {
      const code = "import foo, { a, b as c } from 'x'";
      final res = sfcParseScript(code, language: 'js');
      final lines = moduleImportsToCode(res.unit.imported);
      expect(lines, ['import foo, { a, b as c } from "x";']);
    });
  });
}
