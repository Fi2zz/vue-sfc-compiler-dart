// Port of compiler-sfc scopedPlugin: data-attribute injection, selector
// rewriting (:deep / :slotted / :global / >>> / /deep/), keyframes scoping
// and animation decl rewriting.
import 'css_ast.dart';
import 'selector_ast.dart';
import 'selector_parser.dart';

final _animationNameRE = RegExp(r'^(?:-\w+-)?animation-name$');
final _animationRE = RegExp(r'^(?:-\w+-)?animation$');
final _keyframesRE = RegExp(r'^(?:-\w+-)?keyframes$');

/// Mirrors scopedPlugin(id): Rule + AtRule visitors in document order, then
/// the OnceExit keyframes pass. Warnings (deprecated >>> etc.) are dropped —
/// they go to console.warn, not the compile result.
void applyScopedPlugin(CssRoot root, String id) {
  final shortId = id.replaceFirst(RegExp('^data-v-'), '');
  final keyframes = <String, String>{};
  final processed = <CssRule>{};
  _walkDocument(root, (node) {
    if (node is CssRule) _processRule(id, node, processed);
    if (node is CssAtRule) _collectKeyframes(node, shortId, keyframes);
  });
  if (keyframes.isNotEmpty) _rewriteAnimationDecls(root, keyframes);
}

void _walkDocument(CssContainer container, void Function(CssNode) visitor) {
  final nodes = container.nodes;
  if (nodes == null) return;
  var i = 0;
  while (i < nodes.length) {
    final node = nodes[i];
    visitor(node);
    if (node is CssContainer && node.nodes != null) {
      _walkDocument(node, visitor);
    }
    i++;
  }
}

void _collectKeyframes(
  CssAtRule node,
  String shortId,
  Map<String, String> keyframes,
) {
  if (_keyframesRE.hasMatch(node.name) && !node.params.endsWith('-$shortId')) {
    keyframes[node.params] = node.params = '${node.params}-$shortId';
  }
}

void _rewriteAnimationDecls(CssRoot root, Map<String, String> keyframes) {
  root.walkDecls((decl) {
    if (_animationNameRE.hasMatch(decl.prop)) {
      decl.value = decl.value
          .split(',')
          .map((v) => keyframes[v.trim()] ?? v.trim())
          .join(',');
    }
    if (_animationRE.hasMatch(decl.prop)) {
      decl.value = decl.value
          .split(',')
          .map((v) {
            final vals = v.trim().split(RegExp(r'\s+'));
            final i = vals.indexWhere(keyframes.containsKey);
            if (i == -1) return v;
            vals[i] = keyframes[vals[i]]!;
            return vals.join(' ');
          })
          .join(',');
    }
  });
}

void _processRule(String id, CssRule rule, Set<CssRule> processed) {
  final parent = rule.parent;
  final insideKeyframes =
      parent is CssAtRule && _keyframesRE.hasMatch(parent.name);
  if (processed.contains(rule) || insideKeyframes) return;
  processed.add(rule);
  rule.selector = transformSelector(rule.selector, (selectorRoot) {
    selectorRoot.each((selector) {
      _rewriteSelector(id, rule, selector as SelSelector, _isDeep(rule));
      return null;
    });
  });
}

bool _isDeep(CssRule rule) {
  var parent = rule.parent;
  while (parent != null && parent is! CssRoot) {
    if (parent is CssRule && parent.deep) return true;
    parent = parent.parent;
  }
  return false;
}

void _rewriteSelector(
  String id,
  CssRule rule,
  SelSelector selector,
  bool deep, [
  bool slotted = false,
]) {
  SelNode? node;
  var shouldInject = !deep;
  selector.each((n) {
    if (n.type == 'combinator' && (n.value == '>>>' || n.value == '/deep/')) {
      n.value = ' ';
      n.spaces.before = n.spaces.after = '';
      return false;
    }
    if (n.type == 'pseudo') {
      final res = _pseudoBranch(id, rule, selector, n as SelPseudo, deep);
      if (res.handled) {
        if (res.shouldInject != null) shouldInject = res.shouldInject!;
        return false;
      }
    }
    if (n.type == 'universal') {
      final res = _universalBranch(selector, n, node != null);
      if (res.stop) {
        node = res.node;
        return false;
      }
      if (res.skip) return null;
    }
    final plain = n.type != 'pseudo' && n.type != 'combinator';
    final isWhere =
        n.type == 'pseudo' &&
        (n.value == ':is' || n.value == ':where') &&
        node == null;
    if (plain || isWhere) node = n;
    return null;
  });
  shouldInject = _wrapNestedRules(rule, shouldInject);
  if (node != null && _isIsOrWhere(node!)) {
    for (final inner in (node as SelPseudo).nodes) {
      _rewriteSelector(id, rule, inner as SelSelector, deep, slotted);
    }
    shouldInject = false;
  }
  _injectAttribute(id, selector, node, shouldInject, slotted);
}

