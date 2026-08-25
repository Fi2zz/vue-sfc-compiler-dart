// Port of @vue/compiler-core baseParse: tokenizer callbacks -> template AST.

import 'tokenizer.dart';
import 'tmpl_ast.dart';

final class TmplParseError {
  final int code;
  final TmplLoc loc;
  final String? message;
  TmplParseError(this.code, this.loc, [this.message]);
}

final class TmplParserOptions {
  final int parseMode; // modeBase | modeHtml | modeSfc
  final bool comments;
  final bool prefixIdentifiers;
  final String whitespace; // 'condense' | 'preserve'
  final bool Function(String tag) isVoidTag;
  final bool Function(String tag) isPreTag;
  final bool Function(String tag) isIgnoreNewlineTag;
  final bool Function(String tag) isCustomElement;
  final bool Function(String tag)? isNativeTag;
  final bool Function(String tag)? isBuiltInComponent;
  final int Function(String tag, ElementNode? parent, int prevNs) getNamespace;
  final void Function(TmplParseError e) onError;

  const TmplParserOptions({
    this.parseMode = modeBase,
    this.comments = true,
    this.prefixIdentifiers = false,
    this.whitespace = 'condense',
    this.isVoidTag = _no,
    this.isPreTag = _no,
    this.isIgnoreNewlineTag = _no,
    this.isCustomElement = _no,
    this.isNativeTag,
    this.isBuiltInComponent,
    this.getNamespace = _nsZero,
    this.onError = _noopError,
  });

  static bool _no(String tag) => false;
  static int _nsZero(String tag, ElementNode? parent, int prevNs) => nsHtml;
  static void _noopError(TmplParseError e) {}
}

final class _ParserCallbacks implements TokenizerCallbacks {
  final _BaseParseState s;
  _ParserCallbacks(this.s);

  @override
  void onerr(int code, int index) => s.emitError(code, index);

  @override
  void ontext(int start, int end) => s.onText(s.slice(start, end), start, end);

  @override
  void ontextentity(String char, int start, int end) =>
      s.onText(char, start, end);

  @override
  void oninterpolation(int start, int end) => s.onInterpolation(start, end);

  @override
  void onopentagname(int start, int end) => s.onOpenTagName(start, end);

  @override
  void onopentagend(int end) => s.endOpenTag(end);

  @override
  void onclosetag(int start, int end) => s.onCloseTagCallback(start, end);

  @override
  void onselfclosingtag(int end) => s.onSelfClosingTag(end);

  @override
  void onattribname(int start, int end) => s.onAttribName(start, end);

  @override
  void onattribnameend(int end) => s.onAttribNameEnd(end);

  @override
  void onattribdata(int start, int end) => s.onAttribData(start, end);

  @override
  void onattribentity(String char, int start, int end) =>
      s.onAttribEntity(char, start, end);

  @override
  void onattribend(int quote, int end) => s.onAttribEnd(quote, end);

  @override
  void ondirname(int start, int end) => s.onDirName(start, end);

  @override
  void ondirarg(int start, int end) => s.onDirArg(start, end);

  @override
  void ondirmodifier(int start, int end) => s.onDirModifier(start, end);

  @override
  void oncomment(int start, int end) {
    if (s.options.comments) {
      s.addNode(CommentNode(
          s.slice(start, end), s.getLoc(start - 4, end + 3)));
    }
  }

  @override
  void onend() => s.onEnd();

  @override
  void oncdata(int start, int end) {
    final parentNs = s.stack.isEmpty ? s.options.getNamespace('', null, nsHtml) : s.stack[0].ns;
    if (parentNs != nsHtml) {
      s.onText(s.slice(start, end), start, end);
    } else {
      s.emitError(1, start - 9);
    }
  }

  @override
  void onprocessinginstruction(int start, int end) {
    final ns = s.stack.isEmpty ? nsHtml : s.stack[0].ns;
    if (ns == nsHtml) s.emitError(21, start - 1);
  }
}

