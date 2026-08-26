// Port of compiler-core cacheStatic walk + getConstantType family
// (transforms/hoistStatic.ts).
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';

const _allowHoistedHelperSet = {
  hNormalizeClass,
  hNormalizeStyle,
  hNormalizeProps,
  hGuardReactiveProps,
};

void cacheStatic(RootNode root, TransformContext context) {
  // Root node is non-hoistable (potential parent fallthrough attrs): a lone
  // root element child is walked with doNotHoistNode = true.
  _walk(root, null, context, _singleElementRoot(root) != null, false);
}

ElementNode? _singleElementRoot(RootNode root) {
  final children = root.children.where((c) => c is! CommentNode).toList();
  return children.length == 1 &&
          children[0] is ElementNode &&
          !isSlotOutlet(children[0])
      ? children[0] as ElementNode
      : null;
}

void _walk(
  TmplNode node,
  TmplNode? parent,
  TransformContext context,
  bool doNotHoistNode,
  bool inFor,
) {
  final children = _children(node);
  // Lazily allocated: most containers have no hoistable children.
  List<TmplNode>? toCache;
  for (var i = 0; i < children.length; i++) {
    final child = children[i];
    if (child is ElementNode && child.tagType == etElement) {
      final constantType = doNotHoistNode ? 0 : getConstantType(child, context);
      if (constantType > 0) {
        if (constantType >= ctCanHoist) {
          (child.codegenNode as VNodeCall).patchFlag = -1;
          (toCache ??= []).add(child);
          continue;
        }
      } else {
        final codegenNode = child.codegenNode;
        if (codegenNode is VNodeCall) {
          final flag = codegenNode.patchFlag;
          if ((flag == null || flag == 512 || flag == 1) &&
              getGeneratedPropsConstantType(child, context) >= ctCanHoist) {
            final props = getNodeProps(child);
            if (props != null) {
              codegenNode.props = context.hoist(props);
            }
          }
          if (codegenNode.dynamicProps != null) {
            codegenNode.dynamicProps = context.hoist(codegenNode.dynamicProps);
          }
        }
      }
    } else if (child is TextCallNode) {
      final constantType = doNotHoistNode ? 0 : getConstantType(child, context);
      if (constantType >= ctCanHoist) {
        final cn = child.codegenNode;
        if (cn is JSCallExpression && cn.arguments.isNotEmpty) {
          cn.arguments.add('-1 /* ${patchFlagNames[-1]} */');
        }
        (toCache ??= []).add(child);
        continue;
      }
    }
    _walkChild(child, node, context, inFor);
  }
  final caching = toCache ?? const <TmplNode>[];
  var cachedAsArray = _tryCacheAsArray(
    node,
    parent,
    children,
    caching,
    context,
  );
  if (!cachedAsArray) {
    for (final child in caching) {
      _setCodegenNode(child, context.cache(_codegenNodeOf(child)));
    }
  }
  if (caching.isNotEmpty && context.transformHoist != null) {
    context.transformHoist!(children, context, node);
  }
}

void _walkChild(
  TmplNode child,
  TmplNode node,
  TransformContext context,
  bool inFor,
) {
  if (child is ElementNode) {
    final isComponent = child.tagType == etComponent;
    if (isComponent) context.scopes.vSlot++;
    _walk(child, node, context, false, inFor);
    if (isComponent) context.scopes.vSlot--;
  } else if (child is ForNode) {
    _walk(child, node, context, child.children.length == 1, true);
  } else if (child is IfNode) {
    for (final branch in child.branches) {
      _walk(branch, node, context, branch.children.length == 1, inFor);
    }
  }
}

