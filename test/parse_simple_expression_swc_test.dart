import 'package:test/test.dart';
import 'package:vue_sfc_parser/parse_simple_expression.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';

void main() {
  group('parseSimpleExpression via SWC', () {
    test('null', () {
      final e = parseSimpleExpression('null', 0, 4);
      expect(e, isA<NullLiteral>());
    });
    test('boolean', () {
      final t = parseSimpleExpression('true', 0, 4) as BooleanLiteral;
      expect(t.value, isTrue);
      final f = parseSimpleExpression('false', 0, 5) as BooleanLiteral;
      expect(f.value, isFalse);
    });
    test('number', () {
      final n = parseSimpleExpression('123', 0, 3) as NumberLiteral;
      expect(n.value, 123);
    });
    test('bigint', () {
      final b = parseSimpleExpression('123n', 0, 4) as BigIntLiteral;
      expect(b.value, BigInt.parse('123'));
    });
    test('string', () {
      final s = parseSimpleExpression("'str'", 0, 5) as StringLiteral;
      expect(s.stringValue, 'str');
    });
    test('object', () {
      final o = parseSimpleExpression('{a:1}', 0, 6) as SetOrMapLiteral;
      expect(o.elements.length, 1);
      expect(o.elements.first.keyText, 'a');
      expect((o.elements.first.value as NumberLiteral).value, 1);
    });
    test('array', () {
      final a = parseSimpleExpression('[1,2]', 0, 5) as ListLiteral;
      expect(a.elements.length, 2);
      expect((a.elements[0] as NumberLiteral).value, 1);
      expect((a.elements[1] as NumberLiteral).value, 2);
    });
    test('nested object/array', () {
      final e = parseSimpleExpression('{list:[1,{x:true}]}', 0, 20) as SetOrMapLiteral;
      expect(e.elements.length, 1);
      final listVal = e.elements.first.value as ListLiteral;
      expect(listVal.elements.length, 2);
      expect((listVal.elements[0] as NumberLiteral).value, 1);
      final innerObj = listVal.elements[1] as SetOrMapLiteral;
      expect(innerObj.elements.length, 1);
      expect(innerObj.elements.first.keyText, 'x');
      expect((innerObj.elements.first.value as BooleanLiteral).value, isTrue);
    });
    test('identifier', () {
      final id = parseSimpleExpression('foo', 0, 3) as Identifier;
      expect(id.name, 'foo');
    });
    test('template with placeholder remains untouched', () {
      final id = parseSimpleExpression(r'`${placeholder}`', 0, 16) as Identifier;
      expect(id.name, r'`${placeholder}`');
    });
    test('object method and arrow function value', () {
      final m1 = parseSimpleExpression('{m(){return 1}}', 0, 15) as SetOrMapLiteral;
      expect(m1.elements.length, 1);
      expect(m1.elements.first.keyText, 'm');
      expect(m1.elements.first.value, isA<FunctionExpressionInvocation>());
      final a1 = parseSimpleExpression('{x:() => 2}', 0, 11) as SetOrMapLiteral;
      expect(a1.elements.length, 1);
      expect(a1.elements.first.keyText, 'x');
      expect(a1.elements.first.value, isA<FunctionExpressionInvocation>());
    });
  });
}