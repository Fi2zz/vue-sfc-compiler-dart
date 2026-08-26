// Port of postcss-selector-parser Parser (lossless mode only, which is what
// processor.processSync uses by default). Source positions are omitted.
import 'selector_ast.dart';
import 'selector_tokenize.dart';

part 'selector_parser_attribute.dart';

const _whitespaceTokens = {tkSpace, tkCr, tkFeed, tkNewline, tkTab};
const _whitespaceEquivTokens = {
  tkSpace,
  tkCr,
  tkFeed,
  tkNewline,
  tkTab,
  tkComment,
};

/// Mirrors selectorParser(func).processSync(css): parse, run [transform] on
/// the root, return the stringified selector.
String transformSelector(String css, void Function(SelRoot root) transform) {
  final parser = SelParser(css);
  transform(parser.root);
  return parser.root.stringify();
}

final class SelParser {
  final String css;
  late final List<SelTok> tokens = tokenizeSelector(css);
  int position = 0;
  final SelRoot root = SelRoot();
  late SelContainer current;
  String spaces = '';

  SelParser(this.css) {
    final selector = SelSelector();
    root.append(selector);
    current = selector;
    _loop();
  }

  SelTok get currToken => tokens[position];
  SelTok? get nextToken =>
      position + 1 < tokens.length ? tokens[position + 1] : null;
  SelTok? get prevToken => position - 1 >= 0 ? tokens[position - 1] : null;

  String content([SelTok? token]) {
    final t = token ?? currToken;
    return css.substring(t.start, t.end);
  }

  void _loop() {
    while (position < tokens.length) {
      _parse(true);
    }
  }

  void _parse(bool throwOnParenthesis) {
    switch (currToken.type) {
      case tkSpace:
        _space();
      case tkComment:
        _comment();
      case tkOpenParenthesis:
        _parentheses();
      case tkCloseParenthesis:
        if (throwOnParenthesis) {
          throw SelSyntaxError('Expected an opening parenthesis.');
        }
      case tkOpenSquare:
        _attribute();
      case tkDollar || tkCaret || tkEquals || tkWord:
        _word();
      case tkColon:
        _pseudo();
      case tkComma:
        _comma();
      case tkAsterisk:
        _universal();
      case tkAmpersand:
        _nesting();
      case tkSlash || tkCombinator:
        _combinator();
      case tkStr:
        _string();
      case tkCloseSquare:
        throw SelSyntaxError('Expected an opening square bracket.');
      case tkSemicolon:
        throw SelSyntaxError('Expected a backslash preceding the semicolon.');
      default:
        throw SelSyntaxError(
          "Unexpected '${content()}'. Escaping special characters with \\ may help.",
        );
    }
  }

  // ------------------------------------------------------------ small nodes

  void _comment() {
    newNode(SelComment(value: content()));
    position++;
  }

  void _string() {
    newNode(SelStringNode(value: content()));
    position++;
  }

  void _nesting() {
    final next = nextToken;
    if (next != null && content(next) == '|') {
      position++;
      return;
    }
    newNode(SelNesting(value: content()));
    position++;
  }

  void _universal([Object? namespace]) {
    final next = nextToken;
    if (next != null && content(next) == '|') {
      position++;
      return _namespace();
    }
    newNode(SelUniversal(value: content()), namespace);
    position++;
  }

  void _word([Object? namespace]) {
    final next = nextToken;
    if (next != null && content(next) == '|') {
      position++;
      return _namespace();
    }
    _splitWord(namespace, null);
  }

  void _namespace() {
    final Object before = prevToken != null ? content(prevToken!) : true;
    final next = nextToken;
    if (next != null && next.type == tkWord) {
      position++;
      return _word(before);
    }
    if (next != null && next.type == tkAsterisk) {
      position++;
      return _universal(before);
    }
    throw SelSyntaxError("Unexpected '|'.");
  }

  void _pseudo() {
    var pseudoStr = '';
    while (position < tokens.length && currToken.type == tkColon) {
      pseudoStr += content();
      position++;
    }
    if (position >= tokens.length || currToken.type != tkWord) {
      throw SelSyntaxError('Expected a pseudo-class or pseudo-element.');
    }
    _splitWord(false, (first, length) {
      pseudoStr += first;
      newNode(SelPseudo(value: pseudoStr));
      final next = nextToken;
      if (length > 1 && next != null && next.type == tkOpenParenthesis) {
        throw SelSyntaxError('Misplaced parenthesis.');
      }
    });
  }