bool _tryCacheAsArray(
  TmplNode node,
  TmplNode? parent,
  List<TmplNode> children,
  List<TmplNode> toCache,
  TransformContext context,
) {
  if (toCache.length != children.length || node is! ElementNode) {
    return false;
  }
  JSCacheExpression wrapArray(Object? value) {
    final exp = context.cache(value);
    exp.needArraySpread = true;
    return exp;
  }

  final codegenNode = node.codegenNode;
  if (node.tagType == etElement &&
      codegenNode is VNodeCall &&
      codegenNode.children is List) {
    codegenNode.children = wrapArray(
      createArrayExp(List<Object?>.of(codegenNode.children as List)),
    );
    return true;
  }
  if (node.tagType == etComponent && codegenNode is VNodeCall) {
    final slot = _getSlotNode(codegenNode.children, 'default');
    if (slot != null) {
      slot.returns = wrapArray(
        createArrayExp(List<Object?>.of(slot.returns as List)),
      );
      return true;
    }
  }
  if (node.tagType == etTemplate && parent is ElementNode) {
    final parentCn = parent.codegenNode;
    if (parent.tagType == etComponent &&
        parentCn is VNodeCall &&
        parentCn.children is JSObjectExpression) {
      final slotDir = findDir(node, 'slot', true);
      final slot = slotDir?.arg != null
          ? _getSlotNodeFromArg(parentCn.children, slotDir!.arg!)
          : null;
      if (slot != null) {
        slot.returns = wrapArray(
          createArrayExp(List<Object?>.of(slot.returns as List)),
        );
        return true;
      }
    }
  }
  return false;
}

JSFunctionExpression? _getSlotNode(Object? children, String name) {
  if (children is JSObjectExpression) {
    for (final p in children.properties) {
      if (p.key is SimpleExpression &&
          (p.key as SimpleExpression).content == name) {
        return p.value as JSFunctionExpression?;
      }
    }
  }
  return null;
}

JSFunctionExpression? _getSlotNodeFromArg(Object? children, Object arg) {
  // 官方语义：p.key === name || p.key.content === name——name 是 arg 节点，
  // content(string) 永远不等于节点，实际只有对象身份能命中。重复插槽名
  // （dup names）因此匹配失败，走官方的逐子缓存回退路径。
  if (children is JSObjectExpression) {
    for (final p in children.properties) {
      if (identical(p.key, arg)) {
        return p.value as JSFunctionExpression?;
      }
    }
  }
  return null;
}

List<TmplNode> _children(TmplNode node) => switch (node) {
  RootNode n => n.children,
  ElementNode n => n.children,
  IfBranchNode n => n.children,
  ForNode n => n.children,
  _ => const [],
};

