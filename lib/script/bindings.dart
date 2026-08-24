// Port of walkDeclaration / walkPattern binding registration (official
// compiler-sfc rules incl. literal-const / setup-ref / setup-reactive-const).
import 'package:vue_sfc_parser/ts_parser.dart';

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

/// Port of walkDeclaration. Returns true when all inits are static literals
/// (VariableDeclaration) or all enum members are literal (enum) — the caller
/// hoists the statement when hoistStatic is on.
bool walkDeclaration(
  SetupContext ctx,
  AstNode node,
  Map<String, BindingKind> bindings, {
  Map<String, String> vueImportAliases = const {},
  bool hoistStatic = false,
  bool fromScript = false,
  bool propsDestructureEnabled = false,
}) {
  if (node.type == 'lexical_declaration' ||
      node.type == 'variable_declaration') {
    return _walkVarDecl(ctx, node, bindings,
        vueImportAliases: vueImportAliases,
        hoistStatic: hoistStatic,
        fromScript: fromScript,
        propsDestructureEnabled: propsDestructureEnabled);
  }
  if (node.type == 'enum_declaration') return _walkEnum(ctx, node, bindings);
  if (node.type == 'function_declaration' ||
      node.type == 'generator_function_declaration' ||
      node.type == 'class_declaration' ||
      node.type == 'abstract_class_declaration') {
    final id = childOfType(node, 'identifier') ??
        childOfType(node, 'type_identifier');
    if (id != null) bindings[ctx.view.textOf(id)] = BindingKind.setupConst;
  }
  return false;
}

bool _walkVarDecl(
  SetupContext ctx,
  AstNode node,
  Map<String, BindingKind> bindings, {
  required Map<String, String> vueImportAliases,
  required bool hoistStatic,
  required bool fromScript,
  required bool propsDestructureEnabled,
}) {
  final isConst = declarationKind(node, ctx.view) == 'const';
  final declarators = childrenOfType(node, 'variable_declarator').toList();
  final allLiteral = isConst &&
      declarators.isNotEmpty &&
      declarators.every((d) =>
          d.children.first.type == 'identifier' &&
          _isStaticNode(_declInit(d)));
  for (final decl in declarators) {
    final id = decl.children.first;
    final init = _declInit(decl);
    if (id.type == 'identifier') {
      final kind = _identifierKind(ctx, init, isConst, allLiteral,
          vueImportAliases: vueImportAliases,
          hoistStatic: hoistStatic,
          fromScript: fromScript);
      bindings[ctx.view.textOf(id)] = kind;
    } else {
      final isConstMacroCall = isConst && _isMacroCall(ctx, init);
      if (_isDefinePropsCall(ctx, init) && propsDestructureEnabled) {
        continue;
      }
      if (id.type == 'object_pattern') {
        _walkObjectPattern(ctx, id, bindings, isConst, isConstMacroCall);
      } else if (id.type == 'array_pattern') {
        _walkArrayPattern(ctx, id, bindings, isConst, isConstMacroCall);
      }
    }
  }
  return allLiteral;
}

bool _walkEnum(SetupContext ctx, AstNode node, Map<String, BindingKind> bindings) {
  final id = childOfType(node, 'identifier');
  if (id == null) return false;
  // 官方：成员无初始化器或初始化器为静态字面量 → literal-const。
  final body = childOfType(node, 'enum_body');
  final members = body?.children ?? const [];
  final allLiteral = members.every((m) =>
      m.type == 'property_identifier' ||
      (m.type == 'enum_assignment' &&
          m.children.isNotEmpty &&
          _isStaticNode(m.children.last)));
  bindings[ctx.view.textOf(id)] =
      allLiteral ? BindingKind.literalConst : BindingKind.setupConst;
  return allLiteral;
}

BindingKind _identifierKind(
  SetupContext ctx,
  AstNode? init,
  bool isConst,
  bool allLiteral, {
  required Map<String, String> vueImportAliases,
  required bool hoistStatic,
  required bool fromScript,
}) {  // 官方：(hoistStatic || from === 'script') && (isAllLiteral || 静态字面量)
  final staticInit = allLiteral || (init != null && _isStaticNode(init));
  if ((hoistStatic || fromScript) && isConst && staticInit) {
    return BindingKind.literalConst;
  }
  final reactiveLocal = vueImportAliases['reactive'];
  if (reactiveLocal != null && _isCallOfName(ctx.view, init, {reactiveLocal})) {
    return isConst ? BindingKind.setupReactiveConst : BindingKind.setupLet;
  }
  if (isConst && (_isMacroCall(ctx, init) || _neverRef(ctx, init, reactiveLocal))) {
    return BindingKind.setupConst;
  }
  if (isConst && _refFamilyCall(ctx, init, vueImportAliases)) {
    return BindingKind.setupRef;
  }
  if (isConst) return BindingKind.setupMaybeRef;
  return BindingKind.setupLet;
}

