// Port of compiler-dom stringifyStatic (the transformHoist hook) with
// analyzeNode / stringifyNode / stringifyElement / evaluateConstant.
import '../html_attrs.dart';
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../stringify_utils.dart';
import '../tmpl_ast.dart';
import '../transform_context.dart';
import 'const_eval.dart';

final _expReplaceRE = RegExp(r'__VUE_EXP_START__(.*?)__VUE_EXP_END__');
final _dataAriaRE = RegExp(r'^(?:data|aria)-');
final _nonStringifiable = makeMap(
  'caption,thead,tr,th,tbody,td,tfoot,colgroup,col',
);

/// Official stringifyStatic(children, context, parent).
void stringifyStatic(
  List<TmplNode> children,
  TransformContext context,
  TmplNode parent,
) {
  if (context.scopes.vSlot > 0) return;
  _Stringifier(children, context, parent).run();
}

final class _Stringifier {
  final List<TmplNode> children;
  final TransformContext context;
  final TmplNode parent;
  int nc = 0;
  int ec = 0;
  final chunk = <TmplNode>[];
  int _deletedSoFar = 0;

  _Stringifier(this.children, this.context, this.parent);

  bool get parentCached {
    final p = parent;
    if (p is! ElementNode) return false;
    final cn = p.codegenNode;
    return cn is VNodeCall && cn.children is JSCacheExpression;
  }

  void run() {
    var i = 0;
    for (; i < children.length; i++) {
      i -= _visitChild(i);
    }
    stringifyChunk(i);
  }

  /// Returns how far the loop index must move back after this child.
  int _visitChild(int i) {
    final child = children[i];
    final cached = parentCached || _cachedNodeOf(child) != null;
    if (cached) {
      final result = _analyzeNode(child);
      if (result != null) {
        nc += result.$1;
        ec += result.$2;
        chunk.add(child);
        return 0;
      }
    }
    final deleted = parentCached ? 0 : stringifyChunk(i);
    nc = 0;
    ec = 0;
    chunk.clear();
    return deleted;
  }

  /// Official stringifyCurrentChunk.
  int stringifyChunk(int currentIndex) {
    if (nc < 20 && ec < 5) return 0;
    final content = chunk.map((n) => _stringifyNode(n, context)).join();
    final json = jsJsonString(
      content,
    ).replaceAllMapped(_expReplaceRE, (m) => '" + ${m[1]} + "');
    context.helper(hCreateStatic);
    final call = createCallExp(hCreateStatic, [json, '${chunk.length}']);
    if (parentCached) {
      _spliceCachedArray(currentIndex, call);
    } else {
      _mergeIntoFirst(currentIndex, call);
    }
    return chunk.length - 1;
  }

  /// cached-as-array path: the printed elements live in the cache array.
  void _spliceCachedArray(int currentIndex, JSCallExpression call) {
    final vnode = (parent as ElementNode).codegenNode as VNodeCall;
    final cacheExp = vnode.children as JSCacheExpression;
    final elements = (cacheExp.value as JSArrayExpression).elements;
    final start = currentIndex - chunk.length - _deletedSoFar;
    elements.replaceRange(start, start + chunk.length, [call]);
    _deletedSoFar += chunk.length - 1;
  }

  /// Normal path: first cached node carries the static call, the rest of
  /// the chunk is removed and later cache indices shift down.
  void _mergeIntoFirst(int currentIndex, JSCallExpression call) {
    _cachedNodeOf(chunk[0])!.value = call;
    if (chunk.length == 1) return;
    final deleteCount = chunk.length - 1;
    children.removeRange(currentIndex - deleteCount, currentIndex);
    final cacheIndex = context.cached.indexOf(_cachedNodeOf(chunk.last));
    if (cacheIndex > -1) _fixCachedIndices(cacheIndex, deleteCount);
  }

  void _fixCachedIndices(int cacheIndex, int deleteCount) {
    for (var i = cacheIndex; i < context.cached.length; i++) {
      final c = context.cached[i];
      if (c != null) c.index -= deleteCount;
    }
    context.cached.removeRange(cacheIndex - deleteCount + 1, cacheIndex + 1);
  }
}

JSCacheExpression? _cachedNodeOf(TmplNode node) {
  final ok =
      node is TextCallNode ||
      (node is ElementNode && node.tagType == etElement);
  if (!ok) return null;
  final cn = node is ElementNode
      ? node.codegenNode
      : (node as TextCallNode).codegenNode;
  return cn is JSCacheExpression ? cn : null;
}

// --- analyzeNode -----------------------------------------------------------

(int, int)? _analyzeNode(TmplNode node) {
  if (node is! ElementNode) return node is TextCallNode ? (1, 0) : null;
  if (_nonStringifiable(node.tag)) return null;
  if (findDir(node, 'once', true) != null) return null;
  final st = _AnalyzeState(node.props.isNotEmpty ? 1 : 0);
  return _walkAnalyze(node, st) ? (st.nc, st.ec) : null;
}

final class _AnalyzeState {
  int nc = 1;
  int ec;
  _AnalyzeState(this.ec);
}