Object? _codegenNodeOf(TmplNode node) => switch (node) {
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

int getConstantType(TmplNode node, TransformContext context) {
  final constantCache = context.constantCache;
  switch (node.type) {
    case ntElement:
      final el = node as ElementNode;
      if (el.tagType != etElement) return 0;
      final cached = constantCache[node];
      if (cached != null) return cached;
      final codegenNode = el.codegenNode;
      if (codegenNode is! VNodeCall) return 0;
      if (codegenNode.isBlock &&
          el.tag != 'svg' &&
          el.tag != 'foreignObject' &&
          el.tag != 'math') {
        return 0;
      }
      if (codegenNode.patchFlag != null) {
        constantCache[node] = 0;
        return 0;
      }
      return _elementConstantType(el, codegenNode, context);
    case ntText:
    case ntComment:
      return ctCanStringify;
    case ntIf:
    case ntFor:
    case ntIfBranch:
      return 0;
    case ntInterpolation:
    case ntTextCall:
      return getConstantType(_contentOf(node), context);
    case ntSimpleExpression:
      return (node as SimpleExpression).constType;
    case ntCompoundExpression:
      return _compoundConstantType(node as CompoundExpression, context);
    case ntJSCacheExpression:
      return ctCanHoist;
    default:
      return 0;
  }
}

int _elementConstantType(
  ElementNode node,
  VNodeCall codegenNode,
  TransformContext context,
) {
  var returnType = ctCanStringify;
  final generatedPropsType = getGeneratedPropsConstantType(node, context);
  if (generatedPropsType == 0) {
    context.constantCache[node] = 0;
    return 0;
  }
  if (generatedPropsType < returnType) returnType = generatedPropsType;
  for (final child in node.children) {
    final childType = getConstantType(child, context);
    if (childType == 0) {
      context.constantCache[node] = 0;
      return 0;
    }
    if (childType < returnType) returnType = childType;
  }
  returnType = _bindPropsConstantType(node, returnType, context);
  if (returnType == 0) return 0;
  // 官方：isBlock 且含任意指令 → 0；无指令的 block 降级为普通 vnode。
  // 返回值必须传播（此前 0 被吞掉导致带指令元素仍被整体缓存）。
  returnType = _maybeUnblock(node, codegenNode, context, returnType);
  context.constantCache[node] = returnType;
  return returnType;
}

int _bindPropsConstantType(
  ElementNode node,
  int returnType,
  TransformContext context,
) {
  if (returnType <= ctCanSkipPatch) return returnType;
  for (final p in node.props) {
    if (p is DirectiveNode && p.name == 'bind' && p.exp != null) {
      final expType = getConstantType(p.exp!, context);
      if (expType == 0) {
        context.constantCache[node] = 0;
        return 0;
      }
      if (expType < returnType) returnType = expType;
    }
  }
  return returnType;
}

int _maybeUnblock(
  ElementNode node,
  VNodeCall codegenNode,
  TransformContext context,
  int returnType,
) {
  if (!codegenNode.isBlock) return returnType;
  for (final p in node.props) {
    if (p is DirectiveNode) {
      context.constantCache[node] = 0;
      return 0;
    }
  }
  context.removeHelper(hOpenBlock);
  context.removeHelper(
    getVNodeBlockHelper(context.inSSR, codegenNode.isComponent),
  );
  codegenNode.isBlock = false;
  context.helper(getVNodeHelper(context.inSSR, codegenNode.isComponent));
  return returnType;
}

TmplNode _contentOf(TmplNode node) => switch (node) {
  InterpolationNode n => n.content,
  TextCallNode n => n.content,
  _ => node,
};

int _compoundConstantType(CompoundExpression node, TransformContext context) {
  var returnType = ctCanStringify;
  for (final child in node.children) {
    if (child is String) continue;
    if (child is! TmplNode) continue;
    final childType = getConstantType(child, context);
    if (childType == 0) {
      return 0;
    } else if (childType < returnType) {
      returnType = childType;
    }
  }
  return returnType;
}

int _getConstantTypeOfHelperCall(Object? value, TransformContext context) {
  if (value is JSCallExpression &&
      value.callee is String &&
      _allowHoistedHelperSet.contains(value.callee)) {
    final arg = value.arguments.isNotEmpty ? value.arguments[0] : null;
    if (arg is SimpleExpression) {
      return getConstantType(arg, context);
    } else if (arg is JSCallExpression) {
      return _getConstantTypeOfHelperCall(arg, context);
    }
  }
  return 0;
}

int getGeneratedPropsConstantType(ElementNode node, TransformContext context) {
  var returnType = ctCanStringify;
  final props = getNodeProps(node);
  if (props is JSObjectExpression) {
    for (final property in props.properties) {
      final keyType = getConstantType(property.key as TmplNode, context);
      if (keyType == 0) return keyType;
      if (keyType < returnType) returnType = keyType;
      final value = property.value;
      int valueType;
      if (value is SimpleExpression) {
        valueType = getConstantType(value, context);
      } else if (value is JSCallExpression) {
        valueType = _getConstantTypeOfHelperCall(value, context);
      } else {
        valueType = 0;
      }
      if (valueType == 0) return valueType;
      if (valueType < returnType) returnType = valueType;
    }
  }
  return returnType;
}

Object? getNodeProps(ElementNode node) {
  final codegenNode = node.codegenNode;
  if (codegenNode is VNodeCall) return codegenNode.props;
  return null;
}
