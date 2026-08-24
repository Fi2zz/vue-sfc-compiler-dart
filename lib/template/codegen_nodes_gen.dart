// genNode* family — port of compiler-core codegen node emission.
import 'dart:convert';

import 'codegen.dart';
import 'js_nodes.dart';
import 'shared_utils.dart';
import 'tmpl_ast.dart';

bool _isTextLike(Object? n) =>
    n is String ||
    (n is TmplNode &&
        (n.type == ntSimpleExpression ||
            n.type == ntText ||
            n.type == ntInterpolation ||
            n.type == ntCompoundExpression));

void genNode(Object? node, CodegenContext context) {
  if (node is String) {
    // Official prints Symbols via context.helper(); helper-name strings model
    // symbol identity, so they get the `_` prefix here.
    context.push(helperNames.contains(node) ? context.helper(node) : node);
    return;
  }
  switch (node) {
    case ElementNode n:
      _genCodegenOf(n.codegenNode, context, node);
    case IfNode n:
      _genCodegenOf(n.codegenNode, context, node);
    case ForNode n:
      _genCodegenOf(n.codegenNode, context, node);
    case TextNode n:
      context.push(jsonEncode(n.content));
    case SimpleExpression n:
      context.push(n.static_ ? jsonEncode(n.content) : n.content);
    case InterpolationNode n:
      _genInterpolation(n, context);
    case TextCallNode n:
      _genCodegenOf(n.codegenNode, context, node);
    case CompoundExpression n:
      _genCompoundExpression(n, context);
    case CommentNode n:
      _genComment(n, context);
    case VNodeCall n:
      _genVNodeCall(n, context);
    case JSCallExpression n:
      _genCallExpression(n, context);
    case JSObjectExpression n:
      _genObjectExpression(n, context);
    case JSArrayExpression n:
      genNodeListAsArray(n.elements, context);
    case JSFunctionExpression n:
      _genFunctionExpression(n, context);
    case JSConditionalExpression n:
      _genConditionalExpression(n, context);
    case JSCacheExpression n:
      _genCacheExpression(n, context);
    case JSBlockStatement n:
      genNodeList(n.body, context, multilines: true, comma: false);
    case JSTemplateLiteral n:
      _genTemplateLiteral(n, context);
    case JSIfStatement n:
      _genIfStatement(n, context);
    case JSAssignmentExpression n:
      genNode(n.left, context);
      context.push(' = ');
      genNode(n.right, context);
    case JSSequenceExpression n:
      context.push('(');
      genNodeList(n.expressions, context);
      context.push(')');
    case JSReturnStatement n:
      context.push('return ');
      final r = n.returns;
      if (r is List) {
        genNodeListAsArray(r, context);
      } else {
        genNode(r, context);
      }
    default:
      throw StateError('unhandled codegen node: $node');
  }
}

void _genCodegenOf(Object? codegenNode, CodegenContext context, Object node) {
  if (codegenNode == null) {
    // 与官方 assert 文案逐字对齐（错误文本会进样例 ground truth）。
    throw StateError('Codegen node is missing for element/if/for node. '
        'Apply appropriate transforms first.');
  }
  genNode(codegenNode, context);
}

void _genInterpolation(InterpolationNode node, CodegenContext context) {
  if (context.pure) context.push(pureAnnotation);
  context.push('${context.helper(hToDisplayString)}(');
  genNode(node.content, context);
  context.push(')');
}

void _genComment(CommentNode node, CodegenContext context) {
  if (context.pure) context.push(pureAnnotation);
  context.push(
      '${context.helper(hCreateComment)}(${jsonEncode(node.content)})');
}

void _genCompoundExpression(CompoundExpression node, CodegenContext context) {
  for (final child in node.children) {
    genNode(child, context);
  }
}

