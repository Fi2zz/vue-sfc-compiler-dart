import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_script_parse.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';

void main() {
  group('moduleExportsToCode', () {
    test('default export expression', () {
      const code = 'export default 1';
      final res = sfcParseScript(code, language: 'ts');
      final lines = moduleExportsToCode(res.unit.exported);
      expect(lines, ['export default 1;']);
    });

    test('named local export', () {
      const code = 'const a=1; export { a }';
      final res = sfcParseScript(code, language: 'ts');
      final lines = moduleExportsToCode(res.unit.exported);
      expect(lines, ['export { a };']);
    });

    test('named alias export', () {
      const code = 'const a=1; export { a as b }';
      final res = sfcParseScript(code, language: 'ts');
      final lines = moduleExportsToCode(res.unit.exported);
      expect(lines, ['export { a as b };']);
    });

    test('re-export named from source', () {
      const code = 'export { a } from "./m"';
      final res = sfcParseScript(code, language: 'ts');
      final lines = moduleExportsToCode(res.unit.exported);
      expect(lines, ['export { a } from "./m";']);
    });

    test('export all from source', () {
      const code = 'export * from "./m"';
      final res = sfcParseScript(code, language: 'ts');
      final lines = moduleExportsToCode(res.unit.exported);
      expect(lines, ['export * from "./m";']);
    });
  });
}