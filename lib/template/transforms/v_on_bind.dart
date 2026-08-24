// Ports of compiler-core transformOn / transformBind.
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import '../tmpl_error_messages.dart';
import 'transform_expression.dart';
import 'transform_utils.dart';

typedef OnAugmentor = DirTransformResult Function(DirTransformResult result);

DirTransformResult transformOnCore(DirectiveNode dir, ElementNode node,
    TransformContext context,
    [OnAugmentor? augmentor]) {
  final loc = dir.loc;
  final modifiers = dir.modifiers;
  final arg = dir.arg;
  if (dir.exp == null && modifiers.isEmpty) {
    context.onError(
        TmplCompileError(35, 'v-on is missing expression.', loc));
  }
  final eventName = _resolveEventName(dir, node, context, arg);
  TmplNode? exp = dir.exp;
  if (exp is SimpleExpression && exp.content.trim().isEmpty) exp = null;
  var shouldCache =
      context.cacheHandlers && exp == null && !context.inVOnce;
  final handlerResult =
      _processHandlerExp(node, context, dir, exp as SimpleExpression?);
  exp = handlerResult.$1;
  shouldCache = handlerResult.$2 ?? shouldCache;
  var ret = DirTransformResult([
    createObjectProp(eventName,
        exp ?? createSimpleExp('() => {}', false, loc))
  ]);
  if (augmentor != null) ret = augmentor(ret);
  if (shouldCache) {
    ret.props[0].value = context.cache(ret.props[0].value);
  }
  // 官方：ret.props.forEach((p) => p.key.isHandlerKey = true)——不区分
  // SimpleExpression / CompoundExpression。
  for (final p in ret.props) {
    final k = p.key;
    if (k is SimpleExpression) k.isHandlerKey = true;
    if (k is CompoundExpression) k.isHandlerKey = true;
  }
  return ret;
}

Object _resolveEventName(DirectiveNode dir, ElementNode node,
    TransformContext context, Object? arg) {
  if (arg is SimpleExpression) {
    if (arg.static_) {
      var rawName = arg.content;
      if (rawName.startsWith('vnode')) {
        context.onError(
            TmplCompileError(51, tmplErrorMessage(51), arg.loc));
      }
      if (rawName.startsWith('vue:')) {
        rawName = 'vnode-${rawName.substring(4)}';
      }
      final eventString =
          node.tagType != etElement || !RegExp(r'[A-Z]').hasMatch(rawName)
              ? toHandlerKey(camelize(rawName))
              : 'on:$rawName';
      return createSimpleExp(eventString, true, arg.loc);
    }
    return createCompoundExp(
        ['${context.helperString(hToHandlerKey)}(', arg, ')']);
  }
  final compound = arg as CompoundExpression;
  compound.children.insert(0, '${context.helperString(hToHandlerKey)}(');
  compound.children.add(')');
  return compound;
}

/// Returns (processed handler expression, shouldCache override or null).
(TmplNode?, bool?) _processHandlerExp(ElementNode node,
    TransformContext context, DirectiveNode dir, SimpleExpression? exp) {
  if (exp == null) return (null, null);
  var shouldCache = false;
  final isMemberExp = isMemberExpressionOf(exp, context);
  final isInlineStatement = !(isMemberExp || isFnExpression(exp, context));
  final hasMultipleStatements = exp.content.contains(';');
  TmplNode handled = exp;
  if (context.prefixIdentifiers) {
    if (isInlineStatement) context.addIdentifiers('\$event');
    handled = processExpression(exp, context,
        asRawStatements: hasMultipleStatements);
    dir.exp = handled;
    if (isInlineStatement) context.removeIdentifiers('\$event');
    shouldCache = context.cacheHandlers &&
        !context.inVOnce &&
        !(handled is SimpleExpression && handled.constType > 0) &&
        !(isMemberExp && node.tagType == etComponent) &&
        !hasScopeRef(handled, context.identifiers);
    if (shouldCache && isMemberExp) {
      handled = _extendMemberHandler(handled);
    }
  }
  if (isInlineStatement || (shouldCache && isMemberExp)) {
    final head = isInlineStatement
        ? (context.isTS ? '(\$event: any)' : '\$event')
        : '${context.isTS ? '\n//@ts-ignore\n' : ''}(...args)';
    handled = createCompoundExp([
      '$head => ${hasMultipleStatements ? '{' : '('}',
      handled,
      hasMultipleStatements ? '}' : ')'
    ]);
  }
  return (handled, shouldCache);
}

TmplNode _extendMemberHandler(TmplNode exp) {
  if (exp is SimpleExpression) {
    exp.content = '${exp.content} && ${exp.content}(...args)';
    return exp;
  }
  if (exp is CompoundExpression) {
    exp.children = [...exp.children, ' && ', ...exp.children, '(...args)'];
  }
  return exp;
}

DirTransformResult transformBindCore(
    DirectiveNode dir, ElementNode node, TransformContext context) {
  final modifiers = dir.modifiers;
  final loc = dir.loc;
  final arg = dir.arg;
  final exp = dir.exp;
  if (exp is SimpleExpression && exp.content.trim().isEmpty) {
    context.onError(
        TmplCompileError(34, 'v-bind is missing expression.', loc));
    return DirTransformResult(
        [createObjectProp(arg!, createSimpleExp('', true, loc))]);
  }
  _normalizeBindArg(arg);
  if (modifiers.any((m) => m.content == 'camel')) {
    _camelizeBindArg(arg, context);
  }
  if (!context.inSSR) {
    if (modifiers.any((m) => m.content == 'prop')) _injectPrefix(arg, '.');
    if (modifiers.any((m) => m.content == 'attr')) _injectPrefix(arg, '^');
  }
  return DirTransformResult([createObjectProp(arg!, exp)]);
}

void _normalizeBindArg(Object? arg) {
  if (arg is CompoundExpression) {
    arg.children.insert(0, '(');
    arg.children.add(') || ""');
  } else if (arg is SimpleExpression && !arg.static_) {
    arg.content = arg.content.isNotEmpty ? '${arg.content} || ""' : '""';
  }
}

void _camelizeBindArg(Object? arg, TransformContext context) {
  if (arg is SimpleExpression) {
    if (arg.static_) {
      arg.content = camelize(arg.content);
    } else {
      arg.content = '${context.helperString(hCamelize)}(${arg.content})';
    }
  } else if (arg is CompoundExpression) {
    arg.children.insert(0, '${context.helperString(hCamelize)}(');
    arg.children.add(')');
  }
}

void _injectPrefix(Object? arg, String prefix) {
  if (arg is SimpleExpression) {
    if (arg.static_) {
      arg.content = prefix + arg.content;
    } else {
      arg.content = '`$prefix\${${arg.content}}`';
    }
  } else if (arg is CompoundExpression) {
    arg.children.insert(0, "'$prefix' + (");
    arg.children.add(')');
  }
}
