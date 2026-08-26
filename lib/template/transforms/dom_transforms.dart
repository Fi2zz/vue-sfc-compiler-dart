// Ports of compiler-dom transforms: style/html/text/model(DOM)/on(DOM)/show/
// transition/ignoreSideEffectTags/validateHtmlNesting + noop cloak.
import 'dart:convert';

import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import '../tmpl_error_messages.dart';
import 'hoist_static.dart';
import 'v_model_core.dart';
import 'v_on_bind.dart';

// --- transformStyle + parseInlineCSS ---

final _styleCommentRE = RegExp(r'/\*[^]*?\*/');
final _listDelimiterRE = RegExp(r';(?![^(]*\))');

Map<String, String> parseStringStyle(String cssText) {
  final ret = <String, String>{};
  final cleaned = cssText.replaceAll(_styleCommentRE, '');
  for (final item in cleaned.split(_listDelimiterRE)) {
    if (item.isEmpty) continue;
    // 官方 JS /:(.+)/ split 捕获；Dart split 会插入捕获组且 [^] 语义不同，
    // 手动首个冒号切分与之等价。
    final colon = item.indexOf(':');
    if (colon <= 0) continue;
    ret[item.substring(0, colon).trim()] = item.substring(colon + 1).trim();
  }
  return ret;
}

Object? transformStyle(TmplNode node, TransformContext context) {
  if (node is! ElementNode) return null;
  for (var i = 0; i < node.props.length; i++) {
    final p = node.props[i];
    if (p is AttributeNode && p.name == 'style' && p.value != null) {
      node.props[i] = DirectiveNode(
        'bind',
        ':style',
        p.loc,
        arg: createSimpleExp('style', true, p.loc),
        exp: _parseInlineCss(p.value!.content, p.loc),
      );
    }
  }
  return null;
}

SimpleExpression _parseInlineCss(String cssText, TmplLoc loc) {
  final normalized = parseStringStyle(cssText);
  return createSimpleExp(jsonEncode(normalized), false, loc, ctCanStringify);
}

// --- v-html / v-text ---

DirTransformResult transformVHtml(
  DirectiveNode dir,
  ElementNode node,
  TransformContext context,
) {
  final exp = dir.exp;
  final loc = dir.loc;
  if (exp == null) {
    context.onError(TmplCompileError(53, 'v-html is missing expression.', loc));
  }
  if (node.children.isNotEmpty) {
    context.onError(
      TmplCompileError(54, 'v-html will override element children.', loc),
    );
    node.children = [];
  }
  return DirTransformResult([
    createObjectProp(
      createSimpleExp('innerHTML', true, loc),
      exp ?? createSimpleExp('', true),
    ),
  ]);
}

DirTransformResult transformVText(
  DirectiveNode dir,
  ElementNode node,
  TransformContext context,
) {
  final exp = dir.exp;
  final loc = dir.loc;
  if (exp == null) {
    context.onError(TmplCompileError(55, 'v-text is missing expression.', loc));
  }
  if (node.children.isNotEmpty) {
    context.onError(
      TmplCompileError(56, 'v-text will override element children.', loc),
    );
    node.children = [];
  }
  Object? value;
  if (exp != null) {
    value = getConstantType(exp, context) > 0
        ? exp
        : createCallExp(context.helperString(hToDisplayString), [exp], loc);
  } else {
    value = createSimpleExp('', true);
  }
  return DirTransformResult([
    createObjectProp(createSimpleExp('textContent', true), value),
  ]);
}

// --- DOM v-model ---

DirTransformResult transformModelDom(
  DirectiveNode dir,
  ElementNode node,
  TransformContext context,
) {
  final baseResult = transformModelCore(dir, node, context);
  if (baseResult.props.isEmpty || node.tagType == etComponent) {
    return baseResult;
  }
  if (dir.arg != null) {
    context.onError(
      TmplCompileError(
        58,
        'v-model argument is not supported on plain elements.',
        dir.arg!.loc,
      ),
    );
  }
  _applyDomModelDirective(dir, node, context, baseResult);
  baseResult.props = baseResult.props
      .where(
        (p) =>
            !(p.key is SimpleExpression &&
                (p.key as SimpleExpression).content == 'modelValue'),
      )
      .toList();
  return baseResult;
}

void _applyDomModelDirective(
  DirectiveNode dir,
  ElementNode node,
  TransformContext context,
  DirTransformResult baseResult,
) {
  final tag = node.tag;
  final isCustomElement = customElementOf(context, tag);
  if (tag != 'input' &&
      tag != 'textarea' &&
      tag != 'select' &&
      !isCustomElement) {
    context.onError(TmplCompileError(57, tmplErrorMessage(57), dir.loc));
    return;
  }
  var directiveToUse = hVModelText;
  var isInvalidType = false;
  if (tag == 'input' || isCustomElement) {
    final type = findProp(node, 'type');
    final resolved = _resolveInputModelType(type, node, context, dir);
    directiveToUse = resolved.$1;
    isInvalidType = resolved.$2;
  } else if (tag == 'select') {
    directiveToUse = hVModelSelect;
  } else {
    _checkDuplicatedValue(node, context);
  }
  if (!isInvalidType) {
    context.helper(directiveToUse);
    baseResult.needRuntime = directiveToUse;
  }
}

