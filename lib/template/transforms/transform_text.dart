// Port of compiler-core transformText.
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import 'hoist_static.dart';

Object? transformText(TmplNode node, TransformContext context) {
  if (node is! RootNode &&
      node is! ElementNode &&
      node is! ForNode &&
      node is! IfBranchNode) {
    return null;
  }
  return () => _mergeTextChildren(node, context);
}

void _mergeTextChildren(TmplNode node, TransformContext context) {
  final children = _childrenOfNode(node);
  CompoundExpression? currentContainer;
  var hasText = false;
  for (var i = 0; i < children.length; i++) {
    final child = children[i];
    if (isTextNode(child)) {
      hasText = true;
      for (var j = i + 1; j < children.length; j++) {
        final next = children[j];
        if (isTextNode(next)) {
          currentContainer ??= children[i] = _compoundOf(child);
          currentContainer.children.add(' + ');
          currentContainer.children.add(next);
          children.removeAt(j);
          j--;
        } else {
          currentContainer = null;
          break;
        }
      }
    }
  }
  if (!hasText || _keepSingleTextChild(node, children, context)) {
    return;
  }
  _wrapTextCalls(children, context);
}

CompoundExpression _compoundOf(TmplNode child) {
  return createCompoundExp([child], child.loc);
}

bool _keepSingleTextChild(
    TmplNode node, List<TmplNode> children, TransformContext context) {
  if (children.length != 1) return false;
  if (node is RootNode) return true;
  if (node is! ElementNode || node.tagType != etElement) return false;
  final hasCustomDir = node.props.any((p) =>
      p is DirectiveNode &&
      !context.directiveTransforms.containsKey(p.name));
  return !hasCustomDir && node.tag != 'template';
}

void _wrapTextCalls(List<TmplNode> children, TransformContext context) {
  for (var i = 0; i < children.length; i++) {
    final child = children[i];
    if (isTextNode(child) || child is CompoundExpression) {
      final callArgs = <Object?>[];
      if (child is! TextNode || child.content != ' ') {
        callArgs.add(child);
      }
      if (!context.ssr && getConstantType(child, context) == 0) {
        callArgs.add('1 /* ${patchFlagNames[1]} */');
      }
      context.helper(hCreateText);
      children[i] = TextCallNode(child, child.loc)
        ..codegenNode = createCallExp(hCreateText, callArgs);
    }
  }
}

List<TmplNode> _childrenOfNode(TmplNode node) => switch (node) {
      RootNode n => n.children,
      ElementNode n => n.children,
      ForNode n => n.children,
      IfBranchNode n => n.children,
      _ => throw StateError('no children'),
    };
