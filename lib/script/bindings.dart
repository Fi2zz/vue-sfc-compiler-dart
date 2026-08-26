// Port of walkDeclaration / walkPattern binding registration (official
// compiler-sfc rules incl. literal-const / setup-ref / setup-reactive-const).
import '../ts_parser.dart';

import 'macro_process.dart';
import 'setup_context.dart';
import 'src_view.dart';

const _macroConstCalls = {
  'defineProps',
  'defineEmits',
  'withDefaults',
  'defineSlots',
};

/// ref 家族 + defineModel：const 初始化为这些调用时登记 setup-ref。
const _refFamilyImports = {
  'ref',
  'computed',
  'shallowRef',
  'customRef',
  'toRef',
  'useTemplateRef',
};

const _kDefineModel = 'defineModel';

String declarationKind(AstNode node, SrcView view) {
  // lexical_declaration (let/const) or variable_declaration (var);
  // the kind keyword precedes the first named child.
  if (node.children.isEmpty) return 'const';
  final head = view.slice(node.startByte, node.children.first.startByte).trim();
  return head;
}

bool _isCallOfName(SrcView view, AstNode? init, Set<String> names) {
  if (init == null || init.type != 'call_expression') return false;
  final id = childOfType(init, 'identifier');
  return id != null && names.contains(view.textOf(id));
}

bool _isStaticNode(AstNode? raw) {
  if (raw == null) return false;
  final node = unwrapForCall(raw);
  switch (node.type) {
    case 'unary_expression':
      return node.children.isNotEmpty && _isStaticNode(node.children.last);
    case 'binary_expression':
    case 'logical_expression':
      return node.children.length == 2 &&
          _isStaticNode(node.children[0]) &&
          _isStaticNode(node.children[1]);
    case 'ternary_expression':
    case 'sequence_expression':
      return node.children.length >= 2 && node.children.every(_isStaticNode);
    case 'template_string':
      return node.children
          .where((c) => c.type == 'template_substitution')
          .every(
            (c) => c.children.isNotEmpty && _isStaticNode(c.children.first),
          );
    case 'string':
    case 'number':
    case 'true':
    case 'false':
    case 'null':
      return true;
    default:
      return false;
  }
}

AstNode? _declInit(AstNode declarator) {
  // variable_declarator: id [type_annotation] [= value]; init is last when
  // the declarator has more than just the id (and optional annotation).
  if (declarator.children.length < 2) return null;
  final last = declarator.children.last;
  if (last.type == 'type_annotation') return null;
  return unwrapForCall(last);
}

AstNode unwrapForCall(AstNode node) {
  var n = node;
  while (n.type == 'as_expression' ||
      n.type == 'satisfies_expression' ||
      n.type == 'non_null_expression' ||
      n.type == 'type_assertion' ||
      n.type == 'parenthesized_expression') {
    if (n.children.isEmpty) return n;
    n = n.children.first;
  }
  return n;
}

/// Port of walkDeclaration. Returns true when all inits are static literals
/// (VariableDeclaration) or all enum members are literal (enum) — the caller
/// hoists the statement when hoistStatic is on.
///
/// [view] 是声明所在块的视图：normal script 与 setup 是同一源文件的不同
/// 切片，字节坐标互不相通；用错 view 会把声明名提取成乱码键。
bool walkDeclaration(
  SetupContext ctx,
  AstNode node,
  Map<String, BindingKind> bindings, {
  Map<String, String> vueImportAliases = const {},
  bool hoistStatic = false,
  bool fromScript = false,
  bool propsDestructureEnabled = false,
  SrcView? view,
}) {
  final v = view ?? ctx.view;
  if (node.type == 'lexical_declaration' ||
      node.type == 'variable_declaration') {
    return _walkVarDecl(
      ctx,
      node,
      bindings,
      view: v,
      vueImportAliases: vueImportAliases,
      hoistStatic: hoistStatic,
      fromScript: fromScript,
      propsDestructureEnabled: propsDestructureEnabled,
    );
  }
  if (node.type == 'enum_declaration') {
    return _walkEnum(ctx, node, bindings, v);
  }
  if (node.type == 'function_declaration' ||
      node.type == 'generator_function_declaration' ||
      node.type == 'class_declaration' ||
      node.type == 'abstract_class_declaration') {
    final id =
        childOfType(node, 'identifier') ?? childOfType(node, 'type_identifier');
    if (id != null) bindings[v.textOf(id)] = BindingKind.setupConst;
  }
  return false;
}

