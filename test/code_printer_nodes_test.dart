import 'package:test/test.dart';
import 'package:vue_sfc_parser/ast.dart';
import 'package:vue_sfc_parser/code_printer.dart';

void main() {
  group('CodePrinter: literals and identifiers', () {
    test('Identifier', () {
      final out = CodePrinter.printNode(Identifier(name: 'name'));
      expect(out, equals('name'));
    });
    test('StringLiteral', () {
      final out = CodePrinter.printNode(StringLiteral(stringValue: 'x'));
      expect(out, equals('"x"'));
    });
    test('NumericLiteral', () {
      final out = CodePrinter.printNode(NumericLiteral(value: 42));
      expect(out, equals('42'));
    });
    test('BooleanLiteral / NullLiteral', () {
      expect(
        CodePrinter.printNode(BooleanLiteral(value: true)),
        equals('true'),
      );
      expect(
        CodePrinter.printNode(BooleanLiteral(value: false)),
        equals('false'),
      );
      expect(CodePrinter.printNode(NullLiteral()), equals('null'));
    });
  });

  group('CodePrinter: arguments and call', () {
    test('ArgumentList join', () {
      final args = ArgumentList(
        arguments: [
          StringLiteral(stringValue: 'x'),
          NumberLiteral(value: 1),
        ],
      );
      final out = CodePrinter.printNode(args);
      expect(out, equals('"x", 1'));
    });
    test('FunctionCallExpression text passthrough (+semicolon ensure)', () {
      final out = CodePrinter.printNode(
        FunctionCallExpression(
          methodName: Identifier(name: 'fn'),
          argumentList: ArgumentList(arguments: const []),
          text: 'doWork() ;',
        ),
      );
      expect(out, equals('doWork() ;'));
    });
    test('FunctionCallExpression structured', () {
      final out = CodePrinter.printNode(
        FunctionCallExpression(
          methodName: Identifier(name: 'doWork'),
          argumentList: ArgumentList(
            arguments: [
              SetOrMapLiteral(
                elements: [
                  MapLiteralEntry(
                    keyText: 'opt',
                    value: NumberLiteral(value: 1),
                  ),
                ],
              ),
              StringLiteral(stringValue: 'x'),
              NumberLiteral(value: 2),
            ],
          ),
        ),
      );
      expect(out, equals('doWork({ opt: 1 }, "x", 2);'));
    });
  });

  group('CodePrinter: map and set literals', () {
    test('MapLiteralEntry + SetOrMapLiteral', () {
      final m = SetOrMapLiteral(
        elements: [
          MapLiteralEntry(keyText: 'a', value: NumberLiteral(value: 1)),
          MapLiteralEntry(
            keyText: 'b',
            value: StringLiteral(stringValue: 'x'),
          ),
        ],
      );
      final out = CodePrinter.printNode(m);
      expect(out, equals('{ a: 1, b: "x" }'));
    });
  });

  group('CodePrinter: variable and patterns', () {
    test('VariableDeclaration simple', () {
      final v = VariableDeclaration(
        NumberLiteral(value: 1),
        name: Identifier(name: 'x'),
        declKind: 'const',
      );
      final out = CodePrinter.printNode(v);
      expect(out, equals('const x = 1;'));
    });
    test('ObjectBindingPattern', () {
      final pat = ObjectBindingPattern(
        properties: [
          ObjectBindingProperty(
            key: 'a',
            alias: Identifier(name: 'aa'),
            defaultValue: NumberLiteral(value: 2),
          ),
          ObjectBindingProperty(key: 'b'),
        ],
      );
      final out = CodePrinter.printNode(pat);
      expect(out, equals('{ a: aa = 2, b }'));
    });
    test('ArrayBindingPattern', () {
      final pat = ArrayBindingPattern(
        elements: [
          ArrayBindingElement(
            target: Identifier(name: 'x'),
            defaultValue: NumberLiteral(value: 1),
          ),
          ArrayBindingElement(target: Identifier(name: 'rest'), isRest: true),
        ],
      );
      final out = CodePrinter.printNode(pat);
      expect(out, equals('[ x = 1, ...rest ]'));
    });
  });

  group('CodePrinter: expressions', () {
    test('AssignmentExpression', () {
      final out = CodePrinter.printNode(
        AssignmentExpression(
          operator: '=',
          left: Identifier(name: 'a'),
          right: NumberLiteral(value: 1),
        ),
      );
      expect(out, equals('a = 1'));
    });
    test('MemberExpression computed', () {
      final out = CodePrinter.printNode(
        MemberExpression(
          object: Identifier(name: 'obj'),
          property: StringLiteral(stringValue: 'p'),
          computed: true,
        ),
      );
      expect(out, equals('obj["p"]'));
    });
    test('MemberExpression dot', () {
      final out = CodePrinter.printNode(
        MemberExpression(
          object: Identifier(name: 'obj'),
          property: Identifier(name: 'field'),
          computed: false,
        ),
      );
      expect(out, equals('obj.field'));
    });
  });

  group('CodePrinter: modules', () {
    test('ImportDeclaration named/default/namespace', () {
      final named = ImportSpecifier(
        local: Identifier(name: 'A'),
        imported: Identifier(name: 'A'),
      );
      final aliased = ImportSpecifier(
        local: Identifier(name: 'C'),
        imported: Identifier(name: 'B'),
      );
      final imp = ImportDeclaration(
        specifiers: [
          ImportDefaultSpecifier(local: Identifier(name: 'Default')),
          named,
          aliased,
        ],
        source: StringLiteral(value: 'mod'),
      );
      final out = CodePrinter.printNode(imp);
      expect(out, equals('import Default, { A, B as C } from "mod";'));
    });
    test('ExportNamedDeclaration', () {
      final spec = [
        ExportSpecifier(
          local: Identifier(name: 'A'),
          exported: Identifier(name: 'A'),
        ),
        ExportSpecifier(
          local: Identifier(name: 'B'),
          exported: Identifier(name: 'C'),
        ),
      ];
      final exp = ExportNamedDeclaration(declaration: null, specifiers: spec);
      final out = CodePrinter.printNode(exp);
      expect(out, equals('export { A, B as C };'));
    });
    test('ExportAllDeclartion alias', () {
      final exp = ExportAllDeclartion(
        source: StringLiteral(value: 'mod'),
        exported: Identifier(name: 'NS'),
      );
      final out = CodePrinter.printNode(exp);
      expect(out, equals('export * as NS from "mod";'));
    });
  });

  group('CodePrinter: object methods with patterns', () {
    test('ObjectMethod ArrayPattern/ObjectPattern params', () {
      final m = ObjectExpression(
        properties: [
          ObjectMethod(
            kind: 'method',
            key: Identifier(name: 'fn2'),
            params: [
              ArrayPattern(elements: [Identifier(name: 'a')]),
            ],
            body: const BlockStatement(body: [], directives: []),
            computed: false,
            generator: false,
            async: false,
          ),
          ObjectMethod(
            kind: 'method',
            key: Identifier(name: 'fn4'),
            params: [
              ArrayPattern(elements: const []),
              ObjectPattern(properties: const []),
            ],
            body: const BlockStatement(body: [], directives: []),
            computed: false,
            generator: false,
            async: false,
          ),
        ],
      );
      final out = CodePrinter.printNode(m);
      expect(out, equals('{ fn2([ a ]) { }, fn4([  ], {  }) { } }'));
    });

    test('FunctionCall with SetOrMapLiteral Method entries', () {
      final arg = SetOrMapLiteral(
        elements: [
          MapLiteralEntry(
            keyText: 'fn',
            value: ArrowFunctionExpression(
              params: const [],
              body: const BlockStatement(body: [], directives: []),
              async: false,
              expression: false,
              text: '',
            ),
          ),
          MapLiteralEntry(
            keyText: 'fn1',
            value: FunctionExpression(
              id: null,
              params: const [],
              body: const BlockStatement(body: [], directives: []),
              generator: false,
              async: false,
              text: '',
            ),
            extra: const {'kind': 'Method'},
          ),
          MapLiteralEntry(
            keyText: 'fn2',
            value: ArrowFunctionExpression(
              params: [
                ArrayPattern(elements: [Identifier(name: 'a')]),
              ],
              body: const BlockStatement(body: [], directives: []),
              async: false,
              expression: false,
              text: '',
            ),
            extra: const {'kind': 'Method'},
          ),
          MapLiteralEntry(
            keyText: 'fn4',
            value: ArrowFunctionExpression(
              params: [
                ArrayPattern(elements: const []),
                ObjectPattern(properties: const []),
              ],
              body: const BlockStatement(body: [], directives: []),
              async: false,
              expression: false,
              text: '',
            ),
            extra: const {'kind': 'Method'},
          ),
        ],
      );
      final call = FunctionCallExpression(
        methodName: Identifier(name: 'fn'),
        argumentList: ArgumentList(arguments: [arg]),
      );
      final out = CodePrinter.printNode(call);
      expect(
        out,
        equals(
          'fn({ fn: () => { }, fn1() { }, fn2([ a ]) { }, fn4([  ], {  }) { } });',
        ),
      );
    });
  });
}
