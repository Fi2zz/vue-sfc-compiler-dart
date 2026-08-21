// Port of the official top-level await transform (processAwait + the
// scope-tracking statement walk in compileScript).
import 'package:vue_sfc_parser/ts_parser.dart';

import 'mini_magic.dart';
import 'node_utils.dart';
import 'setup_context.dart';

final _awaitRe = RegExp(r'\bawait\b');

/// Walk a top-level statement for await expressions, mirroring the official
/// enter/exit walker with block-scope tracking.
void walkForAwait(
  SetupContext ctx,
  AstNode node,
  MiniMagic s,
  List<AstNode> rootBody,
) {
  final scopeStack = <List<AstNode>>[rootBody];

  void enter(AstNode child, AstNode? parent) {
    if (isFunctionType(child)) return; // skip subtree
    if (child.type == 'statement_block') {
      scopeStack.add(child.children);
    }
    if (child.type == 'await_expression') {
      ctx.hasAwait = true;
      final currentScope = scopeStack.last;
      final needsSemi = _needsSemi(currentScope, scopeStack.length, child);
      _processAwait(ctx, child, needsSemi, parent?.type == 'expression_statement', s);
    }
    for (final c in child.children) {
      if (isFunctionType(c)) continue;
      enter(c, child);
    }
    if (child.type == 'statement_block') {
      scopeStack.removeLast();
    }
  }

  if (isFunctionType(node)) return;
  for (final c in node.children) {
    if (isFunctionType(c)) continue;
    enter(c, node);
  }
}

bool _needsSemi(List<AstNode> scope, int scopeLen, AstNode awaitNode) {
  for (var i = 0; i < scope.length; i++) {
    final n = scope[i];
    if ((scopeLen == 1 || i > 0) &&
        n.type == 'expression_statement' &&
        n.startByte == awaitNode.startByte) {
      return true;
    }
  }
  return false;
}

void _processAwait(
  SetupContext ctx,
  AstNode node,
  bool needSemi,
  bool isStatement,
  MiniMagic s,
) {
  final argument = node.children.isEmpty ? null : node.children.first;
  if (argument == null) return;
  // tree-sitter parenthesized_expression starts at '(', matching babel's
  // extra.parenStart, so the argument start is always correct here.
  final argumentStart = argument.startByte;
  final argumentStr =
      ctx.source.substring(ctx.abs(argumentStart), ctx.abs(argument.endByte));
  final containsNestedAwait = _awaitRe.hasMatch(argumentStr);

  s.overwrite(
    ctx.abs(node.startByte),
    ctx.abs(argumentStart),
    '${needSemi ? ';' : ''}(\n  ([__temp,__restore] = '
        '${ctx.helper('withAsyncContext')}('
        '${containsNestedAwait ? 'async ' : ''}() => ',
  );
  s.appendLeft(
    ctx.abs(node.endByte),
    ')),\n  ${isStatement ? '' : '__temp = '}await __temp,\n  __restore()'
        '${isStatement ? '' : ',\n  __temp'}\n)',
  );
}
