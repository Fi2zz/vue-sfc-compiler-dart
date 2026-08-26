// Shared tree-sitter node predicates mirroring @vue/compiler-dom helpers.
import '../ts_parser.dart';

const functionTypes = {
  'function_expression',
  'arrow_function',
  'function_declaration',
  'generator_function',
  'generator_function_declaration',
  'method_definition',
};

bool isFunctionType(AstNode node) => functionTypes.contains(node.type);

/// Unwrap TS-only wrappers (as / satisfies / non-null / type assertion).
AstNode unwrapTSNode(AstNode node) {
  var n = node;
  while (n.type == 'as_expression' ||
      n.type == 'satisfies_expression' ||
      n.type == 'non_null_expression' ||
      n.type == 'type_assertion') {
    if (n.children.isEmpty) return n;
    n = n.children.first;
  }
  return n;
}

/// babel isLiteralNode: node.type.endsWith('Literal') mapped to tree-sitter.
bool isLiteralNode(AstNode node) {
  switch (node.type) {
    case 'string':
    case 'number':
    case 'true':
    case 'false':
    case 'null':
    case 'regex':
    case 'template_string':
      return true;
    default:
      return false;
  }
}

/// Best-effort runtime value type (official inferValueType in defineProps).
String? inferValueType(AstNode node) {
  switch (node.type) {
    case 'string':
      return 'String';
    case 'number':
      return 'Number';
    case 'true':
    case 'false':
      return 'Boolean';
    case 'object':
      return 'Object';
    case 'array':
      return 'Array';
    case 'function_expression':
    case 'arrow_function':
      return 'Function';
    default:
      return null;
  }
}

/// Collect all binding identifiers declared by a pattern node
/// (port of extractIdentifiers for tree-sitter patterns).
List<AstNode> extractIdentifiers(AstNode node) {
  final out = <AstNode>[];
  void walk(AstNode n) {
    switch (n.type) {
      case 'identifier':
        out.add(n);
        break;
      case 'shorthand_property_identifier_pattern':
        out.add(n);
        break;
      case 'object_assignment_pattern':
      case 'assignment_pattern':
        // only the left side declares bindings; the default value is an
        // expression and must not contribute identifiers
        if (n.children.isNotEmpty) walk(n.children.first);
        break;
      case 'pair_pattern':
        if (n.children.isNotEmpty) walk(n.children.last);
        break;
      case 'rest_pattern':
      case 'required_parameter':
      case 'optional_parameter':
        // the binding pattern is always the first named child
        if (n.children.isNotEmpty) walk(n.children.first);
        break;
      case 'object_pattern':
      case 'array_pattern':
        for (final c in n.children) {
          walk(c);
        }
        break;
      default:
        break;
    }
  }

  walk(node);
  return out;
}