bool _walkVarDecl(
  SetupContext ctx,
  AstNode node,
  Map<String, BindingKind> bindings, {
  required SrcView view,
  required Map<String, String> vueImportAliases,
  required bool hoistStatic,
  required bool fromScript,
  required bool propsDestructureEnabled,
}) {
  final isConst = declarationKind(node, view) == 'const';
  final declarators = childrenOfType(node, 'variable_declarator').toList();
  final allLiteral =
      isConst &&
      declarators.isNotEmpty &&
      declarators.every(
        (d) =>
            d.children.first.type == 'identifier' &&
            _isStaticNode(_declInit(d)),
      );
  for (final decl in declarators) {
    final id = decl.children.first;
    final init = _declInit(decl);
    if (id.type == 'identifier') {
      bindings[view.textOf(id)] = _identifierKind(
        view,
        init,
        isConst: isConst,
        allLiteral: allLiteral,
        aliases: vueImportAliases,
        hoistStatic: hoistStatic,
        fromScript: fromScript,
      );
    } else {
      final isConstMacroCall = isConst && _isMacroCall(view, init);
      if (_isDefinePropsCall(view, init) && propsDestructureEnabled) {
        continue;
      }
      if (id.type == 'object_pattern') {
        _walkObjectPattern(view, id, bindings, isConst, isConstMacroCall);
      } else if (id.type == 'array_pattern') {
        _walkArrayPattern(view, id, bindings, isConst, isConstMacroCall);
      }
    }
  }
  return allLiteral;
}

BindingKind _identifierKind(
  SrcView view,
  AstNode? init, {
  required bool isConst,
  required bool allLiteral,
  required Map<String, String> aliases,
  required bool hoistStatic,
  required bool fromScript,
}) {
  // 官方：(hoistStatic || from === 'script') && (isAllLiteral || 静态字面量)
  final staticInit = allLiteral || (init != null && _isStaticNode(init));
  if ((hoistStatic || fromScript) && isConst && staticInit) {
    return BindingKind.literalConst;
  }
  final reactiveLocal = aliases['reactive'];
  if (reactiveLocal != null && _isCallOfName(view, init, {reactiveLocal})) {
    return isConst ? BindingKind.setupReactiveConst : BindingKind.setupLet;
  }
  if (isConst &&
      (_isMacroCall(view, init) || _neverRef(view, init, reactiveLocal))) {
    return BindingKind.setupConst;
  }
  if (isConst && _refFamilyCall(view, init, aliases)) {
    return BindingKind.setupRef;
  }
  if (isConst) return BindingKind.setupMaybeRef;
  return BindingKind.setupLet;
}

bool _walkEnum(
  SetupContext ctx,
  AstNode node,
  Map<String, BindingKind> bindings,
  SrcView view,
) {
  final id = childOfType(node, 'identifier');
  if (id == null) return false;
  // 官方：成员无初始化器或初始化器为静态字面量 → literal-const。
  final body = childOfType(node, 'enum_body');
  final members = body?.children ?? const [];
  final allLiteral = members.every(
    (m) =>
        m.type == 'property_identifier' ||
        (m.type == 'enum_assignment' &&
            m.children.isNotEmpty &&
            _isStaticNode(m.children.last)),
  );
  bindings[view.textOf(id)] = allLiteral
      ? BindingKind.literalConst
      : BindingKind.setupConst;
  return allLiteral;
}

bool _definePropsCall(SrcView view, AstNode? init) =>
    init != null && isCallOf(unwrapForCall(init), 'defineProps', view);

bool _isDefinePropsCall(SrcView view, AstNode? init) =>
    _definePropsCall(view, init);

bool _isMacroCall(SrcView view, AstNode? init) {
  if (init == null) return false;
  final n = unwrapForCall(init);
  if (n.type != 'call_expression') return false;
  final id = childOfType(n, 'identifier');
  return id != null && _macroConstCalls.contains(view.textOf(id));
}

