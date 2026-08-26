// Port of compiler-core vFor.ts: transformFor / processFor / helpers.
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import '../tmpl_error_messages.dart';
import 'transform_expression.dart';
import 'transform_utils.dart';

final transformFor = createStructuralDirectiveTransform('for', (
  node,
  dir,
  context,
) {
  return _processFor(node, dir, context, (forNode) {
    context.helper(hRenderList);
    final renderExp = createCallExp(hRenderList, [forNode.source]);
    final isTemplate = isTemplateNode(node);
    final memo = findDir(node, 'memo');
    final keyProp = findProp(node, 'key', false, true);
    final isDirKey = keyProp is DirectiveNode;
    TmplNode? keyExp = _keyExpOf(keyProp);
    if (memo != null && keyExp != null && isDirKey) {
      keyProp.exp = keyExp = processExpression(
        keyExp as SimpleExpression,
        context,
      );
    }
    final keyProperty = keyProp != null && keyExp != null
        ? createObjectProp('key', keyExp)
        : null;
    if (memo != null && keyProperty != null && isDirKey) {
      // Official vForMemoKeyedNodes: the :key expression was processed here,
      // so transformExpression must skip it (avoids double processing).
      context.vForMemoKeyedNodes.add(node);
    }
    _processTemplateMemoAndKey(node, memo, keyProp, keyProperty, context);
    final src = forNode.source;
    final isStableFragment = src is SimpleExpression && src.constType > 0;
    final fragmentFlag = isStableFragment ? 64 : (keyProp != null ? 128 : 256);
    context.helper(hFragment);
    forNode.codegenNode = createVNodeCall(
      context,
      VNodeCallSpec(
        hFragment,
        children: renderExp,
        patchFlag: fragmentFlag,
        isBlock: true,
        disableTracking: !isStableFragment,
        loc: node.loc,
      ),
    );
    return () => _finishForCodegen(
      node,
      dir,
      context,
      forNode,
      renderExp,
      isTemplate,
      memo,
      keyProp,
      keyProperty,
      isStableFragment,
    );
  });
});

TmplNode? _keyExpOf(Object? keyProp) {
  if (keyProp is AttributeNode) {
    final v = keyProp.value;
    return v != null ? createSimpleExp(v.content, true) : null;
  }
  if (keyProp is DirectiveNode) return keyProp.exp;
  return null;
}

void _processTemplateMemoAndKey(
  TmplNode node,
  DirectiveNode? memo,
  Object? keyProp,
  JSProperty? keyProperty,
  TransformContext context,
) {
  if (!isTemplateNode(node)) return;
  if (memo != null && memo.exp != null) {
    memo.exp = processExpression(memo.exp! as SimpleExpression, context);
  }
  if (keyProperty != null && keyProp is! AttributeNode) {
    final value = keyProperty.value;
    if (value is SimpleExpression) {
      keyProperty.value = processExpression(value, context);
    }
  }
}

void _finishForCodegen(
  TmplNode node,
  DirectiveNode dir,
  TransformContext context,
  ForNode forNode,
  JSCallExpression renderExp,
  bool isTemplate,
  DirectiveNode? memo,
  Object? keyProp,
  JSProperty? keyProperty,
  bool isStableFragment,
) {
  Object childBlock;
  final children = forNode.children;
  if (isTemplate) {
    _errorOnChildKeys(node, context);
  }
  final needFragmentWrapper =
      children.length != 1 || children[0] is! ElementNode;
  final slotOutlet = _forSlotOutlet(node, isTemplate);
  if (slotOutlet != null) {
    childBlock = (slotOutlet as ElementNode).codegenNode!;
    if (isTemplate && keyProperty != null) {
      injectProp(childBlock, keyProperty, context);
    }
  } else if (needFragmentWrapper) {
    context.helper(hFragment);
    childBlock = createVNodeCall(
      context,
      VNodeCallSpec(
        hFragment,
        props: keyProperty != null ? createObjectExp([keyProperty]) : null,
        children: (node as ElementNode).children,
        patchFlag: 64,
        isBlock: true,
      ),
    );
  } else {
    childBlock = _adjustChildBlock(
      children[0] as ElementNode,
      isTemplate,
      keyProperty,
      isStableFragment,
      context,
    );
  }
  _pushForRenderArgs(
    renderExp,
    forNode,
    memo,
    keyProperty,
    childBlock,
    context,
  );
}

void _errorOnChildKeys(TmplNode node, TransformContext context) {
  for (final c in (node as ElementNode).children) {
    if (c is ElementNode) {
      final key = findProp(c, 'key');
      if (key != null) {
        context.onError(
          TmplCompileError(
            33,
            '<template v-for> key should be placed on the <template> tag.',
            _locOf(key),
          ),
        );
        return;
      }
    }
  }
}

TmplLoc? _locOf(Object prop) =>
    prop is AttributeNode ? prop.loc : (prop as DirectiveNode).loc;

Object? _forSlotOutlet(TmplNode node, bool isTemplate) {
  if (isSlotOutlet(node)) return node;
  if (isTemplate) {
    final children = (node as ElementNode).children;
    if (children.length == 1 && isSlotOutlet(children[0])) {
      return children[0];
    }
  }
  return null;
}

