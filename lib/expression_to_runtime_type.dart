import 'package:vue_sfc_parser/ast.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';

String expressionToRuntimeType(Expression exp) {
  final v = exp;
  if (v is Identifier) {
    return normalizeObjectText(v.text);
  } else if (v is StringLiteral) {
    return 'String';
  } else if (v is NumberLiteral) {
    return 'Number';
  } else if (v is BooleanLiteral) {
    return 'Boolean';
  } else if (v is SetOrMapLiteral) {
    return 'Object';
  } else {
    return 'Object';
  }
}
