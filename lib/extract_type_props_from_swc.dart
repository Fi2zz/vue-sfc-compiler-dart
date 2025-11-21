import 'package:vue_sfc_parser/parse_type_literal_props.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';
import 'package:vue_sfc_parser/sfc_module_to_compilation_unit.dart';

List<PropSignature> extractTypePropsFromSwc(
  List<String>? typeArgs,
  Map<String, List<PropSignature>> alias,
) {
  final out = <PropSignature>[];
  if (typeArgs == null || typeArgs.isEmpty) return out;
  final raw = typeArgs.first.trim();
  if (isSimpleIdentifier(raw)) {
    final props = alias[raw];
    if (props != null) out.addAll(props);
    return out;
  }
  final body = outerBracesBody(raw);
  if (body == null) return out;
  out.addAll(parseTypeLiteralProps(body));
  return out;
}