/// Returns (handled, shouldInject override). :deep/:global leave shouldInject
/// unchanged; :slotted forces it to false.
({bool handled, bool? shouldInject}) _pseudoBranch(
  String id,
  CssRule rule,
  SelSelector selector,
  SelPseudo pseudo,
  bool deep,
) {
  final value = pseudo.value;
  if (value == ':deep' || value == '::v-deep') {
    rule.deep = true;
    if (pseudo.nodes.isNotEmpty) {
      _unwrapDeep(selector, pseudo);
    } else {
      _dropDeepCombinator(selector, pseudo);
    }
    return (handled: true, shouldInject: null);
  }
  if (value == ':slotted' || value == '::v-slotted') {
    _rewriteSlotted(id, rule, selector, pseudo, deep);
    return (handled: true, shouldInject: false);
  }
  if (value == ':global' || value == '::v-global') {
    selector.replaceWith(pseudo.nodes[0]);
    return (handled: true, shouldInject: null);
  }
  return (handled: false, shouldInject: null);
}

void _unwrapDeep(SelSelector selector, SelPseudo pseudo) {
  SelNode last = pseudo;
  (pseudo.nodes[0] as SelContainer).each((ss) {
    selector.insertAfter(last, ss);
    last = ss;
    return null;
  });
  final prev = selector.at(selector.index(pseudo) - 1);
  if (prev == null || !_isSpaceCombinator(prev)) {
    selector.insertAfter(pseudo, SelCombinator(value: ' '));
  }
  selector.removeChild(pseudo);
}

void _dropDeepCombinator(SelSelector selector, SelPseudo pseudo) {
  final prev = selector.at(selector.index(pseudo) - 1);
  if (prev != null && _isSpaceCombinator(prev)) {
    selector.removeChild(prev);
  }
  selector.removeChild(pseudo);
}

void _rewriteSlotted(
  String id,
  CssRule rule,
  SelSelector selector,
  SelPseudo pseudo,
  bool deep,
) {
  _rewriteSelector(id, rule, pseudo.nodes[0] as SelSelector, deep, true);
  SelNode last = pseudo;
  (pseudo.nodes[0] as SelContainer).each((ss) {
    selector.insertAfter(last, ss);
    last = ss;
    return null;
  });
  selector.removeChild(pseudo);
}

/// Mirrors the JS universal branch: prev present -> skip only when node was
/// already assigned; no prev -> drop the star, or replace a lone star with an
/// empty combinator that becomes the injection point.
({bool stop, bool skip, SelNode? node}) _universalBranch(
  SelSelector selector,
  SelNode n,
  bool nodeSet,
) {
  final prev = selector.at(selector.index(n) - 1);
  final next = selector.at(selector.index(n) + 1);
  if (prev == null) {
    if (next != null) {
      if (next.type == 'combinator' && next.value == ' ') {
        selector.removeChild(next);
      }
      selector.removeChild(n);
      return (stop: false, skip: true, node: null);
    }
    final empty = SelCombinator(value: '');
    selector.insertBefore(n, empty);
    selector.removeChild(n);
    return (stop: true, skip: false, node: empty);
  }
  if (nodeSet) return (stop: false, skip: true, node: null);
  return (stop: false, skip: false, node: null);
}

bool _isSpaceCombinator(SelNode node) =>
    node.type == 'combinator' && RegExp(r'^\s+$').hasMatch(node.value);

bool _isIsOrWhere(SelNode node) =>
    node.type == 'pseudo' && (node.value == ':is' || node.value == ':where');

bool _wrapNestedRules(CssRule rule, bool shouldInject) {
  final nodes = rule.nodes;
  if (nodes == null || !nodes.any((n) => n is CssRule)) {
    return shouldInject;
  }
  final deep = rule.deep;
  if (!deep) {
    _extractAndWrapNodes(rule);
    final atrules = nodes.whereType<CssAtRule>().toList();
    for (final atnode in atrules) {
      _extractAndWrapNodes(atnode);
    }
  }
  return deep;
}

void _extractAndWrapNodes(CssContainer parentNode) {
  final nodes = parentNode.nodes;
  if (nodes == null) return;
  final decls = nodes.where((n) => n is CssDecl || n is CssComment).toList();
  if (decls.isEmpty) return;
  for (final n in decls) {
    parentNode.removeChild(n);
  }
  final wrapped = CssRule(selector: '&');
  wrapped.nodes = decls;
  for (final d in decls) {
    d.parent = wrapped;
  }
  parentNode.prepend(wrapped);
}

void _injectAttribute(
  String id,
  SelSelector selector,
  SelNode? node,
  bool shouldInject,
  bool slotted,
) {
  if (node != null) {
    node.spaces.after = '';
  } else {
    selector.first!.spaces.before = '';
  }
  if (!shouldInject) return;
  final idToAdd = slotted ? '$id-s' : id;
  final attr = SelAttribute()
    ..attribute = idToAdd
    ..attrValue = idToAdd
    ..quoteMark = '"';
  selector.insertAfter(node, attr);
}
