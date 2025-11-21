import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_script_parse.dart';
import 'package:vue_sfc_parser/sfc_ast.dart' as ts;

void main() {
  group('CompilationUnit moduleDeclarations parsing & validation', () {
    test('ImportDeclaration default/named/namespace/type', () {
      const code = """
import foo from './a';
import { a, b as c } from "./b";
import * as ns from '../c';
import type { T } from '/abs';
""";
      final res = sfcParseScript(code, language: 'ts');
      final decls = res.unit.imported;
      expect(decls.length, 4);
      expect(decls[0] is ts.ImportDeclaration, true);
      expect(decls[1] is ts.ImportDeclaration, true);
      expect(decls[2] is ts.ImportDeclaration, true);
      expect(decls[3] is ts.ImportDeclaration, true);
    });

    test('ExportAllDeclaration & ExportNamedDeclaration', () {
      const code = """
export * from './m';
export { a, b as c } from "./n";
""";
      final res = sfcParseScript(code, language: 'ts');
      final decls = res.unit.exported;
      expect(decls.length, 2);
      expect(decls[0] is ts.ExportAllDeclaration, true);
      expect(decls[1] is ts.ExportNamedDeclaration, true);
    });

    test('ExportDefaultDeclaration', () {
      const code = """
export default {};
""";
      final res = sfcParseScript(code, language: 'ts');
      final decls = res.unit.exported;
      expect(decls.length, 1);
      expect(decls.first is ts.ExportDefaultDeclaration, true);
    });

    test('Invalid import syntax throws', () {
      const code = """
import * bad from './x';
""";
      expect(
        () => sfcParseScript(code, language: 'ts'),
        throwsA(isA<StateError>()),
      );
    });

    test('Combination of different declarations', () {
      const code = """
import foo from './a';
export * from './m';
export { foo as bar } from './a';
export default foo;
""";
      final res = sfcParseScript(code, language: 'ts');
      final decls = res.unit.exported;
      expect(decls.length, 3);
    });
  });
}