final class _BaseParseState {
  String input = '';
  TmplParserOptions options = const TmplParserOptions();
  RootNode? root;
  ElementNode? openTag;
  TmplNode? prop;
  String attrValue = '';
  int attrStartIndex = -1;
  int attrEndIndex = -1;
  int inPre = 0;
  bool inVPre = false;
  ElementNode? vPreBoundary;
  final List<ElementNode> stack = [];
  late final Tokenizer tokenizer = Tokenizer(stack, _ParserCallbacks(this));

  // JS String.slice 语义：越界钳制、end<start 返回空串（官方依赖此行为，
  // 如 {{ }} 空插值的空白裁剪）。
  String slice(int start, int end) {
    final s = start.clamp(0, input.length);
    final e = end.clamp(s, input.length);
    return input.substring(s, e);
  }

  TmplLoc getLoc(int start, [int? end]) {
    return TmplLoc(
      tokenizer.getPos(start),
      end == null ? tokenizer.getPos(start) : tokenizer.getPos(end),
      end == null ? '' : slice(start, end),
    );
  }

  void setLocEnd(TmplLoc loc, int end) {
    loc.end = tokenizer.getPos(end);
    loc.source = slice(loc.start.offset, end);
  }

  void addNode(TmplNode node) {
    parentChildren().add(node);
  }

  List<TmplNode> parentChildren() =>
      stack.isEmpty ? root!.children : stack[0].children;

  void emitError(int code, int index, [String? message]) {
    options.onError(TmplParseError(code, getLoc(index, index), message));
  }

  SimpleExpression createExp(String content, bool static_, TmplLoc loc,
      [int constType = ctNotConstant, int parseMode = 0]) {
    // prefixIdentifiers expression AST parsing is handled at transform time.
    return SimpleExpression(content, static_, loc, constType);
  }

  void onText(String content, int start, int end) {
    final children = parentChildren();
    if (children.isNotEmpty && children.last.type == ntText) {
      final last = children.last as TextNode;
      last.content += content;
      setLocEnd(last.loc, end);
    } else {
      children.add(TextNode(content, getLoc(start, end)));
    }
  }

  void onInterpolation(int start, int end) {
    if (inVPre) return onText(slice(start, end), start, end);
    var innerStart = start + tokenizer.delimiterOpen.length;
    var innerEnd = end - tokenizer.delimiterClose.length;
    while (isWhitespaceCode(input.codeUnitAt(innerStart))) {
      innerStart++;
    }
    while (isWhitespaceCode(input.codeUnitAt(innerEnd - 1))) {
      innerEnd--;
    }
    final exp = slice(innerStart, innerEnd);
    // Entity decoding inside interpolation is skipped (rare; decodeHTML).
    addNode(InterpolationNode(
      createExp(exp, false, getLoc(innerStart, innerEnd)),
      getLoc(start, end),
    ));
  }

  void onOpenTagName(int start, int end) {
    final name = slice(start, end);
    openTag = ElementNode(
      name,
      options.getNamespace(
          name, stack.isEmpty ? null : stack[0], nsHtml),
      etElement,
      [],
      [],
      getLoc(start - 1, end),
    );
  }

  void endOpenTag(int end) {
    if (tokenizer.inSFCRoot) {
      openTag!.innerLoc = getLoc(end + 1, end + 1);
    }
    addNode(openTag!);
    final tag = openTag!.tag;
    final ns = openTag!.ns;
    if (ns == nsHtml && options.isPreTag(tag)) inPre++;
    if (options.isVoidTag(tag)) {
      onCloseTag(openTag!, end);
    } else {
      stack.insert(0, openTag!);
      if (ns == nsSvg || ns == nsMathMl) tokenizer.inXML = true;
    }
    openTag = null;
  }

