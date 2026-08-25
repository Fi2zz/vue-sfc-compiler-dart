// Shared transform helpers: injectProp, hasScopeRef, getMemoedVNodeCall...
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';

const _propsHelperSet = {hNormalizeProps, hGuardReactiveProps};

(Object?, List<JSCallExpression>) _getUnnormalizedProps(
    Object? props, List<JSCallExpression> callPath) {
  var current = props;
  while (current is JSCallExpression &&
      current.callee is String &&
      _propsHelperSet.contains(current.callee)) {
    callPath.add(current);
    current = current.arguments.isNotEmpty ? current.arguments[0] : null;
  }
  return (current, callPath);
}

void injectProp(Object? node, JSProperty prop, TransformContext context) {
  // Official injectSlotKey (#15051): branch keys on renderSlot calls move
  // to the 6th argument instead of leaking into slot props.
  if (node is JSCallExpression && _injectSlotKey(node, prop)) {
    return;
  }
  Object? propsWithInjection;
  Object? props = node is VNodeCall
      ? node.props
      : (node as JSCallExpression).arguments.length > 2
          ? node.arguments[2]
          : null;
  var callPath = <JSCallExpression>[];
  JSCallExpression? parentCall;
  if (props is JSCallExpression) {
    final ret = _getUnnormalizedProps(props, callPath);
    props = ret.$1;
    callPath = ret.$2;
    parentCall = callPath.isNotEmpty ? callPath.last : null;
  }
  if (props == null || props is String) {
    propsWithInjection = createObjectExp([prop]);
  } else if (props is JSCallExpression) {
    final first = props.arguments.isNotEmpty ? props.arguments[0] : null;
    if (first is JSObjectExpression) {
      if (!hasProp(prop, first)) {
        first.properties.insert(0, prop);
      }
    } else {
      if (props.callee == hToHandlers) {
        context.helper(hMergeProps);
        propsWithInjection = createCallExp(
            hMergeProps, [createObjectExp([prop]), props]);
      } else {
        props.arguments.insert(0, createObjectExp([prop]));
      }
    }
    propsWithInjection ??= props;
  } else if (props is JSObjectExpression) {
    if (!hasProp(prop, props)) {
      props.properties.insert(0, prop);
    }
    propsWithInjection = props;
  } else {
    context.helper(hMergeProps);
    propsWithInjection = createCallExp(
        hMergeProps, [createObjectExp([prop]), props]);
    if (parentCall != null && parentCall.callee == hGuardReactiveProps) {
      parentCall = callPath[callPath.length - 2];
    }
  }
  _assignProps(node, propsWithInjection, parentCall);
}

/// Official injectSlotKey: a `key` property injected into a renderSlot call
/// pads the call to 6 arguments (`{}, undefined, undefined, key`) instead of
/// merging into the props object. Returns false for non-key properties so
/// injectProp falls through to normal prop injection.
bool _injectSlotKey(JSCallExpression node, JSProperty prop) {
  if (prop.key is! SimpleExpression ||
      (prop.key as SimpleExpression).content != 'key') {
    return false;
  }
  // A user-provided key keeps priority: skip branch key injection.
  final props = node.arguments.length > 2 ? node.arguments[2] : null;
  if (props != null && props is! String) {
    final unnormalized = _getUnnormalizedProps(props, <JSCallExpression>[]).$1;
    if (unnormalized is JSObjectExpression && hasProp(prop, unnormalized)) {
      return true;
    }
  }
  void pad(int index, String raw) {
    while (node.arguments.length <= index) {
      node.arguments.add(null);
    }
    final current = node.arguments[index];
    if (current == null || current == '') node.arguments[index] = raw;
  }

  pad(2, '{}');
  pad(3, 'undefined');
  pad(4, 'undefined');
  while (node.arguments.length <= 5) {
    node.arguments.add(null);
  }
  node.arguments[5] = prop.value;
  return true;
}

void _assignProps(
    Object? node, Object? propsWithInjection, JSCallExpression? parentCall) {
  if (node is VNodeCall) {
    if (parentCall != null) {
      parentCall.arguments[0] = propsWithInjection;
    } else {
      node.props = propsWithInjection;
    }
  } else if (node is JSCallExpression) {
    if (parentCall != null) {
      parentCall.arguments[0] = propsWithInjection;
    } else {
      // 官方依赖 JS arguments[2]= 的自动扩容语义（如 renderSlot 调用在
      // v-if 分支 key 注入时仅含 slots+name 两参）。
      while (node.arguments.length < 3) {
        node.arguments.add(null);
      }
      node.arguments[2] = propsWithInjection;
    }
  }
}

bool hasProp(JSProperty prop, JSObjectExpression props) {
  if (prop.key is! SimpleExpression) return false;
  final propKeyName = (prop.key as SimpleExpression).content;
  return props.properties.any((p) =>
      p.key is SimpleExpression &&
      (p.key as SimpleExpression).content == propKeyName);
}

Object? getMemoedVNodeCall(Object? node) {
  if (node is JSCallExpression && node.callee == hWithMemo) {
    final fn = node.arguments[1];
    if (fn is JSFunctionExpression) return fn.returns;
  }
  return node;
}

bool hasScopeRef(Object? node, Map<String, int> ids) {
  if (node == null || ids.isEmpty) return false;
  if (node is ElementNode) {
    for (final p in node.props) {
      if (p is DirectiveNode &&
          (hasScopeRef(p.arg, ids) || hasScopeRef(p.exp, ids))) {
        return true;
      }
    }
    return node.children.any((c) => hasScopeRef(c, ids));
  }
  if (node is ForNode) {
    return hasScopeRef(node.source, ids) ||
        node.children.any((c) => hasScopeRef(c, ids));
  }
  if (node is IfNode) {
    return node.branches.any((b) => hasScopeRef(b, ids));
  }
  if (node is IfBranchNode) {
    return hasScopeRef(node.condition, ids) ||
        node.children.any((c) => hasScopeRef(c, ids));
  }
  if (node is TextCallNode) return hasScopeRef(node.content, ids);
  return _leafScopeRef(node, ids);
}

bool _leafScopeRef(Object? node, Map<String, int> ids) {
  if (node is SimpleExpression) {
    return !node.static_ &&
        isSimpleIdentifier(node.content) &&
        (ids[node.content] ?? 0) != 0;
  }
  if (node is CompoundExpression) {
    return node.children
        .any((c) => c is! String && hasScopeRef(c, ids));
  }
  if (node is InterpolationNode) return hasScopeRef(node.content, ids);
  return false;
}

bool isNonWhitespaceContent(TmplNode node) {
  if (node.type != ntText && node.type != ntTextCall) return true;
  if (node is TextNode) return node.content.trim().isNotEmpty;
  if (node is TextCallNode) return isNonWhitespaceContent(node.content);
  return true;
}