(String, bool) _resolveInputModelType(
  Object? type,
  ElementNode node,
  TransformContext context,
  DirectiveNode dir,
) {
  if (type == null) {
    if (hasDynamicKeyVBind(node)) return (hVModelDynamic, false);
    _checkDuplicatedValue(node, context);
    return (hVModelText, false);
  }
  if (type is DirectiveNode) return (hVModelDynamic, false);
  final attr = type as AttributeNode;
  if (attr.value == null) {
    _checkDuplicatedValue(node, context);
    return (hVModelText, false);
  }
  switch (attr.value!.content) {
    case 'radio':
      return (hVModelRadio, false);
    case 'checkbox':
      return (hVModelCheckbox, false);
    case 'file':
      context.onError(TmplCompileError(59, tmplErrorMessage(59), dir.loc));
      return (hVModelText, true);
    default:
      _checkDuplicatedValue(node, context);
      return (hVModelText, false);
  }
}

void _checkDuplicatedValue(ElementNode node, TransformContext context) {
  final value = findDir(node, 'bind');
  if (value != null && isStaticArgOf(value.arg, 'value')) {
    context.onError(TmplCompileError(60, tmplErrorMessage(60), value.loc));
  }
}

// --- DOM v-on (modifiers) ---

final _isEventOptionModifier = makeMap('passive,once,capture');
final _isNonKeyModifier = makeMap(
  'stop,prevent,self,ctrl,shift,alt,meta,exact,middle',
);
final _maybeKeyModifier = makeMap('left,right');
final _isKeyboardEvent = makeMap('onkeyup,onkeydown,onkeypress');

DirTransformResult transformOnDom(
  DirectiveNode dir,
  ElementNode node,
  TransformContext context,
) {
  return transformOnCore(dir, node, context, (baseResult) {
    final modifiers = dir.modifiers;
    if (modifiers.isEmpty) return baseResult;
    var key = baseResult.props[0].key;
    var handlerExp = baseResult.props[0].value;
    final resolved = _resolveModifiers(key, modifiers);
    key = _applyClickTransforms(key, resolved.$2);
    if (resolved.$2.isNotEmpty) {
      context.helper(hVOnWithModifiers);
      handlerExp = createCallExp(hVOnWithModifiers, [
        handlerExp,
        jsonEncode(resolved.$2),
      ]);
    }
    if (resolved.$1.isNotEmpty &&
        (!isStaticExp(key) ||
            _isKeyboardEvent(
              (key as SimpleExpression).content.toLowerCase(),
            ))) {
      context.helper(hVOnWithKeys);
      handlerExp = createCallExp(hVOnWithKeys, [
        handlerExp,
        jsonEncode(resolved.$1),
      ]);
    }
    if (resolved.$3.isNotEmpty) {
      key = _applyOptionPostfix(key, resolved.$3);
    }
    return DirTransformResult([createObjectProp(key, handlerExp)]);
  });
}

(List<String>, List<String>, List<String>) _resolveModifiers(
  Object key,
  List<SimpleExpression> modifiers,
) {
  final keyModifiers = <String>[];
  final nonKeyModifiers = <String>[];
  final eventOptionModifiers = <String>[];
  for (final m in modifiers) {
    final modifier = m.content;
    if (_isEventOptionModifier(modifier)) {
      eventOptionModifiers.add(modifier);
    } else if (_maybeKeyModifier(modifier)) {
      if (isStaticExp(key)) {
        if (_isKeyboardEvent((key as SimpleExpression).content.toLowerCase())) {
          keyModifiers.add(modifier);
        } else {
          nonKeyModifiers.add(modifier);
        }
      } else {
        keyModifiers.add(modifier);
        nonKeyModifiers.add(modifier);
      }
    } else if (_isNonKeyModifier(modifier)) {
      nonKeyModifiers.add(modifier);
    } else {
      keyModifiers.add(modifier);
    }
  }
  return (keyModifiers, nonKeyModifiers, eventOptionModifiers);
}

Object _applyClickTransforms(Object key, List<String> nonKeyModifiers) {
  var result = key;
  if (nonKeyModifiers.contains('right')) {
    result = _transformClick(result, 'onContextmenu');
  }
  if (nonKeyModifiers.contains('middle')) {
    result = _transformClick(result, 'onMouseup');
  }
  return result;
}

Object _transformClick(Object key, String event) {
  final isStaticClick =
      isStaticExp(key) &&
      (key as SimpleExpression).content.toLowerCase() == 'onclick';
  if (isStaticClick) return createSimpleExp(event, true);
  if (key is! SimpleExpression) {
    return createCompoundExp([
      '(',
      key,
      ') === "onClick" ? "$event" : (',
      key,
      ')',
    ]);
  }
  return key;
}