  void onCloseTagCallback(int start, int end) {
    final name = slice(start, end);
    if (options.isVoidTag(name)) return;
    var found = false;
    for (var i = 0; i < stack.length; i++) {
      final e = stack[i];
      if (e.tag.toLowerCase() == name.toLowerCase()) {
        found = true;
        if (i > 0) emitError(24, stack[0].loc.start.offset);
        for (var j = 0; j <= i; j++) {
          final el = stack.removeAt(0);
          onCloseTag(el, end, j < i);
        }
        break;
      }
    }
    if (!found) emitError(23, backTrack(start, 60));
  }

  void onSelfClosingTag(int end) {
    final name = openTag!.tag;
    openTag!.isSelfClosing = true;
    endOpenTag(end);
    if (stack.isNotEmpty && stack[0].tag == name) {
      onCloseTag(stack.removeAt(0), end);
    }
  }

  void onAttribName(int start, int end) {
    prop = AttributeNode(slice(start, end), getLoc(start, end), null,
        getLoc(start));
  }

  void onDirName(int start, int end) {
    final raw = slice(start, end);
    final name = raw == '.' || raw == ':'
        ? 'bind'
        : raw == '@'
            ? 'on'
            : raw == '#'
                ? 'slot'
                : raw.substring(2);
    if (!inVPre && name.isEmpty) emitError(26, start);
    if (inVPre || name.isEmpty) {
      prop = AttributeNode(raw, getLoc(start, end), null, getLoc(start));
      return;
    }
    final dir = DirectiveNode(name, raw, getLoc(start));
    if (raw == '.') {
      dir.modifiers.add(SimpleExpression('prop', true, getLoc(start, start + 1)));
    }
    prop = dir;
    if (name == 'pre') _enterVPre();
  }

  void _enterVPre() {
    inVPre = tokenizer.inVPre = true;
    vPreBoundary = openTag;
    final props = openTag!.props;
    for (var i = 0; i < props.length; i++) {
      if (props[i].type == ntDirective) {
        props[i] = dirToAttr(props[i] as DirectiveNode);
      }
    }
  }

  void onDirArg(int start, int end) {
    if (start == end) return;
    final arg = slice(start, end);
    final p = prop!;
    if (inVPre && !(p is DirectiveNode && p.name == 'pre')) {
      final attr = p as AttributeNode;
      attr.name += arg;
      setLocEnd(attr.nameLoc, end);
      return;
    }
    final dir = p as DirectiveNode;
    final static_ = arg[0] != '[';
    dir.arg = createExp(
      static_ ? arg : arg.substring(1, arg.length - 1),
      static_,
      getLoc(start, end),
      static_ ? ctCanStringify : ctNotConstant,
    );
  }

  void onDirModifier(int start, int end) {
    final mod = slice(start, end);
    final p = prop!;
    if (inVPre && !(p is DirectiveNode && p.name == 'pre')) {
      final attr = p as AttributeNode;
      attr.name += '.$mod';
      setLocEnd(attr.nameLoc, end);
    } else if ((p as DirectiveNode).name == 'slot') {
      final arg = p.arg;
      if (arg is SimpleExpression) {
        arg.content += '.$mod';
        setLocEnd(arg.loc, end);
      }
    } else {
      p.modifiers
          .add(SimpleExpression(mod, true, getLoc(start, end)));
    }
  }

  void onAttribData(int start, int end) {
    attrValue += slice(start, end);
    if (attrStartIndex < 0) attrStartIndex = start;
    attrEndIndex = end;
  }

  void onAttribEntity(String char, int start, int end) {
    attrValue += char;
    if (attrStartIndex < 0) attrStartIndex = start;
    attrEndIndex = end;
  }

  void onAttribNameEnd(int end) {
    final start = prop!.loc.start.offset;
    final name = slice(start, end);
    final p = prop!;
    if (p is DirectiveNode) p.rawName = name;
    final dup = openTag!.props.any((q) =>
        (q is DirectiveNode ? q.rawName : (q as AttributeNode).name) == name);
    if (dup) emitError(2, start);
  }