  // ------------------------------------------------------------ combinators

  void _space() {
    final c = content();
    final prev = prevToken;
    final next = nextToken;
    final onlyComments = current.nodes.every((n) => n.type == 'comment');
    if (position == 0 ||
        (prev != null &&
            (prev.type == tkComma || prev.type == tkOpenParenthesis)) ||
        onlyComments) {
      spaces = c;
      position++;
    } else if (position == tokens.length - 1 ||
        (next != null &&
            (next.type == tkComma || next.type == tkCloseParenthesis))) {
      current.last?.spaces.after = c;
      position++;
    } else {
      _combinator();
    }
  }

  void _comma() {
    if (position == tokens.length - 1) {
      root.trailingComma = true;
      position++;
      return;
    }
    final selector = SelSelector();
    current.parent!.append(selector);
    current = selector;
    position++;
  }

  void _combinator() {
    if (content() == '|') return _namespace();
    final nextSig = _locateNextMeaningfulToken(position);
    if (nextSig < 0 ||
        tokens[nextSig].type == tkComma ||
        tokens[nextSig].type == tkCloseParenthesis) {
      _trailingCombinator(nextSig);
      return;
    }
    final spaceNodes = nextSig > position
        ? _parseWhitespaceEquivalentTokens(nextSig)
        : null;
    final node = _combinatorNode(spaceNodes);
    if (position < tokens.length && currToken.type == tkSpace) {
      node.spaces.after = content();
      position++;
    }
    newNode(node);
  }

  void _trailingCombinator(int nextSig) {
    final nodes = _parseWhitespaceEquivalentTokens(nextSig);
    if (nodes.isEmpty) return;
    final last = current.last;
    if (last != null) {
      final conv = _convertWhitespaceNodesToSpace(nodes);
      if (conv.rawSpace != null) last.rawSpaceAfter += conv.rawSpace!;
      last.spaces.after += conv.space;
    } else {
      for (final n in nodes) {
        newNode(n);
      }
    }
  }

  SelNode _combinatorNode(List<SelNode>? spaceNodes) {
    SelNode? node;
    if (_isNamedCombinator()) {
      node = _namedCombinator();
    } else if (currToken.type == tkCombinator) {
      node = SelCombinator(value: content());
      position++;
    } else if (_whitespaceTokens.contains(currToken.type)) {
      node = null;
    } else if (spaceNodes == null) {
      throw SelSyntaxError(
        "Unexpected '${content()}'. Escaping special characters with \\ may help.",
      );
    }
    if (node != null) {
      if (spaceNodes != null) _applySpaceBefore(node, spaceNodes);
      return node;
    }
    return _descendantCombinator(spaceNodes!);
  }

  void _applySpaceBefore(SelNode node, List<SelNode> spaceNodes) {
    final conv = _convertWhitespaceNodesToSpace(spaceNodes);
    node.spaces.before = conv.space;
    if (conv.rawSpace != null) node.rawSpaceBefore = conv.rawSpace!;
  }

  SelNode _descendantCombinator(List<SelNode> spaceNodes) {
    final conv = _convertWhitespaceNodesToSpace(spaceNodes, true);
    final space2 = conv.space;
    final rawSpace2 = conv.rawSpace ?? conv.space;
    final node = SelCombinator(value: ' ');
    if (space2.endsWith(' ') && rawSpace2.endsWith(' ')) {
      node.spaces.before = space2.substring(0, space2.length - 1);
      node.ensureRaws().spaces['before'] = rawSpace2.substring(
        0,
        rawSpace2.length - 1,
      );
    } else if (space2.startsWith(' ') && rawSpace2.startsWith(' ')) {
      node.spaces.after = space2.substring(1);
      node.ensureRaws().spaces['after'] = rawSpace2.substring(1);
    } else {
      node.ensureRaws().value = rawSpace2;
    }
    return node;
  }

  bool _isNamedCombinator([int? pos]) {
    final p = pos ?? position;
    return p < tokens.length &&
        tokens[p].type == tkSlash &&
        p + 1 < tokens.length &&
        tokens[p + 1].type == tkWord &&
        p + 2 < tokens.length &&
        tokens[p + 2].type == tkSlash;
  }

