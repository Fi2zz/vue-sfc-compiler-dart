// Port of compiler-core transformExpression + processExpression.
import 'package:vue_sfc_parser/ts_parser.dart';

import '../../script/src_view.dart';
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import 'expression_walk.dart';

final _literalWhitelisted = {'true', 'false', 'null', 'this'};

Object? transformExpression(TmplNode node, TransformContext context) {
  if (node is InterpolationNode) {
    node.content =
        processExpression(node.content as SimpleExpression, context);
  } else if (node is ElementNode) {
    final memo = findDir(node, 'memo');
    for (var i = 0; i < node.props.length; i++) {
      final dir = node.props[i];
      if (dir is! DirectiveNode || dir.name == 'for') continue;
      _processDirectiveExp(dir, memo, context);
    }
  }
  return null;
}

void _processDirectiveExp(
    DirectiveNode dir, DirectiveNode? memo, TransformContext context) {
  final exp = dir.exp;
  final arg = dir.arg;
  if (exp is SimpleExpression &&
      !(dir.name == 'on' && arg != null) &&
      !(memo != null && arg is SimpleExpression && arg.content == 'key')) {
    dir.exp = processExpression(exp, context, asParams: dir.name == 'slot');
  }
  if (arg is SimpleExpression && !arg.static_) {
    dir.arg = processExpression(arg, context);
  }
}

/// Whether [exp] was pre-parsed at parse time (mirrors createExp): null means
/// "simple identifier", false means "parse failed", a node means parsed AST.
class ExpAst {
  static const failed = Object();
}

final class _ParsedExp {
  final AstNode root;
  final String source;
  _ParsedExp(this.root, this.source);
}

TmplNode processExpression(SimpleExpression node, TransformContext context,
    {bool asParams = false,
    bool asRawStatements = false,
    KnownIds? localVars}) {
  if (!context.prefixIdentifiers || node.content.trim().isEmpty) {
    return node;
  }
  final rawExp = node.content;
  final ast = node.ast;
  if (identical(ast, ExpAst.failed)) return node;
  if (ast == null && isSimpleIdentifier(rawExp)) {
    return _processSimpleIdentifier(node, context, rawExp, asParams);
  }
  final parsed = _parseExpression(node, context, rawExp, asParams,
      asRawStatements);
  if (parsed == null) return node;
  return _rebuildExpression(node, context, rawExp, parsed);
}

TmplNode _processSimpleIdentifier(SimpleExpression node,
    TransformContext context, String rawExp, bool asParams) {
  final isScopeVarReference = (context.identifiers[rawExp] ?? 0) != 0;
  final isAllowedGlobal = isGloballyAllowed(rawExp);
  final isLiteral = _literalWhitelisted.contains(rawExp);
  final bindings = context.bindingMetadata;
  if (!asParams &&
      !isScopeVarReference &&
      !isLiteral &&
      (!isAllowedGlobal || bindings.containsKey(rawExp))) {
    if (_isConstBinding(bindings[rawExp])) {
      node.constType = ctCanSkipPatch;
    }
    node.content = _rewriteIdentifier(rawExp, context);
  } else if (!isScopeVarReference) {
    node.constType = isLiteral ? ctCanStringify : ctCanHoist;
  }
  return node;
}

bool _isConstBinding(String? type) =>
    type == 'setup-const' || type == 'literal-const';

String _rewriteIdentifier(String raw, TransformContext context,
    {AstNode? parent, WalkedIdent? id, int Function(int)? byteToChar}) {
  final bindings = context.bindingMetadata;
  final type = bindings[raw];
  if (context.inline) {
    return _rewriteInline(raw, type, context,
        parent: parent, id: id, byteToChar: byteToChar);
  }
  if (type != null && (type.startsWith('setup') || type == 'literal-const')) {
    return '\$setup.$raw';
  }
  if (type == 'props-aliased') {
    return "\$props['${bindings['__propsAliases:$raw'] ?? raw}']";
  }
  if (type != null) {
    return '\$$type.$raw';
  }
  return '_ctx.$raw';
}

