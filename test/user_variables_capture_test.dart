import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_script_parse.dart';

void main() {
  group('UserVariables capture', () {
    test('captures name, type and defaultValue for simple variables', () {
      const code = """
const a = 1;
const b = 'x';
let c = true;
""";
      final res = sfcParseScript(code, language: 'ts');
      final vars = res.unit.userVariables;
      expect(vars.length, 3);
      expect(vars[0].name, 'a');
      expect(vars[0].type, 'Number');
      expect(vars[0].defaultValue, '1');

      expect(vars[1].name, 'b');
      expect(vars[1].type, 'String');
      expect(vars[1].defaultValue, "'x'" );

      expect(vars[2].name, 'c');
      expect(vars[2].type, 'Boolean');
    });
  });
}