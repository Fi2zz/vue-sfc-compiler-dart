import 'package:test/test.dart';
import 'package:vue_sfc_parser/ast.dart';
import 'package:vue_sfc_parser/code_printer.dart';
import 'package:vue_sfc_parser/parse_script.dart';

void main() {
  group('roundtrip: imports', () {
    test('default + named + namespace import equality', () {
      final src = [
        'import Default, { A, B as C } from "mod";',
        'import * as NS from "ns_mod";',
        'import { X, Y as Z } from "pkg";',
        '',
      ].join('\n');
      final pr = parseScript(src, language: 'ts');
      final sanitized = CompilationUnit(
        statements: const [],
        imported: pr.unit.imported,
        exported: const [],
        comments: pr.unit.comments,
      );
      final cuOutput = CodePrinter.printCompilationUnit(sanitized);
      expect(cuOutput, equals(src));
    });
  });

  group('roundtrip: exports', () {
    test('named + namespace + all + default export equality', () {
      final src = [
        'export { A, B as C };',
        'export * as NS from "mod";',
        'export * from "all";',
        'export default null',
        '',
      ].join('\n');
      final pr = parseScript(src, language: 'ts');
      final sanitized = CompilationUnit(
        statements: const [],
        imported: const [],
        exported: pr.unit.exported,
        comments: pr.unit.comments,
      );
      final cuOutput = CodePrinter.printCompilationUnit(sanitized);
      expect(cuOutput, equals(src));
    });
  });

  group('roundtrip: variables and calls', () {
    test('declarations, destructure patterns, function call equality', () {
      final src = [
        'const x = 1;',
        'doWork({ opt: 1 }, "x", 2);',
        '',
      ].join('\n');
      final pr = parseScript(src, language: 'ts');
      final cuOutput = CodePrinter.printCompilationUnit(pr.unit);
      expect(cuOutput, equals(src));
    });
  });

  group('roundtrip: comments and source map', () {
    test('compilation unit comments printed and mappings sane', () {
      final unit = CompilationUnit(
        statements: [
          ExpressionStatement(
            expression: Identifier(name: 'x'),
            loc: Location(
              start: Position(line: 1, column: 0, index: 0),
              end: Position(line: 1, column: 1, index: 1),
              filename: 'inmem.ts',
            ),
          ),
        ],
        imported: const [],
        exported: const [],
        comments: const [
          CommentLine(
            value: 'top comment',
            loc: Location(
              start: Position(line: 1, column: 0, index: 0),
              end: Position(line: 1, column: 14, index: 14),
              filename: 'inmem.ts',
            ),
          ),
        ],
      );
      final generated = CodePrinter.printCompilationUnitWithSourceMap(unit);
      expect(generated.code.contains('// top comment'), isTrue);
      expect(generated.code.contains('x'), isTrue);
      expect(generated.mappings.length, equals(2));
      for (final m in generated.mappings) {
        expect(m.generatedEnd > m.generatedStart, isTrue);
        expect(m.originalEnd >= m.originalStart, isTrue);
      }
    });
  });
}