  void onAttribEnd(int quote, int end) {
    final tag = openTag;
    final p = prop;
    if (tag != null && p != null) {
      setLocEnd(p.loc, end);
      if (quote != 0) _attribValueEnd(quote, end, p, tag);
      if (p is! DirectiveNode || p.name != 'pre') tag.props.add(p);
    }
    attrValue = '';
    attrStartIndex = attrEndIndex = -1;
  }

  void _attribValueEnd(int quote, int end, TmplNode p, ElementNode tag) {
    if (p is AttributeNode) {
      if (p.name == 'class') attrValue = condense(attrValue).trim();
      if (quote == 1 && attrValue.isEmpty) emitError(13, end);
      p.value = TextNode(
        attrValue,
        quote == 1
            ? getLoc(attrStartIndex, attrEndIndex)
            : getLoc(attrStartIndex - 1, attrEndIndex + 1),
      );
      _maybeSfcTemplateLang(p);
      return;
    }
    final dir = p as DirectiveNode;
    dir.exp = createExp(attrValue, false,
        getLoc(attrStartIndex, attrEndIndex));
    if (dir.name == 'for') {
      dir.forParseResult =
          _parseForExpression(dir.exp! as SimpleExpression, this);
    }
  }

  void _maybeSfcTemplateLang(AttributeNode p) {
    final sfcTemplateLang = tokenizer.inSFCRoot &&
        openTag!.tag == 'template' &&
        p.name == 'lang' &&
        attrValue.isNotEmpty &&
        attrValue != 'html';
    if (sfcTemplateLang) {
      tokenizer.enterRCDATA(toCharCodes('</template'), 0);
    }
  }

  void onEnd() {
    final end = input.length;
    if (tokenizer.state != 1) {
      switch (tokenizer.state) {
        case 5:
        case 8:
          emitError(5, end);
        case 3:
        case 4:
          emitError(25, tokenizer.sectionStart);
        case 28:
          emitError(identical(tokenizer.currentSequence, seqCdataEnd) ? 6 : 7, end);
        case 6:
        case 7:
        case 9:
        case 11:
        case 12:
        case 13:
        case 14:
        case 15:
        case 16:
        case 17:
        case 18:
        case 19:
        case 20:
        case 21:
          emitError(9, end);
      }
    }
    for (var index = 0; index < stack.length; index++) {
      onCloseTag(stack[index], end - 1);
      emitError(24, stack[index].loc.start.offset);
    }
  }

  void onCloseTag(ElementNode el, int end, [bool implied = false]) {
    if (implied) {
      setLocEnd(el.loc, backTrack(end, 60));
    } else {
      setLocEnd(el.loc, lookAhead(end, 62) + 1);
    }
    if (tokenizer.inSFCRoot) _finalizeSfcInnerLoc(el);
    _refineTagType(el);
    if (!tokenizer.inRCDATA) {
      el.children = condenseWhitespace(el.children, options.whitespace, inPre);
    }
    if (el.ns == nsHtml && options.isIgnoreNewlineTag(el.tag)) {
      final first = el.children.isEmpty ? null : el.children[0];
      if (first != null && first.type == ntText) {
        (first as TextNode).content =
            first.content.replaceFirst(RegExp(r'^\r?\n'), '');
      }
    }
    if (el.ns == nsHtml && options.isPreTag(el.tag)) inPre--;
    if (identical(vPreBoundary, el)) {
      inVPre = tokenizer.inVPre = false;
      vPreBoundary = null;
    }
    final parentNs = stack.isEmpty ? nsHtml : stack[0].ns;
    if (tokenizer.inXML && parentNs == nsHtml) tokenizer.inXML = false;
  }

  void _finalizeSfcInnerLoc(ElementNode el) {
    final inner = el.innerLoc!;
    if (el.children.isNotEmpty) {
      inner.end = el.children.last.loc.end.clone();
    } else {
      inner.end = inner.start.clone();
    }
    inner.source = slice(inner.start.offset, inner.end.offset);
  }