bool _refFamilyCall(
    SetupContext ctx, AstNode? init, Map<String, String> aliases) {
  if (init == null || init.type != 'call_expression') return false;
  final names = <String>{_kDefineModel};
  for (final imported in _refFamilyImports) {
    final local = aliases[imported];
    if (local != null) names.add(local);
  }
  return _isCallOfName(ctx.view, init, names);
}

const _kDefineModel = 'defineModel';

/// canNeverBeRef：reactive 调用或纯值表达式，永远不可能是 ref。
bool _neverRef(SetupContext ctx, AstNode? init, String? reactiveLocal) {
  if (init == null) return false;
  if (reactiveLocal != null &&
      _isCallOfName(ctx.view, init, {reactiveLocal})) {
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
      return true;
    case 'sequence_expression':
      return init.children.isEmpty
          ? false
          : _neverRef(ctx, init.children.last, reactiveLocal);
    default:
      return false;
  }
}

/// isStaticNode：字面量及字面量间的运算/模板/三元。
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
      return node.children.length == 3 &&
          node.children.every(_isStaticNodeAble);
    case 'sequence_expression':
      return node.children.every(_isStaticNodeAble);
    case 'template_string':
      return node.children
          .where((c) => c.type == 'template_substitution')
          .every((c) => c.children.isNotEmpty && _isStaticNode(c.children.first));
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

bool _isStaticNodeAble(AstNode n) => _isStaticNode(n);

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

bool _isDefinePropsCall(SetupContext ctx, AstNode? init) =>
    init != null && isCallOf(unwrapForCall(init), 'defineProps', ctx.view);

bool _isMacroCall(SetupContext ctx, AstNode? init) {
  if (init == null) return false;
  final n = unwrapForCall(init);
  if (n.type != 'call_expression') return false;
  final id = childOfType(n, 'identifier');
  return id != null && _macroConstCalls.contains(ctx.view.textOf(id));
}

void _walkObjectPattern(
  SetupContext ctx,
  AstNode node,
  Map<String, BindingKind> bindings,
  bool isConst,
  bool isDefineCall,
) {
  for (final p in node.children) {
    if (p.type == 'shorthand_property_identifier_pattern') {
      bindings[ctx.view.textOf(p)] = _patternKind(isConst, isDefineCall);
    } else if (p.type == 'object_assignment_pattern') {
      // { x = 1 }: binding is the shorthand identifier, value is default
      final id = childOfType(p, 'shorthand_property_identifier_pattern');
      if (id != null) {
        bindings[ctx.view.textOf(id)] = _patternKind(isConst, isDefineCall);
      }
    } else if (p.type == 'pair_pattern') {
      final value = p.children.last;
      _walkPattern(ctx, value, bindings, isConst, isDefineCall);
    } else if (p.type == 'rest_pattern') {
      final id = childOfType(p, 'identifier');
      if (id != null) {
        bindings[ctx.view.textOf(id)] =
            isConst ? BindingKind.setupConst : BindingKind.setupLet;
      }
    }
  }
}

void _walkArrayPattern(
  SetupContext ctx,
  AstNode node,
  Map<String, BindingKind> bindings,
  bool isConst,
  bool isDefineCall,
) {
  for (final e in node.children) {
    _walkPattern(ctx, e, bindings, isConst, isDefineCall);
  }
}

void _walkPattern(
  SetupContext ctx,
  AstNode node,
  Map<String, BindingKind> bindings,
  bool isConst,
  bool isDefineCall,
) {
  switch (node.type) {
    case 'identifier':
      bindings[ctx.view.textOf(node)] = _patternKind(isConst, isDefineCall);
      break;
    case 'rest_pattern':
      final id = childOfType(node, 'identifier');
      if (id != null) {
        bindings[ctx.view.textOf(id)] =
            isConst ? BindingKind.setupConst : BindingKind.setupLet;
      }
      break;
    case 'object_pattern':
      _walkObjectPattern(ctx, node, bindings, isConst, false);
      break;
    case 'array_pattern':
      _walkArrayPattern(ctx, node, bindings, isConst, false);
      break;
    case 'assignment_pattern':
      final left = node.children.first;
      if (left.type == 'identifier') {
        bindings[ctx.view.textOf(left)] = _patternKind(isConst, isDefineCall);
      } else {
        _walkPattern(ctx, left, bindings, isConst, false);
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
