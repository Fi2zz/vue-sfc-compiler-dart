import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';

void main() {
  group('UserVariable serialization', () {
    test('toJson/fromJson roundtrip', () {
      final uv = UserVariable(name: 'foo', type: 'String', defaultValue: '"bar"');
      final js = uv.toJson();
      final uv2 = UserVariable.fromJson(js);
      expect(uv2.name, 'foo');
      expect(uv2.type, 'String');
      expect(uv2.defaultValue, '"bar"');
    });
  });
}