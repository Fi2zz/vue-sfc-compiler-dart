// Port of walkDeclaration / walkPattern binding registration.
// Only the SETUP_LET distinction and key insertion order affect the
// generated __returned__ object, so binding kinds are coarsened to
// setupLet vs. everything else.
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

String declarationKind(AstNode node, SrcView view) {
  // lexical_declaration (let/const) or variable_declaration (var);
  // the kind keyword precedes the first named child.
  if (node.children.isEmpty) return 'const';
  final head = view.slice(node.startByte, node.children.first.startByte).trim();
  return head;
}

/// Port of walkDeclaration. Returns true when all inits are static literals.
void walkDeclaration(
  SetupContext ctx,
  AstNode node,
  Map<String, BindingKind> bindings, {
  bool propsDestructureEnabled = false,
}) {
  if (node.type == 'lexical_declaration' ||
      node.type == 'variable_declaration') {
    final isConst = declarationKind(node, ctx.view) == 'const';
    for (final decl in childrenOfType(node, 'variable_declarator')) {
      final id = decl.children.first;
      final init = _declInit(decl);
      if (id.type == 'identifier') {
        final kind = isConst ? BindingKind.setupConst : BindingKind.setupLet;
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
  } else if (node.type == 'enum_declaration') {
    final id = childOfType(node, 'identifier');
    if (id != null) bindings[ctx.view.textOf(id)] = BindingKind.setupConst;
  } else if (node.type == 'function_declaration' ||
      node.type == 'generator_function_declaration' ||
      node.type == 'class_declaration' ||
      node.type == 'abstract_class_declaration') {
    final id = childOfType(node, 'identifier') ??
        childOfType(node, 'type_identifier');
    if (id != null) bindings[ctx.view.textOf(id)] = BindingKind.setupConst;
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