  SelNode _namedCombinator() {
    final nameRaw = content(tokens[position + 1]);
    final name = unescSel(nameRaw).toLowerCase();
    final node = SelCombinator(value: '/$name/');
    if (name != nameRaw) node.ensureRaws().value = '/$nameRaw/';
    position = position + 3;
    return node;
  }

  // ------------------------------------------------------------ parentheses

  void _parentheses() {
    final last = current.last;
    var unbalanced = 1;
    position++;
    if (last != null && last.type == 'pseudo') {
      unbalanced = _pseudoParens(last as SelPseudo, unbalanced);
    } else {
      unbalanced = _rawParens(last, unbalanced);
    }
    if (unbalanced != 0) {
      throw SelSyntaxError('Expected a closing parenthesis.');
    }
  }

  int _pseudoParens(SelPseudo last, int unbalanced) {
    final selector = SelSelector();
    final cache = current;
    last.append(selector);
    current = selector;
    while (position < tokens.length && unbalanced != 0) {
      if (currToken.type == tkOpenParenthesis) unbalanced++;
      if (currToken.type == tkCloseParenthesis) unbalanced--;
      if (unbalanced != 0) {
        _parse(false);
      } else {
        position++;
      }
    }
    current = cache;
    return unbalanced;
  }

  int _rawParens(SelNode? last, int unbalanced) {
    var parenValue = '(';
    while (position < tokens.length && unbalanced != 0) {
      if (currToken.type == tkOpenParenthesis) unbalanced++;
      if (currToken.type == tkCloseParenthesis) unbalanced--;
      parenValue += content();
      position++;
    }
    if (last != null) {
      last.appendValueAndEscape(parenValue);
    } else {
      newNode(SelStringNode(value: parenValue));
    }
    return unbalanced;
  }

  // -------------------------------------------------------------- splitWord

  void _splitWord(
    Object? namespace,
    void Function(String first, int length)? onFirst,
  ) {
    var word = _mergedWord();
    final hasClass = _splitIndices(word, '.');
    var hasId = _splitIndices(word, '#');
    final interpolations = _indexesOfStr(word, '#{');
    if (interpolations.isNotEmpty) {
      hasId = hasId.where((i) => !interpolations.contains(i)).toList();
    }
    final indices = {
      ...{0},
      ...hasClass,
      ...hasId,
    }.toList()..sort();
    var ns = namespace;
    for (var i = 0; i < indices.length; i++) {
      final start = indices[i];
      final end = i + 1 < indices.length ? indices[i + 1] : word.length;
      final value = word.substring(start, end);
      if (i == 0 && onFirst != null) {
        onFirst(value, indices.length);
      } else {
        newNode(_wordNode(value, hasClass, hasId, start), ns);
        ns = null;
      }
    }
    position++;
  }

  String _mergedWord() {
    var word = content();
    var next = nextToken;
    while (next != null &&
        const [tkDollar, tkCaret, tkEquals, tkWord].contains(next.type)) {
      position++;
      final c = content();
      word += c;
      if (c.endsWith('\\')) {
        final nt = nextToken;
        if (nt != null && nt.type == tkSpace) {
          word += content(nt);
          position++;
        }
      }
      next = nextToken;
    }
    return word;
  }

  List<int> _splitIndices(String word, String ch) {
    final result = <int>[];
    for (var i = 0; i < word.length; i++) {
      if (word[i] != ch) continue;
      final escaped = i > 0 && word[i - 1] == '\\';
      final keyframesPct = ch == '.' && RegExp(r'^\d+\.\d+%$').hasMatch(word);
      if (!escaped && !keyframesPct) result.add(i);
    }
    return result;
  }

  List<int> _indexesOfStr(String word, String sub) {
    final result = <int>[];
    var i = -1;
    while ((i = word.indexOf(sub, i + 1)) != -1) {
      result.add(i);
    }
    return result;
  }

  SelNode _wordNode(String value, List<int> hasClass, List<int> hasId, int i) {
    if (hasClass.contains(i)) return _unescapedNode(SelClassName(), value, 1);
    if (hasId.contains(i)) return _unescapedNode(SelId(), value, 1);
    return _unescapedNode(SelTag(), value, 0);
  }

