import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';

void main() {
  group('importedsToCode', () {
    test('named import', () {
      final map = <String, List<Imported>>{
        'c': [Imported('a', 'a', 'c', ImportType.import)],
      };
      final lines = importedsToCode(map);
      expect(lines, ['import { a } from "c";']);
    });

    test('named alias import', () {
      final map = <String, List<Imported>>{
        'c': [Imported('a', 'b', 'c', ImportType.import)],
      };
      final lines = importedsToCode(map);
      expect(lines, ['import { a as b } from "c";']);
    });

    test('mixed named imports with alias', () {
      final map = <String, List<Imported>>{
        'd': [
          Imported('a', 'a', 'd', ImportType.import),
          Imported('b', 'c', 'd', ImportType.import),
        ],
      };
      final lines = importedsToCode(map);
      expect(lines, ['import { a, b as c } from "d";']);
    });

    test('default only', () {
      final map = <String, List<Imported>>{
        'x': [Imported('Default', 'Default', 'x', ImportType.import_default)],
      };
      final lines = importedsToCode(map);
      expect(lines, ['import Default from "x";']);
    });

    test('namespace only', () {
      final map = <String, List<Imported>>{
        'x': [Imported('ns', 'ns', 'x', ImportType.import_ns)],
      };
      final lines = importedsToCode(map);
      expect(lines, ['import * as ns from "x";']);
    });

    test('default + named', () {
      final map = <String, List<Imported>>{
        'x': [
          Imported('Default', 'Default', 'x', ImportType.import_default),
          Imported('a', 'a', 'x', ImportType.import),
          Imported('b', 'c', 'x', ImportType.import),
        ],
      };
      final lines = importedsToCode(map);
      expect(lines, ['import Default, { a, b as c } from "x";']);
    });

    test('default + namespace + named (do not merge)', () {
      final map = <String, List<Imported>>{
        'x': [
          Imported('Default', 'Default', 'x', ImportType.import_default),
          Imported('ns', 'ns', 'x', ImportType.import_ns),
          Imported('a', 'a', 'x', ImportType.import),
        ],
      };
      final lines = importedsToCode(map);
      expect(
        lines,
        [
          'import * as ns from "x";',
          'import Default from "x";',
          'import { a } from "x";',
        ],
      );
    });
  });
}