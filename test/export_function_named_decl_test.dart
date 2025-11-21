import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_script_parse.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';

void main() {
  group('export function named declaration', () {
    test('export function hello() {} recognized as named export', () {
      const code = 'export function hello() {}';
      final res = sfcParseScript(code, language: 'ts');
      final decls = res.unit.exported.whereType<ExportNamedDeclaration>().toList();
      expect(decls.isNotEmpty, isTrue);
      final specs = decls.first.specifiers.whereType<ExportSpecifier>().toList();
      expect(specs.length, 1);
      expect((specs.first.exported as Identifier).name, 'hello');
      expect(specs.first.local.name, 'hello');
      expect(decls.first.source, isNull);
    });

    test('mixed export function and named specifiers', () {
      const code = 'export function hello() {}\nexport { a as b }';
      final res = sfcParseScript(code, language: 'ts');
      final decls = res.unit.exported.whereType<ExportNamedDeclaration>().toList();
      expect(decls.length, 2);
      final fnSpecs = decls[0].specifiers.whereType<ExportSpecifier>().toList();
      final specSpecs = decls[1].specifiers.whereType<ExportSpecifier>().toList();
      expect((fnSpecs.first.exported as Identifier).name, 'hello');
      expect((specSpecs.first.exported as Identifier).name, 'b');
    });
  });
}