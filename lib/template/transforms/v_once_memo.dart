// Ports of compiler-core vOnce.ts / vMemo.ts / transformVBindShorthand.
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import '../tmpl_error_messages.dart';

final _seenOnce = <TmplNode>{};
final _seenMemo = <TmplNode>{};

Object? transformOnce(TmplNode node, TransformContext context) {
  if (node is ElementNode && findDir(node, 'once', true) != null) {
    if (_seenOnce.contains(node) || context.inVOnce || context.inSSR) {
      return null;
    }
    _seenOnce.add(node);
    context.inVOnce = true;
    context.helper(hSetBlockTracking);
    return () {
      context.inVOnce = false;
      final cur = context.currentNode;
      final codegenNode = cur == null ? null : _codegenNodeOf(cur);
      if (cur != null && codegenNode != null) {
        _setCodegenNode(cur, context.cache(codegenNode, true, true));
      }
    };
  }
  return null;
}

Object? transformMemo(TmplNode node, TransformContext context) {
  if (node is! ElementNode) return null;
  final dir = findDir(node, 'memo');
  if (dir == null || _seenMemo.contains(node) || context.inSSR) {
    return null;
  }
  _seenMemo.add(node);
  return () {
    final codegenNode = node.codegenNode ?? _codegenNodeOf(context.currentNode);
    if (codegenNode is VNodeCall) {
      if (node.tagType != etComponent) {
        convertToBlock(codegenNode, context);
      }
      context.helper(hWithMemo);
      node.codegenNode = createCallExp(hWithMemo, [
        dir.exp,
        JSFunctionExpression(null, codegenNode),
        '_cache',
        '${context.cached.length}',
      ]);
      context.cached.add(null);
    }
  };
}

Object? _codegenNodeOf(TmplNode? node) => switch (node) {
  ElementNode n => n.codegenNode,
  TextCallNode n => n.codegenNode,
  IfNode n => n.codegenNode,
  ForNode n => n.codegenNode,
  _ => null,
};

void _setCodegenNode(TmplNode node, Object? codegenNode) {
  switch (node) {
    case ElementNode n:
      n.codegenNode = codegenNode;
    case TextCallNode n:
      n.codegenNode = codegenNode;
    case IfNode n:
      n.codegenNode = codegenNode;
    case ForNode n:
      n.codegenNode = codegenNode;
    default:
      break;
  }
}

final _validFirstIdentCharRE = RegExp(r'[A-Za-z_$\xA0-￿]');

Object? transformVBindShorthand(TmplNode node, TransformContext context) {
  if (node is! ElementNode) return null;
  for (final prop in node.props) {
    if (prop is DirectiveNode &&
        prop.name == 'bind' &&
        prop.exp == null &&
        prop.arg != null) {
      final arg = prop.arg!;
      if (arg is! SimpleExpression || !arg.static_) {
        context.onError(TmplCompileError(52, tmplErrorMessage(52), arg.loc));
        prop.exp = createSimpleExp('', true, arg.loc);
      } else {
        final propName = camelize(arg.content);
        final first = propName.isEmpty ? '' : propName[0];
        if (_validFirstIdentCharRE.hasMatch(first) || first == '-') {
          prop.exp = createSimpleExp(propName, false, arg.loc);
        }
      }
    }
  }
  return null;
}