void genNodeListAsArray(List<Object?> nodes, CodegenContext context) {
  final multilines =
      nodes.length > 3 || nodes.any((n) => n is List || !_isTextLike(n));
  context.push('[');
  if (multilines) context.indent();
  genNodeList(nodes, context, multilines: multilines);
  if (multilines) context.deindent();
  context.push(']');
}

void genNodeList(List<Object?> nodes, CodegenContext context,
    {bool multilines = false, bool comma = true}) {
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    if (node is List) {
      genNodeListAsArray(node, context);
    } else {
      genNode(node, context);
    }
    if (i < nodes.length - 1) {
      if (multilines) {
        if (comma) context.push(',');
        context.newline();
      } else {
        if (comma) context.push(', ');
      }
    }
  }
}

void _genExpressionAsPropertyKey(Object node, CodegenContext context) {
  if (node is CompoundExpression) {
    context.push('[');
    _genCompoundExpression(node, context);
    context.push(']');
  } else if (node is SimpleExpression && node.static_) {
    final text = isSimpleIdentifier(node.content)
        ? node.content
        : jsonEncode(node.content);
    context.push(text);
  } else if (node is SimpleExpression) {
    context.push('[${node.content}]');
  }
}

void _genObjectExpression(JSObjectExpression node, CodegenContext context) {
  final properties = node.properties;
  if (properties.isEmpty) {
    context.push('{}');
    return;
  }
  final multilines = properties.length > 1 ||
      properties.any((p) => p.value is! SimpleExpression);
  context.push(multilines ? '{' : '{ ');
  if (multilines) context.indent();
  for (var i = 0; i < properties.length; i++) {
    final p = properties[i];
    _genExpressionAsPropertyKey(p.key, context);
    context.push(': ');
    genNode(p.value, context);
    if (i < properties.length - 1) {
      context.push(',');
      context.newline();
    }
  }
  if (multilines) context.deindent();
  context.push(multilines ? '}' : ' }');
}

void _genCallExpression(JSCallExpression node, CodegenContext context) {
  final calleeRaw = node.callee;
  final callee = calleeRaw is String && calleeRaw.startsWith('_')
      ? calleeRaw
      : context.helper(calleeRaw as String);
  if (context.pure) context.push(pureAnnotation);
  context.push('$callee(');
  genNodeList(node.arguments, context);
  context.push(')');
}

void _genFunctionExpression(JSFunctionExpression node, CodegenContext context) {
  final params = node.params;
  final returns = node.returns;
  final body = node.body;
  if (node.isSlot) {
    context.push('_$hWithCtx(');
  }
  context.push('(');
  if (params is List) {
    genNodeList(params.cast<Object?>(), context);
  } else if (params != null) {
    genNode(params, context);
  }
  context.push(') => ');
  if (node.newline || body != null) {
    context.push('{');
    context.indent();
  }
  if (returns != null) {
    if (node.newline) context.push('return ');
    if (returns is List) {
      genNodeListAsArray(returns.cast<Object?>(), context);
    } else {
      genNode(returns, context);
    }
  } else if (body != null) {
    genNode(body, context);
  }
  if (node.newline || body != null) {
    context.deindent();
    context.push('}');
  }
  if (node.isSlot) {
    if (node.isNonScopedSlot) context.push(', undefined, true');
    context.push(')');
  }
}

void _genConditionalExpression(
    JSConditionalExpression node, CodegenContext context) {
  final test = node.test;
  final needNewline = node.newline;
  if (test is SimpleExpression) {
    final needsParens = !isSimpleIdentifier(test.content);
    if (needsParens) context.push('(');
    genNode(test, context);
    if (needsParens) context.push(')');
  } else {
    context.push('(');
    genNode(test, context);
    context.push(')');
  }
  if (needNewline) context.indent();
  context.indentLevel++;
  if (!needNewline) context.push(' ');
  context.push('? ');
  genNode(node.consequent, context);
  context.indentLevel--;
  if (needNewline) context.newline();
  if (!needNewline) context.push(' ');
  context.push(': ');
  final isNested = node.alternate is JSConditionalExpression;
  if (!isNested) context.indentLevel++;
  genNode(node.alternate, context);
  if (!isNested) context.indentLevel--;
  if (needNewline) context.deindent(true);
}

