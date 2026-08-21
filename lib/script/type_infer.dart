// Port of official resolveType subset: inferRuntimeType + resolveTypeElements
// over tree-sitter AST nodes.
import 'package:vue_sfc_parser/ts_parser.dart';

import 'src_view.dart';

const unknownType = 'Unknown';

/// A prop extracted from a TS type literal.
final class PropData {
  final String key;
  final AstNode? typeNode; // annotation type node
  final bool optional;
  final bool method;

  PropData(this.key, this.typeNode, {this.optional = false, this.method = false});
}

/// Build a name -> declaration node map for a parsed script body.
Map<String, AstNode> collectTypeScope(AstNode root, SrcView view) {
  final out = <String, AstNode>{};
  for (final n in root.children) {
    if (n.type == 'type_alias_declaration' ||
        n.type == 'interface_declaration' ||
        n.type == 'enum_declaration' ||
        n.type == 'class_declaration') {
      final id = childOfType(n, 'type_identifier') ?? childOfType(n, 'identifier');
      if (id != null) out[view.textOf(id)] = n;
    }
  }
  return out;
}

bool _optionalMarker(SrcView view, AstNode nameNode, AstNode? annotation) {
  if (annotation == null) return false;
  final between = view.slice(nameNode.endByte, annotation.startByte);
  return between.contains('?');
}

String _propKey(SrcView view, AstNode node) {
  final id = childOfType(node, 'property_identifier') ??
      childOfType(node, 'identifier') ??
      childOfType(node, 'string');
  if (id == null) return '';
  var key = view.textOf(id);
  if (id.type == 'string' && key.length >= 2) {
    key = key.substring(1, key.length - 1);
  }
  return key;
}

final class TypeElements {
  final Map<String, PropData> props = {};
  final List<AstNode> calls = [];
}

/// Port of resolveTypeElements for the shapes used in defineProps/defineEmits.
TypeElements resolveTypeElements(
  AstNode node,
  SrcView view,
  Map<String, AstNode> scope,
) {
  final out = TypeElements();
  void fill(AstNode n, int depth) {
    if (depth > 5) return;
    switch (n.type) {
      case 'object_type':
      case 'interface_body':
        _fillFromMembers(n, view, out);
        break;
      case 'parenthesized_type':
        final inner = n.children.isNotEmpty ? n.children.first : null;
        if (inner != null) fill(inner, depth + 1);
        break;
      case 'intersection_type':
        for (final c in n.children) {
          fill(c, depth + 1);
        }
        break;
      case 'type_identifier':
      case 'generic_type':
        _fillFromReference(n, view, scope, out, depth);
        break;
      default:
        break;
    }
  }

  fill(node, 0);
  return out;
}

void _fillFromMembers(AstNode n, SrcView view, TypeElements out) {
  for (final m in n.children) {
    if (m.type == 'property_signature') {
      final key = _propKey(view, m);
      if (key.isEmpty) continue;
      final ann = childOfType(m, 'type_annotation');
      final nameNode = childOfType(m, 'property_identifier') ??
          childOfType(m, 'string');
      out.props[key] = PropData(
        key,
        ann,
        optional: nameNode != null && _optionalMarker(view, nameNode, ann),
      );
    } else if (m.type == 'method_signature') {
      final key = _propKey(view, m);
      if (key.isEmpty) continue;
      final nameNode = childOfType(m, 'property_identifier') ??
          childOfType(m, 'string');
      out.props[key] = PropData(
        key,
        null,
        optional: _optionalMarker(view, nameNode ?? m, null),
        method: true,
      );
    } else if (m.type == 'call_signature') {
      out.calls.add(m);
    }
  }
}

void _fillFromReference(
  AstNode n,
  SrcView view,
  Map<String, AstNode> scope,
  TypeElements out,
  int depth,
) {
  final id = childOfType(n, 'type_identifier');
  if (id == null) return;
  final decl = scope[view.textOf(id)];
  if (decl == null) return;
  if (decl.type == 'type_alias_declaration') {
    final body = decl.children.firstWhere(
      (c) => c.type != 'type_identifier' && c.type != 'type_parameters',
      orElse: () => decl,
    );
    final resolved = resolveTypeElements(body, view, scope);
    out.props.addAll(resolved.props);
    out.calls.addAll(resolved.calls);
  } else if (decl.type == 'interface_declaration') {
    final body = childOfType(decl, 'interface_body');
    if (body != null) _fillFromMembers(body, view, out);
  }
}