  void _refineTagType(ElementNode el) {
    if (inVPre) return;
    if (el.tag == 'slot') {
      el.tagType = etSlot;
    } else if (isFragmentTemplate(el)) {
      el.tagType = etTemplate;
    } else if (_componentTag(el)) {
      el.tagType = etComponent;
    }
  }

  bool _componentTag(ElementNode el) {
    if (options.isCustomElement(el.tag)) return false;
    final tag = el.tag;
    final upper = tag.isNotEmpty && tag.codeUnitAt(0) > 64 && tag.codeUnitAt(0) < 91;
    if (tag == 'component' ||
        upper ||
        isCoreComponent(tag) ||
        (options.isBuiltInComponent?.call(tag) ?? false) ||
        (options.isNativeTag != null && !options.isNativeTag!(tag))) {
      return true;
    }
    for (final p in el.props) {
      if (p is AttributeNode) {
        final v = p.value;
        if (p.name == 'is' && v != null && v.content.startsWith('vue:')) {
          return true;
        }
      } else if (p is DirectiveNode) {
        final arg = p.arg;
        if (p.name == 'bind' &&
            arg is SimpleExpression &&
            arg.static_ &&
            arg.content == 'is') {
          // compat-only in official; we do not enable compat
        }
      }
    }
    return false;
  }

  int lookAhead(int index, int c) {
    var i = index;
    while (i < input.length - 1 && input.codeUnitAt(i) != c) {
      i++;
    }
    return i;
  }

  int backTrack(int index, int c) {
    var i = index;
    while (i >= 0 && input.codeUnitAt(i) != c) {
      i--;
    }
    return i;
  }
}

bool isCoreComponent(String tag) {
  switch (tag) {
    case 'Teleport':
    case 'teleport':
    case 'Suspense':
    case 'suspense':
    case 'KeepAlive':
    case 'keep-alive':
    case 'BaseTransition':
    case 'base-transition':
      return true;
  }
  return false;
}

const _specialTemplateDir = {'if', 'else', 'else-if', 'for', 'slot'};

bool isFragmentTemplate(ElementNode el) {
  if (el.tag != 'template') return false;
  for (final p in el.props) {
    if (p is DirectiveNode && _specialTemplateDir.contains(p.name)) {
      return true;
    }
  }
  return false;
}

AttributeNode dirToAttr(DirectiveNode dir) {
  final attr = AttributeNode(
    dir.rawName,
    TmplLoc(
      dir.loc.start.clone(),
      TmplPosition(dir.loc.start.offset + dir.rawName.length, 0, 0),
      '',
    ),
    null,
    dir.loc,
  );
  // nameLoc end position refinement is unused by codegen; offsets matter.
  attr.nameLoc.end = TmplPosition(
      dir.loc.start.offset + dir.rawName.length,
      dir.loc.start.line,
      dir.loc.start.column + dir.rawName.length);
  attr.nameLoc.source = dir.rawName;
  final exp = dir.exp;
  if (exp is SimpleExpression) {
    attr.value = TextNode(exp.content, exp.loc);
  }
  return attr;
}

List<TmplNode> condenseWhitespace(
    List<TmplNode> nodes, String whitespace, int inPre) {
  final condensing = whitespace != 'preserve';
  final removed = List<bool>.filled(nodes.length, false);
  var removedWhitespace = false;
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    if (node.type != ntText) continue;
    final text = node as TextNode;
    if (inPre != 0) {
      text.content = text.content.replaceAll('\r\n', '\n');
      continue;
    }
    if (_allWhitespace(text.content)) {
      final prev = i > 0 ? nodes[i - 1].type : -1;
      final next = i + 1 < nodes.length ? nodes[i + 1].type : -1;
      final removable = prev == -1 ||
          next == -1 ||
          condensing &&
              (prev == ntComment && (next == ntComment || next == ntElement) ||
                  prev == ntElement &&
                      (next == ntComment ||
                          next == ntElement && _hasNewlineChar(text.content)));
      if (removable) {
        removedWhitespace = true;
        removed[i] = true;
      } else {
        text.content = ' ';
      }
    } else if (condensing) {
      text.content = condense(text.content);
    }
  }
  if (!removedWhitespace) return nodes;
  return [
    for (var i = 0; i < nodes.length; i++)
      if (!removed[i]) nodes[i],
  ];
}

