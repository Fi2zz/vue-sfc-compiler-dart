// Ports of @vue/shared and compiler-core utility predicates/helpers used by
// the template transform + codegen pipeline.

import 'tmpl_ast.dart';

/// Port of @vue/shared makeMap: builds a lookup predicate from a CSV string.
bool Function(String) makeMap(String str) {
  final set = str.split(',').toSet();
  return (val) => set.contains(val);
}

final isReservedProp = makeMap(
    ',key,ref,ref_for,ref_key,onVnodeBeforeMount,onVnodeMounted,'
    'onVnodeBeforeUpdate,onVnodeUpdated,onVnodeBeforeUnmount,onVnodeUnmounted');

final isBuiltInDirective =
    makeMap('bind,cloak,else-if,else,for,html,if,model,on,once,pre,show,'
        'slot,text,memo');

final isGloballyAllowed = makeMap(
    'Infinity,undefined,NaN,isFinite,isNaN,parseFloat,parseInt,decodeURI,'
    'decodeURIComponent,encodeURI,encodeURIComponent,Math,Number,Date,Array,'
    'Object,Boolean,String,RegExp,Map,Set,JSON,Intl,BigInt,console,Error,'
    'Symbol');

bool isOn(String key) =>
    key.length > 2 &&
    key.codeUnitAt(0) == 111 &&
    key.codeUnitAt(1) == 110 &&
    (key.codeUnitAt(2) > 122 || key.codeUnitAt(2) < 97);

bool isModelListener(String key) => key.startsWith('onUpdate:');

final _camelizeRE = RegExp(r'-\w');

String camelize(String str) => str.replaceAllMapped(
    _camelizeRE, (m) => m[0]!.substring(1).toUpperCase());

final _hyphenateRE = RegExp(r'\B([A-Z])');

String hyphenate(String str) =>
    str.replaceAllMapped(_hyphenateRE, (m) => '-${m[1]}').toLowerCase();

String capitalize(String str) =>
    str.isEmpty ? str : str[0].toUpperCase() + str.substring(1);

String toHandlerKey(String str) => str.isEmpty ? '' : 'on${capitalize(str)}';

final _nonIdentifierRE = RegExp(r'^$|^\d|[^\$\w -￿]');

bool isSimpleIdentifier(String name) => !_nonIdentifierRE.hasMatch(name);

bool isStaticExp(Object? p) => p is SimpleExpression && p.static_;

// --- Tree predicates (compiler-core utils) ---

bool isTextNode(Object? node) =>
    node is TmplNode && (node.type == ntInterpolation || node.type == ntText);

bool isVPre(Object? p) => p is DirectiveNode && p.name == 'pre';

bool isVSlot(Object? p) => p is DirectiveNode && p.name == 'slot';

bool isTemplateNode(Object? node) =>
    node is ElementNode && node.tagType == etTemplate;

bool isSlotOutlet(Object? node) =>
    node is ElementNode && node.tagType == etSlot;

DirectiveNode? findDir(TmplNode node, Object name, [bool allowEmpty = false]) {
  if (node is! ElementNode) return null;
  for (final p in node.props) {
    if (p is! DirectiveNode) continue;
    if (!allowEmpty && p.exp == null) continue;
    final matched = name is String
        ? p.name == name
        : (name as RegExp).hasMatch(p.name);
    if (matched) return p;
  }
  return null;
}

Object? findProp(TmplNode node, String name,
    [bool dynamicOnly = false, bool allowEmpty = false]) {
  if (node is! ElementNode) return null;
  for (final p in node.props) {
    if (p is AttributeNode) {
      if (dynamicOnly) continue;
      if (p.name == name && (p.value != null || allowEmpty)) return p;
    } else if (p is DirectiveNode &&
        p.name == 'bind' &&
        (p.exp != null || allowEmpty) &&
        isStaticArgOf(p.arg, name)) {
      return p;
    }
  }
  return null;
}

bool isStaticArgOf(Object? arg, String name) =>
    arg is SimpleExpression && arg.static_ && arg.content == name;

bool hasDynamicKeyVBind(ElementNode node) => node.props.any((p) =>
    p is DirectiveNode &&
    p.name == 'bind' &&
    (p.arg == null ||
        p.arg is! SimpleExpression ||
        !(p.arg as SimpleExpression).static_));

String toValidAssetId(String name, String type) {
  final buf = StringBuffer('_${type}_');
  for (var i = 0; i < name.length; i++) {
    final c = name[i];
    final word = RegExp(r'[\w]').hasMatch(c);
    buf.write(word ? c : (c == '-' ? '_' : name.codeUnitAt(i).toString()));
  }
  return buf.toString();
}

// --- Position helpers ---

TmplPosition advancePositionWithMutation(TmplPosition pos, String source,
    [int? numberOfCharacters]) {
  final n = numberOfCharacters ?? source.length;
  var linesCount = 0;
  var lastNewLinePos = -1;
  for (var i = 0; i < n; i++) {
    if (source.codeUnitAt(i) == 10) {
      linesCount++;
      lastNewLinePos = i;
    }
  }
  pos.offset += n;
  pos.line += linesCount;
  pos.column =
      lastNewLinePos == -1 ? pos.column + n : n - lastNewLinePos;
  return pos;
}

TmplPosition advancePositionWithClone(TmplPosition pos, String source,
    [int? numberOfCharacters]) {
  return advancePositionWithMutation(pos.clone(), source, numberOfCharacters);
}

Never assertTmpl(bool condition, [String? msg]) {
  if (!condition) {
    throw StateError(msg ?? 'unexpected compiler condition');
  }
  throw StateError('unreachable');
}
