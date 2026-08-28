// Port of compiler-core transformExpression + processExpression.
import '../../ts_parser.dart';

import '../../script/src_view.dart';
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import 'expression_walk.dart';

final _literalWhitelisted = {'true', 'false', 'null', 'this'};

Object? transformExpression(TmplNode node, TransformContext context) {
  if (node is InterpolationNode) {
    node.content = processExpression(node.content as SimpleExpression, context);
  } else if (node is ElementNode) {
    final memo = findDir(node, 'memo');
    for (var i = 0; i < node.props.length; i++) {
      final dir = node.props[i];
      if (dir is! DirectiveNode || dir.name == 'for') continue;
      _processDirectiveExp(dir, memo, context, node);
    }
  }
  return null;
}

void _processDirectiveExp(
  DirectiveNode dir,
  DirectiveNode? memo,
  TransformContext context,
  TmplNode node,
) {
  final exp = dir.exp;
  final arg = dir.arg;
  // key has been processed in transformFor (vMemo + vFor combination only).
  final memoKeyProcessed =
      memo != null &&
      context.vForMemoKeyedNodes.contains(node) &&
      arg is SimpleExpression &&
      arg.content == 'key';
  if (exp is SimpleExpression &&
      !(dir.name == 'on' && arg != null) &&
      !memoKeyProcessed) {
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

TmplNode processExpression(
  SimpleExpression node,
  TransformContext context, {
  bool asParams = false,
  bool asRawStatements = false,
  KnownIds? localVars,
}) {
  if (!context.prefixIdentifiers || node.content.trim().isEmpty) {
    return node;
  }
  final rawExp = node.content;
  final ast = node.ast;
  if (identical(ast, ExpAst.failed)) return node;
  if (ast == null && isSimpleIdentifier(rawExp)) {
    return _processSimpleIdentifier(node, context, rawExp, asParams);
  }
  final parsed = _parseExpression(
    node,
    context,
    rawExp,
    asParams,
    asRawStatements,
  );
  if (parsed == null) return node;
  return _rebuildExpression(node, context, rawExp, parsed);
}

TmplNode _processSimpleIdentifier(
  SimpleExpression node,
  TransformContext context,
  String rawExp,
  bool asParams,
) {
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

String _rewriteIdentifier(
  String raw,
  TransformContext context, {
  AstNode? parent,
  WalkedIdent? id,
  int Function(int)? byteToChar,
  String Function(int, int)? sliceText,
  bool destructureAssignment = false,
  bool isNewExpression = false,
}) {
  final bindings = context.bindingMetadata;
  final type = bindings[raw];
  if (context.inline) {
    return _rewriteInline(
      raw,
      type,
      context,
      parent: parent,
      id: id,
      byteToChar: byteToChar,
      sliceText: sliceText,
      destructureAssignment: destructureAssignment,
      isNewExpression: isNewExpression,
    );
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
String _rewriteInline(
  String raw,
  String? type,
  TransformContext context, {
  AstNode? parent,
  WalkedIdent? id,
  int Function(int)? byteToChar,
  String Function(int, int)? sliceText,
  bool destructureAssignment = false,
  bool isNewExpression = false,
}) {
  final lval = _lvalKind(parent, id, byteToChar ?? (b) => b);
  // Lazy: helperString(hUnref) registers the import as a side effect, so it
  // must not run unless the unref form is actually emitted.
  String unrefWrapped() => isNewExpression
      ? '(${context.helperString(hUnref)}($raw))'
      : '${context.helperString(hUnref)}($raw)';
  switch (type) {
    case 'setup-const':
    case 'literal-const':
    case 'setup-reactive-const':
      return raw;
    case 'setup-ref':
      return '$raw.value';
    case 'setup-maybe-ref':
      return lval == _LVal.none && !destructureAssignment
          ? unrefWrapped()
          : '$raw.value';
    case 'setup-let':
      if (lval == _LVal.assign) {
        return _rewriteInlineAssign(raw, context, parent!, byteToChar!, sliceText!);
      }
      if (lval == _LVal.update) {
        return _rewriteInlineUpdate(raw, context, parent!, id!, byteToChar!, sliceText!);
      }
      if (destructureAssignment) return raw;
      return unrefWrapped();
    case 'props':
      return _propsAccessExp(raw);
    case 'props-aliased':
      final alias = context.bindingMetadata['__propsAliases:$raw'] ?? raw;
      return _propsAccessExp(alias);
  }
  return '_ctx.$raw';
}

/// setup-let 赋值左值：isRef 三元（官方形态），RHS 递归改写。
String _rewriteInlineAssign(
  String raw,
  TransformContext context,
  AstNode parent,
  int Function(int) byteToChar,
  String Function(int, int) sliceText,
) {
  final tsIgnore = context.isTS ? ' //@ts-ignore\n' : '';
  final first = parent.children.first;
  final right = parent.children.last;
  final op = sliceText(first.endByte, right.startByte).trim();
  final rExp = sliceText(right.startByte, right.endByte);
  final processed = stringifyExpression(
    processExpression(
      SimpleExpression(rExp, false, locStub()),
      context,
      localVars: KnownIds(context.identifiers),
    ),
  );
  return '${context.helperString(hIsRef)}($raw)$tsIgnore'
      ' ? $raw.value $op $processed : $raw';
}

/// update 表达式（n++ / ++n）：操作符在参数前为前缀形式，参数后为后缀。
String _rewriteInlineUpdate(
  String raw,
  TransformContext context,
  AstNode parent,
  WalkedIdent id,
  int Function(int) byteToChar,
  String Function(int, int) sliceText,
) {
  final tsIgnore = context.isTS ? ' //@ts-ignore\n' : '';
  final first = parent.children.first;
  // Prefix form: the operator sits before the argument (parent starts at
  // the operator); postfix: after it. Compute both from the actual spans so
  // prefix operators are never dropped.
  final pre = sliceText(parent.startByte, first.startByte).trim();
  final post = sliceText(first.endByte, parent.endByte).trim();
  id
    ..startChar = byteToChar(parent.startByte)
    ..endChar = byteToChar(parent.endByte);
  return '${context.helperString(hIsRef)}($raw)$tsIgnore'
      ' ? $pre$raw.value$post : $pre$raw$post';
}

enum _LVal { none, assign, update }

_LVal _lvalKind(
  AstNode? parent,
  WalkedIdent? id,
  int Function(int byteOffset) byteToChar,
) {
  if (parent == null || id == null || parent.children.isEmpty) {
    return _LVal.none;
  }
  final start = byteToChar(parent.children.first.startByte);
  final end = byteToChar(parent.children.first.endByte);
  final covers =
      parent.children.first.type == 'identifier' &&
      start <= id.startChar &&
      id.endChar <= end;
  switch (parent.type) {
    case 'assignment_expression':
    case 'augmented_assignment_expression':
      return covers ? _LVal.assign : _LVal.none;
    case 'update_expression':
      return covers ? _LVal.update : _LVal.none;
  }
  return _LVal.none;
}

final _plainIdentRE = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');

/// 官方 genPropsAccessExp。
String _propsAccessExp(String name) {
  final plain = _plainIdentRE.hasMatch(name);
  return plain ? '__props.$name' : '__props[${_jsStr(name)}]';
}

String _jsStr(String s) =>
    '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

_ParsedExp? _parseExpression(
  SimpleExpression node,
  TransformContext context,
  String rawExp,
  bool asParams,
  bool asRawStatements,
) {
  final source = asRawStatements
      ? ' $rawExp '
      : '($rawExp)${asParams ? '=>{}' : ''}';
  // Batch pre-pass hit: identical tree to an individual parse (the wrapped
  // source fully determines it), so consumers see no difference.
  final cached = context.exprCache?[source];
  if (cached != null) return _ParsedExp(cached, source);
  try {
    final parser = TSParser();
    final root = parser.parse(code: source, language: 'ts');
    if (_hasErrorNode(root)) {
      context.onError(
        TmplCompileError(
          45,
          'Error parsing JavaScript expression: $rawExp',
          node.loc,
        ),
      );
      node.ast = ExpAst.failed;
      return null;
    }
    return _ParsedExp(root, source);
  } catch (e) {
    context.onError(
      TmplCompileError(
        45,
        'Error parsing JavaScript expression: $rawExp',
        node.loc,
      ),
    );
    node.ast = ExpAst.failed;
    return null;
  }
}

bool _hasErrorNode(AstNode node) {
  if (node.type == 'ERROR') return true;
  return node.children.any(_hasErrorNode);
}

TmplNode _rebuildExpression(
  SimpleExpression node,
  TransformContext context,
  String rawExp,
  _ParsedExp parsed,
) {
  final srcView = SrcView(parsed.source);
  final knownIds = KnownIds(context.identifiers);
  final ids = <WalkedIdent>[];
  void onIdent(
    WalkedIdent id,
    AstNode? parent,
    bool isRefed,
    bool isLocal, {
    bool destructureAssignment = false,
    bool isNewExpression = false,
  }) {
    _onIdentifier(
      id,
      parent,
      isRefed,
      isLocal,
      context,
      ids,
      srcView.charOf,
      (s, e) => srcView.slice(srcView.charOf(s), srcView.charOf(e)),
      destructureAssignment: destructureAssignment,
      isNewExpression: isNewExpression,
    );
  }

  final walker = ExpressionWalker(srcView, onIdent, knownIds);
  walker.rootExp = _unwrapTop(parsed.root);
  walker.walk(parsed.root);
  ids.sort((a, b) => a.startChar.compareTo(b.startChar));
  return _spliceChildren(node, rawExp, ids, knownIds);
}

void _onIdentifier(
  WalkedIdent id,
  AstNode? parent,
  bool isRefed,
  bool isLocal,
  TransformContext context,
  List<WalkedIdent> ids,
  int Function(int byteOffset) byteToChar,
  String Function(int, int) sliceText, {
  bool destructureAssignment = false,
  bool isNewExpression = false,
}) {
  if (id.name.startsWith('_filter_')) return;
  final needPrefix = isRefed && _canPrefix(id.name);
  if (needPrefix && !isLocal) {
    // 对象简写与赋值解构目标：改写 value 后需补回 'key: '（官方
    // isStaticProperty(parent)&&parent.shorthand 分支）。带默认值的
    // object_assignment_pattern 不在此列（官方父节点是 AssignmentPattern，
    // 非 shorthand，无 key 前缀）。
    final shorthandKey =
        parent != null &&
        (parent.type == 'object' || parent.type == 'object_pattern');
    if (shorthandKey && (parent.type == 'object' || destructureAssignment)) {
      id.prefix = '${id.name}: ';
    }
    id.rewritten = _rewriteIdentifier(
      id.name,
      context,
      parent: parent,
      id: id,
      byteToChar: byteToChar,
      sliceText: sliceText,
      destructureAssignment: destructureAssignment,
      isNewExpression: isNewExpression,
    );
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

TmplNode _spliceChildren(
  SimpleExpression node,
  String rawExp,
  List<WalkedIdent> ids,
  KnownIds knownIds,
) {
  final children = <Object?>[];
  for (var i = 0; i < ids.length; i++) {
    final id = ids[i];
    final start = id.startChar - 1;
    final end = id.endChar - 1;
    final last = i > 0 ? ids[i - 1] : null;
    final leadingText = rawExp.substring(
      last != null ? last.endChar - 1 : 0,
      start,
    );
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
  SimpleExpression node,
  String rawExp,
  WalkedIdent id,
  int start,
  int end,
) {
  final source = rawExp.substring(start, end);
  final loc = TmplLoc(
    _advanceWithClone(node.loc.start, source, start),
    _advanceWithClone(node.loc.start, source, end),
    source,
  );
  return SimpleExpression(
    id.rewritten ?? id.name,
    false,
    loc,
    id.isConstant ? ctCanStringify : ctNotConstant,
  );
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
  clone.column = lastNewLinePos == -1 ? clone.column + n : n - lastNewLinePos;
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
  final (node, nodeSource) = _topNodeOf(_expSource(exp), context);
  if (node == null) return false;
  if (node.type == 'member_expression' || node.type == 'subscript_expression') {
    return true;
  }
  return node.type == 'identifier' && _source(nodeSource, node) != 'undefined';
}

String _source(String source, AstNode node) => SrcView(source).textOf(node);

/// Port of isFnExpressionNode.
bool isFnExpression(Object exp, TransformContext context) {
  final (node, _) = _topNodeOf(_expSource(exp), context);
  if (node == null) return false;
  return node.type == 'function_expression' ||
      node.type == 'arrow_function' ||
      node.type == 'generator_function';
}

/// Unwrapped top node for [source], served from the batch exprCache when
/// present (key is the wrapped form; _unwrapTop strips the parens so node
/// types match a bare parse). Falls back to an individual parse on miss or
/// when the cached tree carries an ERROR node. Returns the node plus the
/// source string its byte offsets are relative to.
(AstNode?, String) _topNodeOf(String source, TransformContext context) {
  final wrapped = '($source)';
  final cached = context.exprCache?[wrapped];
  if (cached != null && !_hasErrorNode(cached)) {
    return (_unwrapTop(cached), wrapped);
  }
  try {
    final root = TSParser().parse(code: source, language: 'ts');
    return (_unwrapTop(root), source);
  } catch (_) {
    return (null, source);
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