bool _allWhitespace(String str) {
  for (var i = 0; i < str.length; i++) {
    if (!isWhitespaceCode(str.codeUnitAt(i))) return false;
  }
  return true;
}

bool _hasNewlineChar(String str) {
  for (var i = 0; i < str.length; i++) {
    final c = str.codeUnitAt(i);
    if (c == 10 || c == 13) return true;
  }
  return false;
}

String condense(String str) {
  final ret = StringBuffer();
  var prevWhitespace = false;
  for (var i = 0; i < str.length; i++) {
    if (isWhitespaceCode(str.codeUnitAt(i))) {
      if (!prevWhitespace) {
        ret.write(' ');
        prevWhitespace = true;
      }
    } else {
      ret.write(str[i]);
      prevWhitespace = false;
    }
  }
  return ret.toString();
}

final _forAliasRE = RegExp(r'([\s\S]*?)\s+(?:in|of)\s+(\S[\s\S]*)');
final _forIteratorRE = RegExp(r',([^,\}\]]*)(?:,([^,\}\]]*))?$');
final _stripParensRE = RegExp(r'^\(|\)$');

ForParseResult? _parseForExpression(SimpleExpression input, _BaseParseState s) {
  final loc = input.loc;
  final exp = input.content;
  final inMatch = _forAliasRE.firstMatch(exp);
  if (inMatch == null) return null;
  final lhs = inMatch.group(1)!;
  final rhs = inMatch.group(2)!;
  SimpleExpression alias(String content, int offset, [bool asParam = false]) {
    final start = loc.start.offset + offset;
    return s.createExp(content, false, s.getLoc(start, start + content.length),
        ctNotConstant, asParam ? 1 : 0);
  }

  final result =
      ForParseResult(alias(rhs.trim(), exp.indexOf(rhs, lhs.length)));
  var valueContent = lhs.trim().replaceAll(_stripParensRE, '').trim();
  final trimmedOffset = lhs.indexOf(valueContent);
  final iteratorMatch = _forIteratorRE.firstMatch(valueContent);
  if (iteratorMatch != null) {
    valueContent = valueContent.replaceAll(_forIteratorRE, '').trim();
    final keyContent = iteratorMatch.group(1)!.trim();
    var keyOffset = -1;
    if (keyContent.isNotEmpty) {
      keyOffset =
          exp.indexOf(keyContent, trimmedOffset + valueContent.length);
      result.key = alias(keyContent, keyOffset, true);
    }
    final indexGroup = iteratorMatch.group(2);
    if (indexGroup != null) {
      final indexContent = indexGroup.trim();
      if (indexContent.isNotEmpty) {
        final from = result.key != null
            ? keyOffset + keyContent.length
            : trimmedOffset + valueContent.length;
        result.index = alias(indexContent, exp.indexOf(indexContent, from), true);
      }
    }
  }
  if (valueContent.isNotEmpty) {
    result.value = alias(valueContent, trimmedOffset, true);
  }
  return result;
}

/// Port of baseParse.
RootNode baseParse(String input, TmplParserOptions options) {
  final s = _BaseParseState()
    ..input = input
    ..options = options;
  s.tokenizer.mode = options.parseMode;
  final root = RootNode([], TmplLoc(TmplPosition(0, 1, 1), TmplPosition(0, 1, 1), ''));
  s.root = root;
  s.tokenizer.parse(input);
  root.loc = s.getLoc(0, input.length);
  root.children = condenseWhitespace(root.children, options.whitespace, s.inPre);  return root;
}
