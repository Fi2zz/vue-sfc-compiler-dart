import 'package:test/test.dart';
import 'package:vue_sfc_parser/parse_script.dart';
import 'package:vue_sfc_parser/ast.dart';
import 'package:vue_sfc_parser/code_printer.dart';

void main() {
  group('object parsing', () {
    test('getter/setter/computed and params', () {
      const src = '''
const id = 'kid';
const object = {
  world: "world",
  get g() {},
  set s(v) {},
  fn1() {},
  fn2: () => {},
  [id]() {},
  fn3(param1) {},
  fn4(param1, ...more) {},
  fn5({param1}){},
  fn6({param1} ={param1:1}){},
  fn7([]){},
  fn8([param1] = ['hello']){},
};
''';
      final result = parseScript(src, language: 'ts');
      final st = result.unit.statements.firstWhere((e) {
        final d = e.declaration;
        return d is VariableDeclaration && d.name.name == 'object';
      });
      final decl = st.declaration as VariableDeclaration;
      expect(decl.init, isA<ObjectExpression>());
      final obj = decl.init as ObjectExpression;
      // expect properties count
      expect(obj.properties.length, 12);
      // world
      final world = obj.properties[0] as ObjectProperty;
      expect(world.computed, isFalse);
      expect((world.key as Identifier).name, 'world');
      expect(world.value, isA<StringLiteral>());
      // getter
      final getg = obj.properties[1] as ObjectMethod;
      expect(getg.kind, 'get');
      expect((getg.key as Identifier).name, 'g');
      // setter
      final sets = obj.properties[2] as ObjectMethod;
      expect(sets.kind, 'set');
      expect((sets.key as Identifier).name, 's');
      expect(sets.params.length, 1);
      // computed method
      final comp = obj.properties[5] as ObjectMethod;
      expect(comp.computed, isTrue);
      // rest params
      final fn4 = obj.properties[7] as ObjectMethod;
      expect(fn4.params.length, 2);
    });
    test('method body control flow', () {
      const src = '''
const object = {
  m1() { const a = 1; if (a) { return a; } else { return 0; } },
  m2() { let i = 0; while (i) { i = i - 1; } },
  m3() { for (let j = 0; j < 3; j = j + 1) { console.log(j) } },
  m4() { try { const x = 1; } catch (e) { console.log(e) } finally { const y = 2; } },
  m5() { switch (1) { case 1: break; default: throw new Error('x'); } },
  m6() { do { const z = 3 } while (false) },
  m7() { const a = 1 + 2; const b = a && true; const c = a ? b : 0; const d = new Error('e'); const e = obj[prop]; const f = obj.name; },
};
''';
      final result = parseScript(src, language: 'ts');
      final st = result.unit.statements.firstWhere(
        (e) => (e.declaration as VariableDeclaration).name.name == 'object',
      );
      final decl = st.declaration as VariableDeclaration;
      final obj = decl.init as ObjectExpression;
      final code = CodePrinter.print(obj);
      expect(code.contains('if ('), isTrue);
      expect(code.contains('while ('), isTrue);
      expect(code.contains('for ('), isTrue);
      expect(code.contains('try '), isTrue);
      expect(code.contains('catch ('), isTrue);
      expect(code.contains('finally '), isTrue);
      expect(code.contains('switch ('), isTrue);
      expect(code.contains('throw '), isTrue);
      expect(code.contains('do '), isTrue);
      expect(code.contains('?'), isTrue);
      expect(code.contains('&&'), isTrue);
      expect(code.contains('new '), isTrue);
    });
  });

  group('object printer', () {
    test('prints object with getter/setter/computed', () {
      final props = <Object>[
        ObjectProperty(
          key: Identifier(name: 'world'),
          value: const StringLiteral(stringValue: 'world'),
          computed: false,
          shorthand: false,
        ),
        ObjectMethod(
          kind: 'get',
          key: Identifier(name: 'g'),
          params: const [],
          body: const BlockStatement(body: [], directives: []),
          computed: false,
          generator: false,
          async: false,
        ),
        ObjectMethod(
          kind: 'set',
          key: Identifier(name: 's'),
          params: [Identifier(name: 'v')],
          body: const BlockStatement(body: [], directives: []),
          computed: false,
          generator: false,
          async: false,
        ),
        ObjectProperty(
          key: Identifier(text: 'id', name: ''),
          value: ArrowFunctionExpression(
            params: const [],
            body: const BlockStatement(body: [], directives: []),
            async: false,
            expression: false,
          ),
          computed: true,
          shorthand: false,
        ),
      ];
      final obj = ObjectExpression(properties: props);
      final code = CodePrinter.print(obj);
      expect(code.contains('get g() { }'), isTrue);
      expect(code.contains('set s(v) { }'), isTrue);
      expect(code.contains('[id]'), isTrue);
    });
  });
}