void _genCacheExpression(JSCacheExpression node, CodegenContext context) {
  if (node.needArraySpread) context.push('[...(');
  context.push('_cache[${node.index}] || (');
  if (node.needPauseTracking) {
    context.indent();
    context.push('${context.helper(hSetBlockTracking)}(-1');
    if (node.inVOnce) context.push(', true');
    context.push('),');
    context.newline();
    context.push('(');
  }
  context.push('_cache[${node.index}] = ');
  genNode(node.value, context);
  if (node.needPauseTracking) {
    context.push(').cacheIndex = ${node.index},');
    context.newline();
    context.push('${context.helper(hSetBlockTracking)}(1),');
    context.newline();
    context.push('_cache[${node.index}]');
    context.deindent();
  }
  context.push(')');
  if (node.needArraySpread) context.push(')]');
}

void _genTemplateLiteral(JSTemplateLiteral node, CodegenContext context) {
  context.push('`');
  final l = node.elements.length;
  final multilines = l > 3;
  for (var i = 0; i < l; i++) {
    final e = node.elements[i];
    if (e is String) {
      context.push(e.replaceAllMapped(
          RegExp(r'(`|\$|\\)'), (m) => '\\${m[0]}'));
    } else {
      context.push('\${');
      if (multilines) context.indent();
      genNode(e, context);
      if (multilines) context.deindent();
      context.push('}');
    }
  }
  context.push('`');
}

void _genIfStatement(JSIfStatement node, CodegenContext context) {
  context.push('if (');
  genNode(node.test, context);
  context.push(') {');
  context.indent();
  genNode(node.consequent, context);
  context.deindent();
  context.push('}');
  final alternate = node.alternate;
  if (alternate != null) {
    context.push(' else ');
    if (alternate is JSIfStatement) {
      _genIfStatement(alternate, context);
    } else {
      context.push('{');
      context.indent();
      genNode(alternate, context);
      context.deindent();
      context.push('}');
    }
  }
}

void _genVNodeCall(VNodeCall node, CodegenContext context) {
  String? patchFlagString;
  final patchFlag = node.patchFlag;
  if (patchFlag != null && patchFlag != 0) {
    patchFlagString = _formatPatchFlag(patchFlag);
  }
  if (node.directives != null) {
    context.push('${context.helper(hWithDirectives)}(');
  }
  if (node.isBlock) {
    context.push(
        '(${context.helper(hOpenBlock)}(${node.disableTracking ? 'true' : ''}), ');
  }
  if (context.pure) context.push(pureAnnotation);
  final callHelper = node.isBlock
      ? getVNodeBlockHelper(context.options.inSSR, node.isComponent)
      : getVNodeHelper(context.options.inSSR, node.isComponent);
  context.push('${context.helper(callHelper)}(');
  genNodeList(
      _genNullableArgs([
        node.tag,
        node.props,
        node.children,
        patchFlagString,
        node.dynamicProps
      ]),
      context);
  context.push(')');
  if (node.isBlock) context.push(')');
  if (node.directives != null) {
    context.push(', ');
    genNode(node.directives, context);
    context.push(')');
  }
}

String _formatPatchFlag(int patchFlag) {
  if (patchFlag < 0) {
    return '$patchFlag /* ${patchFlagNames[patchFlag]} */';
  }
  final names = patchFlagNames.keys
      .where((n) => n > 0 && (patchFlag & n) != 0)
      .map((n) => patchFlagNames[n])
      .join(', ');
  return '$patchFlag /* $names */';
}

List<Object?> _genNullableArgs(List<Object?> args) {
  var i = args.length;
  while (i-- > 0) {
    if (args[i] != null) break;
  }
  return args
      .sublist(0, i + 1)
      .map((arg) => arg ?? 'null')
      .toList();
}
