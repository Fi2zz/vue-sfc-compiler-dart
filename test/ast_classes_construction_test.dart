import 'package:test/test.dart';
import 'package:vue_sfc_parser/ast.dart';
import 'package:vue_sfc_parser/code_printer.dart';

void main() {
  group('AST classes: text fallback printing', () {
    test('FunctionDeclaration uses text when present', () {
      final node = FunctionDeclaration(
        id: Identifier(name: 'fn'),
        params: const [],
        body: const BlockStatement(body: [], directives: []),
        generator: false,
        async: false,
        text: 'function fn() { return 1; }',
      );
      final out = CodePrinter.printNode(node);
      expect(out, equals('function fn() { return 1; }'));
    });

    test('ExportAllDeclartion uses text when present', () {
      final node = ExportAllDeclartion(
        source: StringLiteral(value: 'mod'),
        text: 'export * from "mod";',
      );
      final out = CodePrinter.printNode(node);
      expect(out, equals('export * from "mod";'));
    });

    test('FunctionCallExpression uses text when present', () {
      final node = FunctionCallExpression(
        methodName: Identifier(name: 'doWork'),
        argumentList: ArgumentList(arguments: const []),
        text: 'doWork(1, 2, 3);',
      );
      final out = CodePrinter.printNode(node);
      expect(out, equals('doWork(1, 2, 3);'));
    });

    test('ExpressionStatement uses text when present', () {
      final node = ExpressionStatement(
        expression: Identifier(name: 'x'),
        text: 'x = 1 + 2;',
      );
      final out = CodePrinter.printNode(node);
      expect(out, equals('x = 1 + 2;'));
    });

    test('Identifier prints terminal name from text', () {
      final node = Identifier(text: 'some.token', name: 'token');
      final out = CodePrinter.printNode(node);
      expect(out, equals('token'));
    });
  });
}