/// 官方 rewriteIdentifier 的 inline 分支：render 内联进 setup 后，绑定按
/// kind 直接引用（ref 类补 .value / unref），不再有 $setup 前缀。
String _rewriteInline(String raw, String? type, TransformContext context,
    {AstNode? parent, WalkedIdent? id, int Function(int)? byteToChar}) {
  final lval = _isLValPosition(parent, id, byteToChar ?? (b) => b);
  switch (type) {
    case 'setup-const':
    case 'literal-const':
    case 'setup-reactive-const':
      return raw;
    case 'setup-ref':
      return '$raw.value';
    case 'setup-maybe-ref':
      return lval ? '$raw.value' : '${context.helperString(hUnref)}($raw)';
    case 'setup-let':
      if (!lval) return '${context.helperString(hUnref)}($raw)';
      // 赋值/自更新左值：isRef 三元（官方形态）。
      final tsIgnore = context.isTS ? ' //@ts-ignore\n' : '';
      return '${context.helperString(hIsRef)}($raw)$tsIgnore'
          '? $raw.value : $raw';
    case 'props':
      return _propsAccessExp(raw);
    case 'props-aliased':
      final alias =
          context.bindingMetadata['__propsAliases:$raw'] ?? raw;
      return _propsAccessExp(alias);
  }
  return '_ctx.$raw';
}

/// 官方 genPropsAccessExp。
String _propsAccessExp(String name) {
  final plain = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(name);
  return plain ? '__props.$name' : '__props[${_jsStr(name)}]';
}

String _jsStr(String s) =>
    '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// 赋值表达式/自更新表达式的左值位置判定（首子节点即左值）。
/// [byteToChar] 由调用方注入（walker 的 SrcView），统一字节/字符坐标；
/// WalkedIdent 的 startChar/endChar 与转换结果同处包裹源 char 空间。
bool _isLValPosition(AstNode? parent, WalkedIdent? id,
    int Function(int byteOffset) byteToChar) {
  if (parent == null || id == null || parent.children.isEmpty) return false;
  const lvalParents = {'assignment_expression', 'update_expression'};
  if (!lvalParents.contains(parent.type)) return false;
  final first = parent.children.first;
  if (first.type != 'identifier') return false;
  final start = byteToChar(first.startByte);
  final end = byteToChar(first.endByte);
  return start <= id.startChar && id.endChar <= end;
}

_ParsedExp? _parseExpression(SimpleExpression node, TransformContext context,
    String rawExp, bool asParams, bool asRawStatements) {
  final source = asRawStatements
      ? ' $rawExp '
      : '($rawExp)${asParams ? '=>{}' : ''}';
  try {
    final parser = TSParser();
    final root = parser.parse(code: source, language: 'ts');
    if (_hasErrorNode(root)) {
      context.onError(TmplCompileError(
          45, 'Error parsing JavaScript expression: $rawExp', node.loc));
      node.ast = ExpAst.failed;
      return null;
    }
    return _ParsedExp(root, source);
  } catch (e) {
    context.onError(TmplCompileError(
        45, 'Error parsing JavaScript expression: $rawExp', node.loc));
    node.ast = ExpAst.failed;
    return null;
  }
}

bool _hasErrorNode(AstNode node) {
  if (node.type == 'ERROR') return true;
  return node.children.any(_hasErrorNode);
}

TmplNode _rebuildExpression(SimpleExpression node, TransformContext context,
    String rawExp, _ParsedExp parsed) {
  final srcView = SrcView(parsed.source);
  final knownIds = KnownIds(context.identifiers);
  final ids = <WalkedIdent>[];
  void onIdent(WalkedIdent id, AstNode? parent, bool isRefed, bool isLocal) {
    _onIdentifier(id, parent, isRefed, isLocal, context, ids,
        srcView.charOf);
  }

  final walker = ExpressionWalker(srcView, onIdent, knownIds);
  walker.rootExp = _unwrapTop(parsed.root);
  walker.walk(parsed.root);
  ids.sort((a, b) => a.startChar.compareTo(b.startChar));
  return _spliceChildren(node, rawExp, ids, knownIds);
}

void _onIdentifier(WalkedIdent id, AstNode? parent, bool isRefed,
    bool isLocal, TransformContext context, List<WalkedIdent> ids,
    int Function(int byteOffset) byteToChar) {
  if (id.name.startsWith('_filter_')) return;
  final needPrefix = isRefed && _canPrefix(id.name);
  if (needPrefix && !isLocal) {
    if (parent != null && parent.type == 'object') {
      id.prefix = '${id.name}: ';
    }
    id.rewritten =
        _rewriteIdentifier(id.name, context, parent: parent, id: id, byteToChar: byteToChar);
    ids.add(id);
  } else {
    if (!(needPrefix && isLocal) && !_isCallOrMember(parent)) {
      id.isConstant = true;
    }
    ids.add(id);
  }
}

bool _canPrefix(String name) {
  if (isGloballyAllowed(name)) return false;
  if (name == 'require') return false;
  return true;
}