  SelNode _unescapedNode(SelNode node, String raw, int strip) {
    final v = raw.substring(strip);
    if (v.contains('\\')) {
      node.value = unescSel(v);
      node.ensureRaws().value = v;
    } else {
      node.value = v;
    }
    return node;
  }

  // ---------------------------------------------------------------- helpers

  void newNode(SelNode node, [Object? namespace]) {
    var ns = namespace;
    if (ns != null) {
      if (ns is String && RegExp(r'^ +$').hasMatch(ns)) {
        spaces = spaces + ns;
        ns = true;
      }
      if (node is SelNamespaceNode) {
        node.namespace = ns;
        _unescapeNamespace(node);
      }
    }
    if (spaces.isNotEmpty) {
      node.spaces.before = spaces;
      spaces = '';
    }
    current.append(node);
  }

  void _unescapeNamespace(SelNamespaceNode node) {
    final ns = node.namespace;
    if (ns is String && ns.contains('\\')) {
      node.ensureRaws().namespace = ns;
      node.namespace = unescSel(ns);
    }
  }

  int _locateNextMeaningfulToken([int? startPosition]) {
    var i = startPosition ?? position + 1;
    while (i < tokens.length) {
      if (_whitespaceEquivTokens.contains(tokens[i].type)) {
        i++;
        continue;
      }
      return i;
    }
    return -1;
  }

  List<SelNode> _parseWhitespaceEquivalentTokens(int stopPosition) {
    if (stopPosition < 0) stopPosition = tokens.length;
    final nodes = <SelNode>[];
    var space = '';
    SelComment? lastComment;
    do {
      if (_whitespaceTokens.contains(currToken.type)) {
        space += content();
      } else if (currToken.type == tkComment) {
        final c = SelComment(value: content());
        if (space.isNotEmpty) {
          c.spaces.before = space;
          space = '';
        }
        lastComment = c;
        nodes.add(c);
      }
      position++;
    } while (position < stopPosition);
    if (space.isNotEmpty) {
      if (lastComment != null) {
        lastComment.spaces.after = space;
      } else {
        nodes.add(SelStringNode(value: '')..spaces.before = space);
      }
    }
    return nodes;
  }

  ({String space, String? rawSpace}) _convertWhitespaceNodesToSpace(
    List<SelNode> nodes, [
    bool requiredSpace = false,
  ]) {
    var space = '';
    var rawSpace = '';
    for (final n in nodes) {
      space += n.spaces.before + n.spaces.after;
      rawSpace += n.spaces.before + n.value + n.rawSpaceAfter;
    }
    return (space: space, rawSpace: rawSpace == space ? null : rawSpace);
  }
}

/// unesc: CSS backslash unescape with hex sequence support.
String unescSel(String str) {
  if (!str.contains('\\')) return str;
  final ret = StringBuffer();
  var i = 0;
  while (i < str.length) {
    if (str[i] == '\\') {
      final gobbled = _gobbleHex(str, i + 1);
      if (gobbled != null) {
        ret.write(gobbled.$1);
        i += gobbled.$2 + 1;
        continue;
      }
      if (i + 1 < str.length && str[i + 1] == '\\') {
        ret.write('\\');
        i += 2;
        continue;
      }
      if (str.length == i + 1) ret.write(str[i]);
      i++;
      continue;
    }
    ret.write(str[i]);
    i++;
  }
  return ret.toString();
}

(String, int)? _gobbleHex(String str, int start) {
  final hex = StringBuffer();
  var spaceTerminated = false;
  for (var i = 0; i < 6; i++) {
    final p = start + i;
    if (p >= str.length) break;
    final code = str.codeUnitAt(p);
    final valid = (code >= 97 && code <= 102) || (code >= 48 && code <= 57);
    if (!valid) {
      spaceTerminated = code == 32;
      break;
    }
    hex.write(str[p].toLowerCase());
  }
  if (hex.isEmpty) return null;
  final codePoint = int.parse(hex.toString(), radix: 16);
  final consumed = hex.length + (spaceTerminated ? 1 : 0);
  final surrogate = codePoint >= 0xD800 && codePoint <= 0xDFFF;
  if (surrogate || codePoint == 0 || codePoint > 0x10FFFF) {
    return ('', consumed);
  }
  return (String.fromCharCode(codePoint), consumed);
}
