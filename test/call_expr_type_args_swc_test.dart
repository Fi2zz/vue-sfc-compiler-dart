import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_script_parse.dart';
import 'package:vue_sfc_parser/sfc_module_to_compilation_unit.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';

void main() {
  group('CallExpression type args from SWC', () {
    test('type_ref alias - defineProps<Props>()', () {
      const code = r'''
type Props = { foo: string; bar?: number }
defineProps<Props>()
''';
      final res = sfcParseScript(code, language: 'ts');
      final unit = swcModuleToCompilationUnit(res.module, code);
      final calls = unit.statements
          .map((e) => e.expression)
          .whereType<FunctionCallExpression>()
          .toList();
      expect(calls, isNotEmpty);
      final c = calls.first;
      expect(c.methodName.name, 'defineProps');
      expect(c.typeArgumentText, isNotNull);
      expect(c.typeArgumentText!.contains('Props'), isTrue);
      // Props expanded may be empty for ref, but text exists
      // typeArgumentProps is populated only for type literal props
      // so here we accept empty
    });

    test('type_literal - defineProps<{ baz: boolean }>()', () {
      const code = r'''
defineProps<{ baz: boolean }>()
''';
      final res = sfcParseScript(code, language: 'ts');
      final unit = swcModuleToCompilationUnit(res.module, code);
      final calls = unit.statements
          .map((e) => e.expression)
          .whereType<FunctionCallExpression>()
          .toList();
      expect(calls, isNotEmpty);
      final c = calls.first;
      expect(c.methodName.name, 'defineProps');
      expect(c.typeArgumentText, isNotNull);
      expect(c.typeArgumentText!.contains('baz'), isTrue);
      expect(c.typeArgumentProps.length, 1);
      expect(c.typeArgumentProps.first.name, 'baz');
      expect(c.typeArgumentProps.first.required, isTrue);
    });

    test('generic fn collects type_argument_text', () {
      const code = r'''
function f<T>(a: T) { return a }
f<string>('x')
''';
      final res = sfcParseScript(code, language: 'ts');
      final unit = swcModuleToCompilationUnit(res.module, code);
      final calls = unit.statements
          .map((e) => e.expression)
          .whereType<FunctionCallExpression>()
          .toList();
      expect(calls.where((c) => c.typeArgumentText != null), isNotEmpty);
    });
  });
}