/// Port of inferRuntimeType (non-keyOf path).
List<String> inferRuntimeType(
  AstNode node,
  SrcView view,
  Map<String, AstNode> scope,
) {
  switch (node.type) {
    case 'type_annotation':
      return node.children.isEmpty
          ? const [unknownType]
          : inferRuntimeType(node.children.first, view, scope);
    case 'predefined_type':
      return _predefined(view.textOf(node));
    case 'object_type':
    case 'interface_body':
      return _literalShape(node);
    case 'function_type':
    case 'method_signature':
      return const ['Function'];
    case 'array_type':
    case 'tuple_type':
      return const ['Array'];
    case 'literal_type':
      return _literal(node);
    case 'union_type':
      return [
        for (final c in node.children) ...inferRuntimeType(c, view, scope),
      ];
    case 'intersection_type':
      return [
        for (final c in node.children)
          ...inferRuntimeType(c, view, scope).where((t) => t != unknownType),
      ];
    case 'parenthesized_type':
      return node.children.isEmpty
          ? const [unknownType]
          : inferRuntimeType(node.children.first, view, scope);
    case 'type_identifier':
    case 'generic_type':
      return _referenceType(node, view, scope);
    default:
      return const [unknownType];
  }
}

List<String> _predefined(String text) {
  switch (text) {
    case 'string':
      return const ['String'];
    case 'number':
      return const ['Number'];
    case 'boolean':
      return const ['Boolean'];
    case 'object':
      return const ['Object'];
    case 'null':
    case 'undefined':
    case 'void':
      return const ['null'];
    case 'symbol':
      return const ['Symbol'];
    case 'bigint':
      return const ['BigInt'];
    case 'function':
      return const ['Function'];
    default:
      return const [unknownType];
  }
}

List<String> _literalShape(AstNode node) {
  final types = <String>{};
  for (final m in node.children) {
    if (m.type == 'call_signature' || m.type == 'construct_signature') {
      types.add('Function');
    } else if (m.type == 'property_signature' ||
        m.type == 'method_signature' ||
        m.type == 'index_signature') {
      types.add(m.type == 'method_signature' ? 'Function' : 'Object');
    }
  }
  return types.isEmpty ? const ['Object'] : types.toList(growable: false);
}

List<String> _literal(AstNode node) {
  if (node.children.isEmpty) return const [unknownType];
  final c = node.children.first;
  switch (c.type) {
    case 'string':
      return const ['String'];
    case 'true':
    case 'false':
      return const ['Boolean'];
    case 'number':
      return const ['Number'];
    default:
      return const [unknownType];
  }
}

List<String> _referenceType(
  AstNode node,
  SrcView view,
  Map<String, AstNode> scope,
) {
  final id = childOfType(node, 'type_identifier');
  if (id == null) return const [unknownType];
  final name = view.textOf(id);
  final decl = scope[name];
  if (decl != null) return _inferDeclared(decl, view, scope);
  return _builtinType(name);
}

List<String> _inferDeclared(
  AstNode decl,
  SrcView view,
  Map<String, AstNode> scope,
) {
  if (decl.type == 'type_alias_declaration') {
    final body = decl.children.firstWhere(
      (c) => c.type != 'type_identifier' && c.type != 'type_parameters',
      orElse: () => decl,
    );
    if (body.type == 'function_type') return const ['Function'];
    if (identical(body, decl)) return const [unknownType];
    return inferRuntimeType(body, view, scope);
  }
  if (decl.type == 'interface_declaration') {
    final body = childOfType(decl, 'interface_body');
    return body == null ? const ['Object'] : _literalShape(body);
  }
  if (decl.type == 'class_declaration') return const ['Object'];
  return const [unknownType];
}

List<String> _builtinType(String name) {
  const selves = {
    'Array', 'Function', 'Object', 'Set', 'Map', 'WeakSet', 'WeakMap', 'Date',
    'Promise', 'Error',
  };
  const objects = {
    'Partial', 'Required', 'Readonly', 'Record', 'Pick', 'Omit', 'InstanceType',
  };
  const strings = {'Uppercase', 'Lowercase', 'Capitalize', 'Uncapitalize'};
  const arrays = {'Parameters', 'ConstructorParameters', 'ReadonlyArray'};
  if (selves.contains(name)) return [name];
  if (objects.contains(name)) return const ['Object'];
  if (strings.contains(name)) return const ['String'];
  if (arrays.contains(name)) return const ['Array'];
  if (name == 'ReadonlyMap') return const ['Map'];
  if (name == 'ReadonlySet') return const ['Set'];
  return const [unknownType];
}

String toRuntimeTypeString(List<String> types) {
  return types.length > 1 ? '[${types.join(', ')}]' : types[0];
}
