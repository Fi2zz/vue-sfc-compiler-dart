import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';
import 'package:vue_sfc_parser/sfc_compiler.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';

void main() {
  group('StatementPrinter setup body', () {
    test('prints basic variable and call equal to slice', () {
      final srcLines = <String>[
        'const a = 1;',
        'doSomething("x");',
      ];
      final src = srcLines.join('\n');
      final st0 = ExpressionStatement(
        expression: VariableDeclaration(
          NumberLiteral(value: 1),
          name: Identifier(name: 'a'),
          declKind: 'const',
        ),
        startByte: 0,
        endByte: srcLines[0].length,
      );
      final st1Start = srcLines[0].length + 1;
      final st1 = ExpressionStatement(
        expression: FunctionCallExpression(
          methodName: Identifier(name: 'doSomething'),
          argumentList: ArgumentList(arguments: [
            StringLiteral(value: 'x', stringValue: 'x'),
          ]),
        ),
        startByte: st1Start,
        endByte: st1Start + srcLines[1].length,
      );
      final unit = CompilationUnit(
        statements: [st0, st1],
        imported: const [],
        exported: const [],
        userVariables: const [],
      );
      final prepared = Prepared(
        language: 'ts',
        setup: unit,
        source: src,
        filename: 'Comp.vue',
      );
      final outAst = ScriptCodegen.generate(prepared: prepared, useAstPrinter: true);
      final outSlice = ScriptCodegen.generate(prepared: prepared, useAstPrinter: false);
      expect(outAst, equals(outSlice));
      expect(outAst, contains('const a = 1;'));
      expect(outAst, contains('doSomething("x");'));
    });

    test('prints destructuring equal to slice', () {
      final srcLines = <String>[
        'const {x = 1, y} = foo();',
        'const [m = 2, n] = bar();',
      ];
      final src = srcLines.join('\n');
      final obpX = ObjectBindingProperty(
        key: 'x',
        defaultValue: NumberLiteral(value: 1),
      );
      final obpY = ObjectBindingProperty(key: 'y');
      final st0 = ExpressionStatement(
        expression: VariableDeclaration(
          FunctionCallExpression(
            methodName: Identifier(name: 'foo'),
            argumentList: ArgumentList(arguments: const []),
          ),
          name: Identifier(name: ''),
          declKind: 'const',
          pattern: ObjectBindingPattern(properties: [obpX, obpY]),
        ),
        startByte: 0,
        endByte: srcLines[0].length,
      );
      final st1Start = srcLines[0].length + 1;
      final abeM = ArrayBindingElement(
        target: Identifier(name: 'm'),
        defaultValue: NumberLiteral(value: 2),
      );
      final abeN = ArrayBindingElement(target: Identifier(name: 'n'));
      final st1 = ExpressionStatement(
        expression: VariableDeclaration(
          FunctionCallExpression(
            methodName: Identifier(name: 'bar'),
            argumentList: ArgumentList(arguments: const []),
          ),
          name: Identifier(name: ''),
          declKind: 'const',
          pattern: ArrayBindingPattern(elements: [abeM, abeN]),
        ),
        startByte: st1Start,
        endByte: st1Start + srcLines[1].length,
      );
      final unit = CompilationUnit(
        statements: [st0, st1],
        imported: const [],
        exported: const [],
        userVariables: const [],
      );
      final prepared = Prepared(
        language: 'ts',
        setup: unit,
        source: src,
        filename: 'Comp.vue',
      );
      final outAst = ScriptCodegen.generate(prepared: prepared, useAstPrinter: true);
      final outSlice = ScriptCodegen.generate(prepared: prepared, useAstPrinter: false);
      expect(outAst, equals(outSlice));
      expect(outAst, contains('const {x = 1, y} = foo();'));
      expect(outAst, contains('const [m = 2, n] = bar();'));
    });
  });
}