bool _refFamilyCall(SrcView view, AstNode? init, Map<String, String> aliases) {
  if (init == null || init.type != 'call_expression') return false;
  final names = <String>{_kDefineModel};
  for (final imported in _refFamilyImports) {
    final local = aliases[imported];
    if (local != null) names.add(local);
  }
  return _isCallOfName(view, init, names);
}

/// canNeverBeRef：reactive 调用或纯值表达式，永远不可能是 ref。
bool _neverRef(SrcView view, AstNode? init, String? reactiveLocal) {
  if (init == null) return false;
  if (reactiveLocal != null && _isCallOfName(view, init, {reactiveLocal})) {
    return true;
  }
  switch (init.type) {
    case 'unary_expression':
    case 'binary_expression':
    case 'array':
    case 'object':
    case 'function_expression':
    case 'arrow_function':
    case 'update_expression':
    case 'class':
    // 官方 default 分支的 isLiteralNode（*Literal）：字面量永不可能是 ref。
    case 'string':
    case 'number':
    case 'true':
    case 'false':
    case 'null':
    case 'regex':
    // 官方 default 分支 isLiteralNode = type.endsWith('Literal')：
    // TemplateLiteral 同样命中（`a${b}` 永不为 ref）。
    case 'template_string':
      return true;
    case 'call_expression':
      // babel TaggedTemplateExpression 显式为 true；tree-sitter 中 tagged
      // template 是无 arguments 的 call_expression，末子节点为模板串。
      final last = init.children.isEmpty ? null : init.children.last;
      return last != null &&
          last.type == 'template_string' &&
          !init.children.any((c) => c.type == 'call_arguments');
    case 'sequence_expression':
      return init.children.isEmpty
          ? false
          : _neverRef(view, init.children.last, reactiveLocal);
    default:
      return false;
  }
}

void _walkObjectPattern(
  SrcView view,
  AstNode node,
  Map<String, BindingKind> bindings,
  bool isConst,
  bool isDefineCall,
) {
  for (final p in node.children) {
    if (p.type == 'shorthand_property_identifier_pattern') {
      bindings[view.textOf(p)] = _patternKind(isConst, isDefineCall);
    } else if (p.type == 'object_assignment_pattern') {
      // { x = 1 }: binding is the shorthand identifier, value is default
      final id = childOfType(p, 'shorthand_property_identifier_pattern');
      if (id != null) {
        bindings[view.textOf(id)] = _patternKind(isConst, isDefineCall);
      }
    } else if (p.type == 'pair_pattern') {
      final value = p.children.last;
      _walkPattern(view, value, bindings, isConst, isDefineCall);
    } else if (p.type == 'rest_pattern') {
      final id = childOfType(p, 'identifier');
      if (id != null) {
        bindings[view.textOf(id)] = isConst
            ? BindingKind.setupConst
            : BindingKind.setupLet;
      }
    }
  }
}

void _walkArrayPattern(
  SrcView view,
  AstNode node,
  Map<String, BindingKind> bindings,
  bool isConst,
  bool isDefineCall,
) {
  for (final e in node.children) {
    _walkPattern(view, e, bindings, isConst, isDefineCall);
  }
}

void _walkPattern(
  SrcView view,
  AstNode node,
  Map<String, BindingKind> bindings,
  bool isConst,
  bool isDefineCall,
) {
  switch (node.type) {
    case 'identifier':
      bindings[view.textOf(node)] = _patternKind(isConst, isDefineCall);
      break;
    case 'rest_pattern':
      final id = childOfType(node, 'identifier');
      if (id != null) {
        bindings[view.textOf(id)] = isConst
            ? BindingKind.setupConst
            : BindingKind.setupLet;
      }
      break;
    case 'object_pattern':
      _walkObjectPattern(view, node, bindings, isConst, false);
      break;
    case 'array_pattern':
      _walkArrayPattern(view, node, bindings, isConst, false);
      break;
    case 'assignment_pattern':
      final left = node.children.first;
      if (left.type == 'identifier') {
        bindings[view.textOf(left)] = _patternKind(isConst, isDefineCall);
      } else {
        _walkPattern(view, left, bindings, isConst, false);
      }
      break;
    default:
      break;
  }
}

BindingKind _patternKind(bool isConst, bool isDefineCall) {
  if (isDefineCall) return BindingKind.setupConst;
  return isConst ? BindingKind.setupMaybeRef : BindingKind.setupLet;
}