bool _walkAnalyze(ElementNode node, _AnalyzeState st) {
  final optionTag = node.tag == 'option' && node.ns == nsHtml;
  for (final p in node.props) {
    if (!_analyzeProp(p, node.ns, optionTag)) return false;
  }
  for (final child in node.children) {
    st.nc++;
    if (child is ElementNode) {
      if (child.props.isNotEmpty) st.ec++;
      if (!_walkAnalyze(child, st)) return false;
    }
  }
  return true;
}

bool _analyzeProp(TmplNode p, int ns, bool optionTag) {
  if (p is AttributeNode) return _isStringifiableAttr(p.name, ns);
  if (p is! DirectiveNode || p.name != 'bind') return true;
  final arg = p.arg;
  final exp = p.exp;
  if (arg is CompoundExpression) return false;
  if (arg is SimpleExpression &&
      arg.static_ &&
      !_isStringifiableAttr(arg.content, ns)) {
    return false;
  }
  if (exp is CompoundExpression) return false;
  if (exp is SimpleExpression && exp.constType < ctCanStringify) return false;
  if (optionTag &&
      isStaticArgOf(arg, 'value') &&
      exp is SimpleExpression &&
      !exp.static_) {
    return false;
  }
  return true;
}

bool _isStringifiableAttr(String name, int ns) {
  final known = switch (ns) {
    nsHtml => isKnownHtmlAttr(name),
    nsSvg => isKnownSvgAttr(name),
    nsMathMl => isKnownMathMlAttr(name),
    _ => false,
  };
  return known || _dataAriaRE.hasMatch(name);
}

// --- stringifyNode / stringifyElement --------------------------------------

String _stringifyNode(Object? node, TransformContext context) {
  if (node is String) return helperNames.contains(node) ? '' : node;
  return switch (node) {
    ElementNode n => _stringifyElement(n, context),
    TextNode n => escapeHtml(n.content),
    CommentNode n => '<!--${escapeHtml(n.content)}-->',
    InterpolationNode n => escapeHtml(
      toDisplayString(evaluateConstant(n.content)),
    ),
    CompoundExpression n => escapeHtml(jsStr(evaluateConstant(n))),
    TextCallNode n => _stringifyNode(n.content, context),
    _ => '',
  };
}

String _stringifyElement(ElementNode node, TransformContext context) {
  final buf = StringBuffer('<${node.tag}');
  Object? inner;
  for (final p in node.props) {
    final r = _stringifyProp(p);
    buf.write(r.$1);
    if (r.$2) inner = r.$3;
  }
  if (context.scopeId != null) buf.write(' ${context.scopeId}');
  buf.write('>');
  if (jsTruthy(inner)) {
    buf.write(jsStr(inner));
  } else {
    for (final c in node.children) {
      buf.write(_stringifyNode(c, context));
    }
  }
  if (!isVoidTag(node.tag)) buf.write('</${node.tag}>');
  return buf.toString();
}

/// Returns (attrText, setsInnerHTML, innerValue).
(String, bool, Object?) _stringifyProp(TmplNode p) {
  if (p is AttributeNode) {
    final v = p.value;
    final text = v == null ? '' : '="${escapeHtml(v.content)}"';
    return (' ${p.name}$text', false, null);
  }
  if (p is DirectiveNode && p.name == 'bind') return _stringifyBind(p);
  if (p is DirectiveNode && p.name == 'html') {
    return ('', true, evaluateConstant(p.exp!));
  }
  if (p is DirectiveNode && p.name == 'text') {
    return ('', true, escapeHtml(toDisplayString(evaluateConstant(p.exp!))));
  }
  return ('', false, null);
}

(String, bool, Object?) _stringifyBind(DirectiveNode p) {
  final arg = (p.arg as SimpleExpression).content;
  final exp = p.exp as SimpleExpression;
  if (exp.content.isNotEmpty && exp.content[0] == '_') {
    return (
      ' $arg="__VUE_EXP_START__${exp.content}__VUE_EXP_END__"',
      false,
      null,
    );
  }
  if (isBooleanAttr(arg) && exp.content == 'false') return ('', false, null);
  final evaluated = evaluateConstant(exp);
  if (evaluated == null || evaluated is JsUndefined) return ('', false, null);
  final value = arg == 'class'
      ? normalizeClass(evaluated)
      : arg == 'style'
      ? stringifyStyle(normalizeStyle(evaluated))
      : evaluated;
  return (' $arg="${escapeHtml(value)}"', false, null);
}

// --- evaluateConstant ------------------------------------------------------

/// Official evaluateConstant: SimpleExpression runs `new Function(...)` —
/// ported as a constant evaluator over the tree-sitter AST; compounds
/// concatenate per official rules.
Object? evaluateConstant(TmplNode exp) {
  if (exp is SimpleExpression) return evalConstantSource(exp.content);
  final buf = StringBuffer();
  for (final c in (exp as CompoundExpression).children) {
    if (c is String || c == null) continue; // strings & helper symbols skip
    if (c is TextNode) {
      buf.write(c.content);
    } else if (c is InterpolationNode) {
      buf.write(toDisplayString(evaluateConstant(c.content)));
    } else if (c is TmplNode) {
      buf.write(jsStr(evaluateConstant(c)));
    } else {
      throw StateError('evaluateConstant: unexpected child $c');
    }
  }
  return buf.toString();
}
