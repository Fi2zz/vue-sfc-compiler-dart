// Port of compiler-core vIf.ts: transformIf / processIf / branch codegen.
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import '../tmpl_error_messages.dart';
import 'transform_expression.dart';
import 'transform_utils.dart';

final transformIf = createStructuralDirectiveTransform(
  RegExp(r'^(?:if|else|else-if)$'),
  (node, dir, context) {
    return _processIf(node, dir, context, (ifNode, branch, isRoot) {
      final siblings = _siblingList(context);
      var i = siblings.indexOf(ifNode);
      var key = 0;
      while (i-- >= 0) {
        // JS reads siblings[-1] as undefined and skips it via truthiness guard.
        if (i < 0) break;
        final sibling = siblings[i];
        if (sibling is IfNode) {
          key += sibling.branches.length;
        }
      }
      return () => _assignBranchCodegen(ifNode, branch, isRoot, key, context);
    });
  },
);

List<TmplNode> _siblingList(TransformContext context) {
  final p = context.parent!;
  return switch (p) {
    RootNode n => n.children,
    ElementNode n => n.children,
    IfBranchNode n => n.children,
    ForNode n => n.children,
    _ => throw StateError('no children'),
  };
}

void _assignBranchCodegen(
  IfNode ifNode,
  IfBranchNode branch,
  bool isRoot,
  int key,
  TransformContext context,
) {
  if (isRoot) {
    ifNode.codegenNode = createCodegenNodeForBranch(branch, key, context);
  } else {
    final parentCondition = _getParentCondition(ifNode.codegenNode!);
    parentCondition.alternate = createCodegenNodeForBranch(
      branch,
      key + ifNode.branches.length - 1,
      context,
    );
  }
}

Object? _processIf(
  TmplNode node,
  DirectiveNode dir,
  TransformContext context,
  Object? Function(IfNode ifNode, IfBranchNode branch, bool isRoot)
  processCodegen,
) {
  if (dir.name != 'else' &&
      (dir.exp == null ||
          (dir.exp! as SimpleExpression).content.trim().isEmpty)) {
    final loc = dir.exp?.loc ?? node.loc;
    context.onError(
      TmplCompileError(28, 'v-if/v-else-if is missing expression.', dir.loc),
    );
    dir.exp = createSimpleExp('true', false, loc);
  }
  if (context.prefixIdentifiers && dir.exp != null) {
    dir.exp = processExpression(dir.exp! as SimpleExpression, context);
  }
  if (dir.name == 'if') {
    final branch = _createIfBranch(node, dir);
    final ifNode = IfNode([branch], _cloneLoc(node.loc));
    context.replaceNode(ifNode);
    return processCodegen(ifNode, branch, true);
  }
  return _attachElseBranch(node, dir, context, processCodegen);
}

Object? _attachElseBranch(
  TmplNode node,
  DirectiveNode dir,
  TransformContext context,
  Object? Function(IfNode ifNode, IfBranchNode branch, bool isRoot)
  processCodegen,
) {
  final siblings = _siblingList(context);
  final comments = <CommentNode>[];
  var i = siblings.indexOf(node);
  while (i-- >= -1) {
    final sibling = i >= 0 ? siblings[i] : null;
    if (sibling is CommentNode) {
      context.removeNode(sibling);
      comments.insert(0, sibling);
      continue;
    }
    if (sibling is TextNode && sibling.content.trim().isEmpty) {
      context.removeNode(sibling);
      continue;
    }
    if (sibling is IfNode) {
      _mergeIntoIfNode(node, dir, context, processCodegen, sibling, comments);
    } else {
      context.onError(
        TmplCompileError(
          30,
          'v-else/v-else-if has no adjacent v-if or v-else-if.',
          node.loc,
        ),
      );
    }
    break;
  }
  return null;
}

void _mergeIntoIfNode(
  TmplNode node,
  DirectiveNode dir,
  TransformContext context,
  Object? Function(IfNode ifNode, IfBranchNode branch, bool isRoot)
  processCodegen,
  IfNode sibling,
  List<CommentNode> comments,
) {
  if ((dir.name == 'else-if' || dir.name == 'else') &&
      sibling.branches.last.condition == null) {
    context.onError(
      TmplCompileError(
        30,
        'v-else/v-else-if has no adjacent v-if or v-else-if.',
        node.loc,
      ),
    );
  }
  context.removeNode();
  final branch = _createIfBranch(node, dir);
  if (comments.isNotEmpty && !_isTransitionChild(context)) {
    branch.children = [...comments, ...branch.children];
  }
  final key = branch.userKey;
  if (key != null) {
    for (final b in sibling.branches) {
      if (_isSameKey(b.userKey, key)) {
        context.onError(TmplCompileError(29, tmplErrorMessage(29), null));
      }
    }
  }
  sibling.branches.add(branch);
  final onExit = processCodegen(sibling, branch, false);
  traverseNode(branch, context);
  if (onExit is void Function()) onExit();
  context.currentNode = null;
}

