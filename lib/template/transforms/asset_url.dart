// Port of compiler-sfc transformAssetUrl / transformSrcset (default options).

import '../js_nodes.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';

final _defaultAssetUrlTags = {
  'video': ['src', 'poster'],
  'source': ['src'],
  'img': ['src'],
  'image': ['xlink:href', 'href'],
  'use': ['xlink:href', 'href'],
};

const _srcsetTags = ['img', 'source'];

final _externalRE = RegExp(r'^(?:https?:)?\/\/');
final _dataUrlRE = RegExp(r'^\s*data:', caseSensitive: false);
final _escapedSpaceRE = RegExp(r'[\t\n\f\r ]+');

bool _isRelativeUrl(String url) {
  if (url.isEmpty) return false;
  final first = url[0];
  return first == '.' || first == '~' || first == '@';
}

(String, String?) _parseUrl(String url) {
  var u = url;
  if (u.startsWith('~')) {
    u = u.substring(u.length > 1 && u[1] == '/' ? 2 : 1);
  }
  final hashIndex = u.indexOf('#');
  if (hashIndex < 0) return (u, null);
  return (u.substring(0, hashIndex), u.substring(hashIndex));
}

Object? transformAssetUrl(TmplNode node, TransformContext context) {
  if (node is! ElementNode || node.props.isEmpty) return null;
  final attrs = _defaultAssetUrlTags[node.tag];
  if (attrs == null) return null;
  for (var index = 0; index < node.props.length; index++) {
    final attr = node.props[index];
    if (attr is! AttributeNode) continue;
    if (!attrs.contains(attr.name) || attr.value == null) continue;
    final content = attr.value!.content;
    if (_isSkippableUrl(content)) continue;
    final (path, hash) = _parseUrl(content);
    final exp = _importsExpression(path, hash, attr.loc, context);
    if (exp == null) continue;
    node.props[index] = DirectiveNode('bind', ':${attr.name}', attr.loc,
        arg: createSimpleExp(attr.name, true, attr.loc), exp: exp);
  }
  return null;
}

bool _isSkippableUrl(String content) {
  return _externalRE.hasMatch(content) ||
      _dataUrlRE.hasMatch(content) ||
      content.startsWith('#') ||
      !_isRelativeUrl(content);
}

SimpleExpression? _importsExpression(
    String path, String? hash, TmplLoc loc, TransformContext context) {
  if (path.isEmpty) return null;
  SimpleExpression exp;
  final existingIndex =
      context.imports.indexWhere((i) => (i as Map)['path'] == path);
  if (existingIndex > -1) {
    exp = (context.imports[existingIndex] as Map)['exp'] as SimpleExpression;
  } else {
    final name = '_imports_${context.imports.length}';
    exp = createSimpleExp(name, false, loc, ctCanStringify);
    context.imports.add({'exp': exp, 'path': _decodeUriComponent(path)});
  }
  if (hash == null) return exp;
  return _hashExpression(exp, hash, loc, context);
}

String _decodeUriComponent(String path) {
  try {
    return Uri.decodeComponent(path);
  } catch (_) {
    return path;
  }
}

SimpleExpression _hashExpression(
    SimpleExpression exp, String hash, TmplLoc loc, TransformContext context) {
  final name = exp.content;
  final hashExp = "$name + '$hash'";
  if (!context.hoistStatic) {
    return createSimpleExp(hashExp, false, loc, ctCanStringify);
  }
  final existingHoistIndex = context.hoists.indexWhere((h) =>
      h is SimpleExpression && !h.static_ && h.content == hashExp);
  if (existingHoistIndex > -1) {
    return createSimpleExp(
        '_hoisted_${existingHoistIndex + 1}', false, loc, ctCanHoist);
  }
  return context.hoist(createSimpleExp(hashExp, false, loc, ctCanStringify));
}

Object? transformSrcset(TmplNode node, TransformContext context) {
  if (node is! ElementNode) return null;
  if (!_srcsetTags.contains(node.tag) || node.props.isEmpty) return null;
  for (var index = 0; index < node.props.length; index++) {
    final attr = node.props[index];
    if (attr is! AttributeNode ||
        attr.name != 'srcset' ||
        attr.value == null) {
      continue;
    }
    _processSrcsetAttr(node, index, attr, context);
  }
  return null;
}

void _processSrcsetAttr(
    ElementNode node, int index, AttributeNode attr, TransformContext context) {
  final value = attr.value!.content;
  if (value.isEmpty) return;
  final candidates = value.split(',').map((s) {
    final parts =
        s.replaceAll(_escapedSpaceRE, ' ').trim().split(' ');
    return (parts[0], parts.length > 1 ? parts[1] : null);
  }).toList();
  // Fold data-url candidates (they contain a comma) back together.
  for (var i = 0; i < candidates.length; i++) {
    if (_dataUrlRE.hasMatch(candidates[i].$1) && i + 1 < candidates.length) {
      final next = candidates[i + 1];
      candidates[i + 1] = ('${candidates[i].$1},${next.$1}', next.$2);
      candidates.removeAt(i);
    }
  }
  if (!candidates.any((c) => _shouldProcessUrl(c.$1))) return;
  _rewriteSrcset(node, index, attr, candidates, context);
}

bool _shouldProcessUrl(String url) {
  return url.isNotEmpty &&
      !_externalRE.hasMatch(url) &&
      !_dataUrlRE.hasMatch(url) &&
      _isRelativeUrl(url);
}

void _rewriteSrcset(ElementNode node, int index, AttributeNode attr,
    List<(String, String?)> candidates, TransformContext context) {
  final compound = createCompoundExp([], attr.loc);
  for (var i = 0; i < candidates.length; i++) {
    final (url, descriptor) = candidates[i];
    if (_shouldProcessUrl(url)) {
      final (path, _) = _parseUrl(url);
      if (path.isNotEmpty) {
        compound.children.add(_srcsetImportExp(path, attr.loc, context));
      }
    } else {
      compound.children
          .add(createSimpleExp('"$url"', false, attr.loc, ctCanStringify));
    }
    final isNotLast = candidates.length - 1 > i;
    if (descriptor != null && isNotLast) {
      compound.children.add(" + ' $descriptor, ' + ");
    } else if (descriptor != null) {
      compound.children.add(" + ' $descriptor'");
    } else if (isNotLast) {
      compound.children.add(" + ', ' + ");
    }
  }
  Object exp = compound;
  if (context.hoistStatic) {
    final hoisted = context.hoist(compound);
    hoisted.constType = ctCanStringify;
    exp = hoisted;
  }
  node.props[index] = DirectiveNode('bind', ':srcset', attr.loc,
      arg: createSimpleExp('srcset', true, attr.loc),
      exp: exp is SimpleExpression ? exp : null);
}

SimpleExpression _srcsetImportExp(
    String path, TmplLoc loc, TransformContext context) {
  final existingIndex =
      context.imports.indexWhere((i) => (i as Map)['path'] == path);
  if (existingIndex > -1) {
    return createSimpleExp(
        '_imports_$existingIndex', false, loc, ctCanStringify);
  }
  final exp = createSimpleExp(
      '_imports_${context.imports.length}', false, loc, ctCanStringify);
  context.imports.add({'exp': exp, 'path': path});
  return exp;
}