bool _isCallOrMember(AstNode? parent) {
  if (parent == null) return false;
  const excluded = {
    'call_expression',
    'new_expression',
    'member_expression',
    'subscript_expression',
  };
  return excluded.contains(parent.type);
}

TmplNode _spliceChildren(SimpleExpression node, String rawExp,
    List<WalkedIdent> ids, KnownIds knownIds) {
  final children = <Object?>[];
  for (var i = 0; i < ids.length; i++) {
    final id = ids[i];
    final start = id.startChar - 1;
    final end = id.endChar - 1;
    final last = i > 0 ? ids[i - 1] : null;
    final leadingText =
        rawExp.substring(last != null ? last.endChar - 1 : 0, start);
    if (leadingText.isNotEmpty || id.prefix != null) {
      children.add(leadingText + (id.prefix ?? ''));
    }
    children.add(_identExpression(node, rawExp, id, start, end));
    if (i == ids.length - 1 && end < rawExp.length) {
      children.add(rawExp.substring(end));
    }
  }
  if (children.isEmpty) {
    node.constType = ctCanStringify;
    node.identifiers = knownIds.ownKeys();
    return node;
  }
  final ret = createCompoundExp(children, node.loc);
  ret.identifiers = knownIds.ownKeys();
  return ret;
}

SimpleExpression _identExpression(
    SimpleExpression node, String rawExp, WalkedIdent id, int start, int end) {
  final source = rawExp.substring(start, end);
  final loc = TmplLoc(
    _advanceWithClone(node.loc.start, source, start),
    _advanceWithClone(node.loc.start, source, end),
    source,
  );
  return SimpleExpression(id.rewritten ?? id.name, false, loc,
      id.isConstant ? ctCanStringify : ctNotConstant);
}

/// Port of official advancePositionWithClone as used in processExpression:
/// advances [pos] by [n] chars, counting newlines inside source[0..n].
TmplPosition _advanceWithClone(TmplPosition pos, String source, int n) {
  var linesCount = 0;
  var lastNewLinePos = -1;
  for (var i = 0; i < n && i < source.length; i++) {
    if (source.codeUnitAt(i) == 10) {
      linesCount++;
      lastNewLinePos = i;
    }
  }
  final clone = pos.clone();
  clone.offset += n;
  clone.line += linesCount;
  clone.column =
      lastNewLinePos == -1 ? clone.column + n : n - lastNewLinePos;
  return clone;
}

String stringifyExpression(Object exp) {
  if (exp is String) return exp;
  if (exp is SimpleExpression) return exp.content;
  if (exp is CompoundExpression) {
    return exp.children
        .map((c) => c == null ? '' : stringifyExpression(c))
        .join('');
  }
  return '';
}

String _expSource(Object exp) =>
    exp is SimpleExpression ? exp.content : (exp as TmplNode).loc.source;

/// Port of isMemberExpressionNode.
bool isMemberExpressionOf(Object exp, TransformContext context) {
  try {
    final source = _expSource(exp);
    final parser = TSParser();
    final root = parser.parse(code: source, language: 'ts');
    final node = _unwrapTop(root);
    if (node == null) return false;
    if (node.type == 'member_expression' ||
        node.type == 'subscript_expression') {
      return true;
    }
    return node.type == 'identifier' &&
        _source(source, node) != 'undefined';
  } catch (_) {
    return false;
  }
}

String _source(String source, AstNode node) =>
    SrcView(source).textOf(node);

/// Port of isFnExpressionNode.
bool isFnExpression(Object exp, TransformContext context) {
  try {
    final source = _expSource(exp);
    final parser = TSParser();
    final root = parser.parse(code: source, language: 'ts');
    final node = _unwrapTop(root);
    if (node == null) return false;
    return node.type == 'function_expression' ||
        node.type == 'arrow_function' ||
        node.type == 'generator_function';
  } catch (_) {
    return false;
  }
}

/// Unwrap program > expression_statement > (parens) > TS wrappers.
AstNode? _unwrapTop(AstNode node) {
  var current = node;
  while (true) {
    if (current.type == 'program') {
      if (current.children.isEmpty) return null;
      current = current.children.first;
    } else if (current.type == 'expression_statement') {
      if (current.children.isEmpty) return null;
      current = current.children.first;
    } else if (current.type == 'parenthesized_expression' ||
        current.type == 'as_expression' ||
        current.type == 'satisfies_expression' ||
        current.type == 'non_null_expression') {
      if (current.children.isEmpty) return null;
      current = current.children.first;
    } else {
      return current;
    }
  }
}
