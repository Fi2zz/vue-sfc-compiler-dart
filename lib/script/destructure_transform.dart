// Port of transformDestructuredProps: rewrite references to destructured
// props (`const { msg } = defineProps(...)`) to `__props.msg` access,
// with scope-aware shadowing.
import 'package:vue_sfc_parser/ts_parser.dart';

import 'bindings.dart';
import 'mini_magic.dart';
import 'node_utils.dart';
import 'setup_context.dart';
import 'src_view.dart';

final _identRe = RegExp(r'^[_$a-zA-Z\xA0-￿][_$a-zA-Z0-9\xA0-￿]*$');

String genPropsAccessExp(String name) {
  return _identRe.hasMatch(name) ? '__props.$name' : '__props[${jsonEncode(name)}]';
}

String jsonEncode(String s) {
  final buf = StringBuffer('"');
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '"' || ch == '\\') {
      buf.write('\\$ch');
    } else if (rune < 0x20) {
      buf.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
    } else {
      buf.write(ch);
    }
  }
  buf.write('"');
  return buf.toString();
}

/// Subtrees that never contain runtime identifier references.
const _skipTypes = {
  'import_statement',
  'type_annotation',
  'type_arguments',
  'type_parameters',
  'type_alias_declaration',
  'interface_declaration',
  'ambient_declaration',
  'enum_declaration',
};