Object _applyOptionPostfix(Object key, List<String> eventOptionModifiers) {
  final modifierPostfix = eventOptionModifiers.map(capitalize).join('');
  return isStaticExp(key)
      ? createSimpleExp(
          '${(key as SimpleExpression).content}$modifierPostfix',
          true,
        )
      : createCompoundExp(['(', key, ') + "$modifierPostfix"']);
}

// --- v-show / cloak ---

DirTransformResult transformShow(
  DirectiveNode dir,
  ElementNode node,
  TransformContext context,
) {
  if (dir.exp == null) {
    context.onError(
      TmplCompileError(61, 'v-show is missing expression.', dir.loc),
    );
  }
  context.helper(hVShow);
  return DirTransformResult([], hVShow);
}

DirTransformResult noopDirectiveTransform(
  DirectiveNode dir,
  ElementNode node,
  TransformContext context,
) {
  return DirTransformResult([]);
}

// --- transformTransition ---

Object? transformTransition(TmplNode node, TransformContext context) {
  if (node is ElementNode && node.tagType == etComponent) {
    final component = builtInComponentOf(context, node.tag);
    if (component == hTransition) {
      return () => _applyTransitionPersist(node, context);
    }
  }
  return null;
}

void _applyTransitionPersist(ElementNode node, TransformContext context) {
  if (node.children.isEmpty) return;
  if (_hasMultipleChildren(node)) {
    context.onError(
      TmplCompileError(
        62,
        '<Transition> expects exactly one child element or component.',
        node.loc,
      ),
    );
  }
  final child = node.children[0];
  if (child is ElementNode) {
    for (final p in child.props) {
      if (p is DirectiveNode && p.name == 'show') {
        node.props.add(AttributeNode('persisted', node.loc, null, node.loc));
      }
    }
  }
}

bool _hasMultipleChildren(ElementNode node) {
  final children = node.children = node.children
      .where(
        (c) =>
            c.type != ntComment &&
            !(c.type == ntText && (c as TextNode).content.trim().isEmpty),
      )
      .toList();
  final child = children.isNotEmpty ? children[0] : null;
  return children.length != 1 ||
      child is ForNode ||
      (child is IfNode && child.branches.any((b) => _branchMultiple(b)));
}

bool _branchMultiple(IfBranchNode branch) {
  // 官方 hasMultipleChildren 对 branch 递归：过滤注释/空白后检查长度。
  final children = branch.children
      .where(
        (c) =>
            c.type != ntComment &&
            !(c.type == ntText && (c as TextNode).content.trim().isEmpty),
      )
      .toList();
  final first = children.isNotEmpty ? children[0] : null;
  return children.length != 1 ||
      first is ForNode ||
      (first is IfNode && first.branches.any(_branchMultiple));
}

// --- ignoreSideEffectTags / validateHtmlNesting ---

Object? ignoreSideEffectTags(TmplNode node, TransformContext context) {
  if (node is ElementNode &&
      node.tagType == etElement &&
      (node.tag == 'script' || node.tag == 'style')) {
    context.onError(TmplCompileError(63, tmplErrorMessage(63), node.loc));
    context.removeNode();
  }
  return null;
}

Object? validateHtmlNesting(TmplNode node, TransformContext context) {
  if (node is ElementNode &&
      node.tagType == etElement &&
      context.parent is ElementNode &&
      (context.parent as ElementNode).tagType == etElement &&
      !_isValidHtmlNesting((context.parent as ElementNode).tag, node.tag)) {
    context.onWarn(
      TmplCompileError(
        0,
        '<${node.tag}> cannot be child of <${(context.parent as ElementNode).tag}>.',
        node.loc,
      ),
    );
  }
  return null;
}

bool _isValidHtmlNesting(String parent, String child) {
  // Simplified port of compiler-dom isValidHTMLNesting tables.
  const headOnly = {'base', 'meta', 'link', 'title', 'style', 'script'};
  if (parent == 'template') return true;
  switch (parent) {
    case 'p':
      return !_phrasingBreakers.contains(child);
    case 'button':
      return child != 'button';
    case 'a':
      return child != 'a';
    case 'form':
      return child != 'form';
    case 'table':
      return {
        'caption',
        'colgroup',
        'thead',
        'tbody',
        'tfoot',
        'tr',
        'script',
      }.contains(child);
    case 'tr':
      return {'td', 'th', 'script'}.contains(child);
  }
  if (headOnly.contains(parent)) return false;
  return true;
}

const _phrasingBreakers = {
  'address',
  'article',
  'aside',
  'blockquote',
  'details',
  'div',
  'dl',
  'fieldset',
  'figcaption',
  'figure',
  'footer',
  'form',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'hr',
  'main',
  'menu',
  'nav',
  'ol',
  'p',
  'pre',
  'section',
  'table',
  'ul',
};
