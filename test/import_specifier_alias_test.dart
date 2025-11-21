import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_script_parse.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';

void main() {
  group('ImportSpecifier alias handling', () {
    test('basic named import', () {
      const code = "import { a } from 'c'";
      final res = sfcParseScript(code, language: 'js');
      final mods = res.unit.imported;
      expect(mods.whereType<ImportDeclaration>().length, 1);
      final decl = mods.whereType<ImportDeclaration>().first;
      expect(decl.specifiers.length, 1);
      final spec = decl.specifiers.first as ImportSpecifier;
      expect(spec.local.name, 'a');
      expect((spec.imported as Identifier).name, 'a');
    });

    test('named import with alias', () {
      const code = "import { a as b } from 'c'";
      final res = sfcParseScript(code, language: 'js');
      final decl = res.unit.imported.whereType<ImportDeclaration>().first;
      final spec = decl.specifiers.first as ImportSpecifier;
      expect(spec.local.name, 'b');
      expect((spec.imported as Identifier).name, 'a');
    });

    test('mixed named imports with alias', () {
      const code = "import { a, b as c } from 'd'";
      final res = sfcParseScript(code, language: 'js');
      final decl = res.unit.imported.whereType<ImportDeclaration>().first;
      expect(decl.specifiers.length, 2);
      final s0 = decl.specifiers[0] as ImportSpecifier;
      final s1 = decl.specifiers[1] as ImportSpecifier;
      expect(s0.local.name, 'a');
      expect((s0.imported as Identifier).name, 'a');
      expect(s1.local.name, 'c');
      expect((s1.imported as Identifier).name, 'b');
    });
  });
}