Object _adjustChildBlock(
  ElementNode child,
  bool isTemplate,
  JSProperty? keyProperty,
  bool isStableFragment,
  TransformContext context,
) {
  final childBlock = child.codegenNode! as VNodeCall;
  if (isTemplate && keyProperty != null) {
    injectProp(childBlock, keyProperty, context);
  }
  if (childBlock.isBlock != !isStableFragment) {
    if (childBlock.isBlock) {
      context.removeHelper(hOpenBlock);
      context.removeHelper(
        getVNodeBlockHelper(context.inSSR, childBlock.isComponent),
      );
    } else {
      context.removeHelper(
        getVNodeHelper(context.inSSR, childBlock.isComponent),
      );
    }
  }
  childBlock.isBlock = !isStableFragment;
  if (childBlock.isBlock) {
    context.helper(hOpenBlock);
    context.helper(getVNodeBlockHelper(context.inSSR, childBlock.isComponent));
  } else {
    context.helper(getVNodeHelper(context.inSSR, childBlock.isComponent));
  }
  return childBlock;
}

void _pushForRenderArgs(
  JSCallExpression renderExp,
  ForNode forNode,
  DirectiveNode? memo,
  JSProperty? keyProperty,
  Object childBlock,
  TransformContext context,
) {
  if (memo != null) {
    _pushMemoLoop(renderExp, forNode, memo, keyProperty, childBlock, context);
  } else {
    renderExp.arguments.add(
      JSFunctionExpression(
        createForLoopParams(forNode.parseResult),
        childBlock,
        newline: true,
      ),
    );
  }
}

void _pushMemoLoop(
  JSCallExpression renderExp,
  ForNode forNode,
  DirectiveNode memo,
  JSProperty? keyProperty,
  Object childBlock,
  TransformContext context,
) {
  final loop = JSFunctionExpression(
    createForLoopParams(forNode.parseResult, [createSimpleExp('_cached')]),
    null,
  );
  final keyExp = keyProperty?.value;
  loop.body = JSBlockStatement([
    createCompoundExp(['const _memo = (', memo.exp, ')']),
    createCompoundExp([
      'if (_cached && _cached.el',
      if (keyExp != null) ...[' && _cached.key === ', keyExp],
      ' && ${context.helperString(hIsMemoSame)}(_cached, _memo)) return _cached',
    ]),
    createCompoundExp(['const _item = ', childBlock]),
    createSimpleExp('_item.memo = _memo'),
    createSimpleExp('return _item'),
  ]);
  renderExp.arguments.add(loop);
  renderExp.arguments.add(createSimpleExp('_cache'));
  renderExp.arguments.add(createSimpleExp('${context.cached.length}'));
  context.cached.add(null);
}

Object? _processFor(
  TmplNode node,
  DirectiveNode dir,
  TransformContext context,
  Object? Function(ForNode forNode) processCodegen,
) {
  if (dir.exp == null) {
    context.onError(
      TmplCompileError(31, 'v-for is missing expression.', dir.loc),
    );
    return null;
  }
  final parseResult = dir.forParseResult;
  if (parseResult == null) {
    context.onError(TmplCompileError(32, tmplErrorMessage(32), dir.loc));
    return null;
  }
  finalizeForParseResult(parseResult, context);
  final forNode = ForNode(
    parseResult.source,
    parseResult,
    isTemplateNode(node) ? (node as ElementNode).children : [node],
    dir.loc,
    valueAlias: parseResult.value,
    keyAlias: parseResult.key,
    objectIndexAlias: parseResult.index,
  );
  context.replaceNode(forNode);
  context.scopes.vFor++;
  _forIdentifiers(context, parseResult, true);
  final onExit = processCodegen(forNode);
  return () {
    context.scopes.vFor--;
    _forIdentifiers(context, parseResult, false);
    if (onExit is void Function()) onExit();
  };
}

void _forIdentifiers(
  TransformContext context,
  ForParseResult result,
  bool add,
) {
  if (!context.prefixIdentifiers) return;
  void Function(Object?) op = add
      ? context.addIdentifiers
      : context.removeIdentifiers;
  if (result.value != null) op(result.value);
  if (result.key != null) op(result.key);
  if (result.index != null) op(result.index);
}

void finalizeForParseResult(ForParseResult result, TransformContext context) {
  if (result.finalized) return;
  if (context.prefixIdentifiers) {
    result.source = processExpression(
      result.source as SimpleExpression,
      context,
    );
    if (result.key != null) {
      result.key = processExpression(
        result.key! as SimpleExpression,
        context,
        asParams: true,
      );
    }
    if (result.index != null) {
      result.index = processExpression(
        result.index! as SimpleExpression,
        context,
        asParams: true,
      );
    }
    if (result.value != null) {
      result.value = processExpression(
        result.value! as SimpleExpression,
        context,
        asParams: true,
      );
    }
  }
  result.finalized = true;
}

List<Object?> createForLoopParams(
  ForParseResult result, [
  List<SimpleExpression> memoArgs = const [],
]) {
  return _createParamsList([
    result.value,
    result.key,
    result.index,
    ...memoArgs,
  ]);
}

List<Object?> _createParamsList(List<Object?> args) {
  var i = args.length;
  while (i-- > 0) {
    if (args[i] != null) break;
  }
  return args
      .sublist(0, i + 1)
      .asMap()
      .entries
      .map((e) => e.value ?? createSimpleExp('_' * (e.key + 1)))
      .toList();
}