bool _isTransitionChild(TransformContext context) {
  final parent = context.parent;
  return parent is ElementNode &&
      (parent.tag == 'transition' || parent.tag == 'Transition');
}

IfBranchNode _createIfBranch(TmplNode node, DirectiveNode dir) {
  final el = node as ElementNode;
  final isTemplateIf = el.tagType == etTemplate;
  return IfBranchNode(
    isTemplateIf && findDir(node, 'for') == null ? el.children : [node],
    el.loc,
    condition: dir.name == 'else' ? null : dir.exp,
    userKey: findProp(node, 'key'),
    isTemplateIf: isTemplateIf,
  );
}

Object createCodegenNodeForBranch(
  IfBranchNode branch,
  int keyIndex,
  TransformContext context,
) {
  final condition = branch.condition;
  if (condition != null) {
    // Registration order matters for the import preamble: helper() is called
    // while constructing the alternate, after the consequent is built.
    return JSConditionalExpression(
      condition,
      createChildrenCodegenNode(branch, keyIndex, context),
      createCallExp(context.helperString(hCreateComment), ['"v-if"', 'true']),
    );
  }
  return createChildrenCodegenNode(branch, keyIndex, context);
}

Object createChildrenCodegenNode(
  IfBranchNode branch,
  int keyIndex,
  TransformContext context,
) {
  final keyProperty = createObjectProp(
    'key',
    createSimpleExp('$keyIndex', false, null, ctCanHoist),
  );
  final children = branch.children;
  final firstChild = children.isNotEmpty ? children[0] : null;
  final needFragmentWrapper =
      children.length != 1 || firstChild is! ElementNode;
  if (needFragmentWrapper) {
    return _fragmentChildren(
      branch,
      keyIndex,
      keyProperty,
      context,
      children,
      firstChild,
    );
  }
  final ret = firstChild.codegenNode!;
  final vnodeCall = getMemoedVNodeCall(ret);
  if (vnodeCall is VNodeCall) {
    convertToBlock(vnodeCall, context);
  }
  injectProp(vnodeCall, keyProperty, context);
  return ret;
}

Object _fragmentChildren(
  IfBranchNode branch,
  int keyIndex,
  JSProperty keyProperty,
  TransformContext context,
  List<TmplNode> children,
  TmplNode? firstChild,
) {
  if (children.length == 1 && firstChild is ForNode) {
    final vnodeCall = firstChild.codegenNode!;
    injectProp(vnodeCall, keyProperty, context);
    return vnodeCall;
  }
  var patchFlag = 64;
  if (!branch.isTemplateIf &&
      children.where((c) => c.type != ntComment).length == 1) {
    patchFlag |= 2048;
  }
  context.helper(hFragment);
  return createVNodeCall(
    context,
    VNodeCallSpec(
      hFragment,
      props: createObjectExp([keyProperty]),
      children: children,
      patchFlag: patchFlag,
      isBlock: true,
      loc: branch.loc,
    ),
  );
}

JSConditionalExpression _getParentCondition(Object node) {
  var current = node;
  while (true) {
    if (current is JSConditionalExpression) {
      if (current.alternate is JSConditionalExpression) {
        current = current.alternate as JSConditionalExpression;
      } else {
        return current;
      }
    } else if (current is JSCacheExpression) {
      current = current.value!;
    }
  }
}

bool _isSameKey(Object? a, Object? b) {
  if (a == null || b == null || a.runtimeType != b.runtimeType) {
    return false;
  }
  if (a is AttributeNode && b is AttributeNode) {
    return a.value?.content == b.value?.content;
  }
  if (a is DirectiveNode && b is DirectiveNode) {
    final exp = a.exp;
    final branchExp = b.exp;
    if (exp is SimpleExpression && branchExp is SimpleExpression) {
      return exp.static_ == branchExp.static_ &&
          exp.content == branchExp.content;
    }
    return identical(exp, branchExp);
  }
  return false;
}

TmplLoc _cloneLoc(TmplLoc loc) {
  return TmplLoc(loc.start.clone(), loc.end.clone(), loc.source);
}