void transformDestructuredProps(
  SetupContext ctx,
  AstNode root,
  MiniMagic s,
  Map<String, String> vueImportAliases,
) {
  final scopeStack = <Map<String, bool>>[{}];
  final excludedIds = <AstNode>{};
  final localToPublic = <String, String>{};
  for (final entry in ctx.propsDestructuredBindings.entries) {
    scopeStack.first[entry.value.local] = true;
    localToPublic[entry.value.local] = entry.key;
  }

  Map<String, bool> currentScope() => scopeStack.last;

  bool scopeLookup(String name) {
    for (var i = scopeStack.length - 1; i >= 0; i--) {
      final v = scopeStack[i][name];
      if (v != null) return v;
    }
    return false;
  }

  void registerLocal(AstNode id) {
    excludedIds.add(id);
    currentScope()[ctx.view.textOf(id)] = false;
  }

  void walkVariableDeclaration(AstNode stmt, bool isRoot) {
    for (final decl in childrenOfType(stmt, 'variable_declarator')) {
      final id = decl.children.first;
      final init = _lastNonAnnotation(decl);
      final isDefineProps = isRoot &&
          init != null &&
          _isCallNamed(unwrapForCall(init), 'defineProps', ctx.view);
      for (final ident in extractIdentifiers(id)) {
        if (isDefineProps) {
          excludedIds.add(ident);
        } else {
          registerLocal(ident);
        }
      }
    }
  }

  void walkScope(List<AstNode> body, bool isRoot) {
    for (final stmt in body) {
      if (stmt.type == 'lexical_declaration' ||
          stmt.type == 'variable_declaration') {
        walkVariableDeclaration(stmt, isRoot);
      } else if (stmt.type == 'function_declaration' ||
          stmt.type == 'generator_function_declaration' ||
          stmt.type == 'class_declaration' ||
          stmt.type == 'abstract_class_declaration') {
        final id = childOfType(stmt, 'identifier') ??
            childOfType(stmt, 'type_identifier');
        if (id != null) registerLocal(id);
      } else if ((stmt.type == 'for_in_statement' ||
              stmt.type == 'for_of_statement') &&
          stmt.children.isNotEmpty &&
          (stmt.children.first.type == 'lexical_declaration' ||
              stmt.children.first.type == 'variable_declaration')) {
        walkVariableDeclaration(stmt.children.first, false);
      } else if (stmt.type == 'labeled_statement') {
        final body = stmt.children.isNotEmpty ? stmt.children.last : null;
        if (body != null &&
            (body.type == 'lexical_declaration' ||
                body.type == 'variable_declaration')) {
          walkVariableDeclaration(body, false);
        }
      }
    }
  }

  void registerParams(AstNode fn) {
    final params = childOfType(fn, 'formal_parameters');
    if (params == null) return;
    for (final p in params.children) {
      for (final id in extractIdentifiers(p)) {
        registerLocal(id);
      }
    }
  }

  void rewriteId(AstNode id, AstNode? parent) {
    if (parent != null &&
        ((parent.type == 'assignment_expression' &&
                identical(id, parent.children.first)) ||
            parent.type == 'augmented_assignment_expression' ||
            parent.type == 'update_expression')) {
      ctx.fail(
        'Cannot assign to destructured props as they are readonly.',
        id,
      );
    }
    final name = ctx.view.textOf(id);
    final access = genPropsAccessExp(localToPublic[name]!);
    if (id.type == 'shorthand_property_identifier') {
      s.appendLeft(ctx.abs(id.endByte), ': $access');
    } else {
      s.overwrite(ctx.abs(id.startByte), ctx.abs(id.endByte), access);
    }
  }

  void checkUsage(AstNode node, String method) {
    final alias = vueImportAliases[method];
    if (alias == null) return;
    if (!_isCallNamed(node, alias, ctx.view)) return;
    final args = childOfType(node, 'arguments');
    if (args == null || args.children.isEmpty) return;
    final arg = unwrapForCall(args.children.first);
    if (arg.type == 'identifier') {
      final name = ctx.view.textOf(arg);
      if (scopeLookup(name)) {
        ctx.fail(
          '"$name" is a destructured prop and should not be passed '
          'directly to $method(). '
          'Pass a getter () => $name instead.',
          arg,
        );
      }
    }
  }

  void walk(AstNode node, AstNode? parent) {
    if (_skipTypes.contains(node.type)) return;
    checkUsage(node, 'watch');
    checkUsage(node, 'toRef');
    if (isFunctionType(node)) {
      scopeStack.add({});
      registerParams(node);
      final body = childOfType(node, 'statement_block');
      if (body != null) walkScope(body.children, false);
      for (final c in node.children) {
        walk(c, node);
      }
      scopeStack.removeLast();
      return;
    }
    if (node.type == 'catch_clause') {
      scopeStack.add({});
      final param = childOfType(node, 'catch_parameter');
      if (param != null) {
        for (final id in extractIdentifiers(param)) {
          registerLocal(id);
        }
      }
      final body = childOfType(node, 'statement_block');
      if (body != null) walkScope(body.children, false);
      for (final c in node.children) {
        walk(c, node);
      }
      scopeStack.removeLast();
      return;
    }
    if (node.type == 'statement_block' &&
        (parent == null || !isFunctionType(parent))) {
      scopeStack.add({});
      walkScope(node.children, false);
      for (final c in node.children) {
        walk(c, node);
      }
      scopeStack.removeLast();
      return;
    }
    if (node.type == 'identifier' ||
        node.type == 'shorthand_property_identifier') {
      if (!excludedIds.contains(node) &&
          _isReferencedIdentifier(node, parent) &&
          scopeLookup(ctx.view.textOf(node))) {
        rewriteId(node, parent);
      }
      return;
    }
    for (final c in node.children) {
      walk(c, node);
    }
  }

  walkScope(root.children, true);
  for (final stmt in root.children) {
    walk(stmt, null);
  }
}

AstNode? _lastNonAnnotation(AstNode declarator) {
  if (declarator.children.length < 2) return null;
  final last = declarator.children.last;
  if (last.type == 'type_annotation') return null;
  return last;
}

bool _isCallNamed(AstNode? node, String name, SrcView view) {
  if (node == null || node.type != 'call_expression') return false;
  final id = childOfType(node, 'identifier');
  return id != null && view.textOf(id) == name;
}

bool _isReferencedIdentifier(AstNode node, AstNode? parent) {
  if (parent == null) return true;
  switch (parent.type) {
    case 'variable_declarator':
      return !identical(node, parent.children.first);
    case 'pair':
      // shorthand handled separately; pair keys are property_identifier
      return true;
    case 'import_specifier':
    case 'export_specifier':
    case 'namespace_import':
    case 'catch_parameter':
      return false;
    case 'function_declaration':
    case 'generator_function_declaration':
    case 'class_declaration':
    case 'abstract_class_declaration':
    case 'method_definition':
      // declaration name position
      return !identical(node, parent.children.first);
    case 'required_parameter':
    case 'optional_parameter':
    case 'rest_pattern':
    case 'object_pattern':
    case 'array_pattern':
      return false;
    default:
      return true;
  }
}
