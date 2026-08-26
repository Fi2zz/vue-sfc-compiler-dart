// Port of official resolveType subset: inferRuntimeType + resolveTypeElements
// over tree-sitter AST nodes.
import '../ts_parser.dart';

import 'src_view.dart';

const unknownType = 'Unknown';

/// A prop extracted from a TS type literal.
final class PropData {
  final String key;
  final AstNode? typeNode; // annotation type node
  final SrcView view; // typeNode 所在块的 view（跨块类型引用必需）
  final bool optional;
  final bool method;

  PropData(this.key, this.typeNode, this.view,
      {this.optional = false, this.method = false});
}

/// Build a name -> declaration node map for a parsed script body.
///
/// 条目必须携带声明所在块的 SrcView：normal script 与 setup 是同一源文件的
/// 不同切片，字节偏移互不相通。setup 整体引用 normal script 声明的类型时，
/// 若用引用方 view 提取声明体文本会拿错内容（成员键乱码/丢失 → props 缺失）。
typedef TypeScopeEntry = (AstNode node, SrcView view);

Map<String, TypeScopeEntry> collectTypeScope(AstNode root, SrcView view) {
  final out = <String, TypeScopeEntry>{};
  for (final n in root.children) {
    // `export interface/enum/...` 会被包一层 export_statement，须解包。
    var d = n;
    if (n.type == 'export_statement' && n.children.isNotEmpty) {
      final inner = n.children.first;
      if (_isTypeDecl(inner.type)) d = inner;
    }
    if (!_isTypeDecl(d.type)) continue;
    final id = childOfType(d, 'type_identifier') ?? childOfType(d, 'identifier');
    if (id != null) out[view.textOf(id)] = (d, view);
  }
  return out;
}

bool _isTypeDecl(String type) =>
    type == 'type_alias_declaration' ||
    type == 'interface_declaration' ||
    type == 'enum_declaration' ||
    type == 'class_declaration';

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
/// [leadingIgnored] mirrors official hasVueIgnore on the top node: babel
/// attaches comments before the first member to the parent, so they apply to
/// that member only.
TypeElements resolveTypeElements(
  AstNode node,
  SrcView view,
  Map<String, TypeScopeEntry> scope, {
  bool leadingIgnored = false,
}) {
  final out = TypeElements();
  void fill(AstNode n, int depth, {bool ignored = false}) {
    if (depth > 5 || ignored) return;
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
      case 'union_type':
        var pending =
            (leadingIgnored && depth == 0) || ignored;
        for (final c in n.children) {
          if (c.type == 'comment') {
            pending = view.textOf(c).contains('@vue-ignore');
            continue;
          }
          fill(c, depth + 1, ignored: pending);
          pending = false;
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
        view,
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
        view,
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
  Map<String, TypeScopeEntry> scope,
  TypeElements out,
  int depth,
) {
  final id =
      n.type == 'type_identifier' ? n : childOfType(n, 'type_identifier');
  if (id == null) return;
  final entry = scope[view.textOf(id)];
  if (entry == null) return;
  // 跨块引用：声明体文本必须用声明所在块的 view 提取。
  final (decl, declView) = entry;
  if (decl.type == 'type_alias_declaration') {
    final body = decl.children.firstWhere(
      (c) => c.type != 'type_identifier' && c.type != 'type_parameters',
      orElse: () => decl,
    );
    final resolved = resolveTypeElements(body, declView, scope);
    out.props.addAll(resolved.props);
    out.calls.addAll(resolved.calls);
  } else if (decl.type == 'interface_declaration') {
    final body = childOfType(decl, 'interface_body');
    if (body != null) _fillFromMembers(body, declView, out);
  }
}

/// Port of inferRuntimeType (non-keyOf path).
List<String> inferRuntimeType(
  AstNode node,
  SrcView view,
  Map<String, TypeScopeEntry> scope,
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
      return _flattenTypes(node.children, view, scope);
    case 'intersection_type':
      return _flattenTypes(node.children, view, scope)
          .where((t) => t != unknownType)
          .toList(growable: false);
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

/// Port of flattenTypes: single member passes through; otherwise concat
/// and dedupe (Set semantics preserve first-occurrence order). A member
/// preceded by an @vue-ignore comment resolves to UNKNOWN (official
/// inferRuntimeType gate).
List<String> _flattenTypes(
  List<AstNode> children,
  SrcView view,
  Map<String, TypeScopeEntry> scope,
) {
  final members = <(AstNode, bool)>[];
  var pending = false;
  for (final c in children) {
    if (c.type == 'comment') {
      pending = view.textOf(c).contains('@vue-ignore');
      continue;
    }
    members.add((c, pending));
    pending = false;
  }
  List<String> of(AstNode t, bool ignored) => ignored
      ? [unknownType]
      : inferRuntimeType(t, view, scope);
  if (members.length == 1) return of(members.first.$1, members.first.$2);
  final seen = <String>{};
  final out = <String>[];
  for (final (t, ignored) in members) {
    for (final r in of(t, ignored)) {
      if (seen.add(r)) out.add(r);
    }
  }
  return out;
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
  Map<String, TypeScopeEntry> scope,
) {
  final id =
      node.type == 'type_identifier' ? node : childOfType(node, 'type_identifier');
  if (id == null) return const [unknownType];
  final name = view.textOf(id);
  final entry = scope[name];
  if (entry != null) {
    // 声明体用声明所在块的 view；嵌套引用再经 scope 逐级切换。
    final (decl, declView) = entry;
    return _inferDeclared(decl, declView, scope);
  }
  return _builtinType(name);
}

List<String> _inferDeclared(
  AstNode decl,
  SrcView view,
  Map<String, TypeScopeEntry> scope,
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
