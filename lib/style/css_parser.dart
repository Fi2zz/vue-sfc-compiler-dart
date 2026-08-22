// Verbatim port of postcss lib/parser.js (source-position tracking omitted;
// positions only feed error messages, not raws or output).
import 'css_ast.dart';
import 'css_tokenize.dart';

class CssParser {
  final String css;
  final CssRoot root = CssRoot();
  late CssContainer current = root;
  String spaces = '';
  bool semicolon = false;
  late CssTokenizer tokenizer;

  CssParser(String source) : css = source {
    tokenizer = CssTokenizer(css);
  }

  CssRoot parse() {
    while (!tokenizer.endOfFile()) {
      final token = tokenizer.nextToken();
      if (token == null) break;
      switch (token.type) {
        case 'space':
          spaces += token.content;
        case ';':
          _freeSemicolon(token);
        case '}':
          _end();
        case 'comment':
          _comment(token);
        case 'at-word':
          _atrule(token);
        case '{':
          _emptyRule(token);
        default:
          _other(token);
      }
    }
    _endFile();
    return root;
  }

  // ------------------------------------------------------------------ atrule

  void _atrule(CssToken startToken) {
    final node = CssAtRule();
    node.name = startToken.content.substring(1);
    if (node.name.isEmpty) {
      throw CssSyntaxError('At-rule without name');
    }
    _init(node);

    var last = false;
    var open = false;
    final params = <CssToken>[];
    final brackets = <String>[];

    while (!tokenizer.endOfFile()) {
      final token = tokenizer.nextToken();
      if (token == null) break;
      final type = token.type;

      if (type == '(' || type == '[') {
        brackets.add(type == '(' ? ')' : ']');
      } else if (type == '{' && brackets.isNotEmpty) {
        brackets.add('}');
      } else if (brackets.isNotEmpty && type == brackets.last) {
        brackets.removeLast();
      }

      if (brackets.isEmpty) {
        if (type == ';') {
          semicolon = true;
          break;
        } else if (type == '{') {
          open = true;
          break;
        } else if (type == '}') {
          _end();
          break;
        } else {
          params.add(token);
        }
      } else {
        params.add(token);
      }

      if (tokenizer.endOfFile()) {
        last = true;
        break;
      }
    }

    node.raws.between = _spacesAndCommentsFromEnd(params);
    if (params.isNotEmpty) {
      node.raws.afterName = _spacesAndCommentsFromStart(params);
      _raw(node, 'params', params);
      if (last) {
        spaces = node.raws.between!;
        node.raws.between = '';
      }
    } else {
      node.raws.afterName = '';
      node.params = '';
    }

    if (open) {
      node.nodes = [];
      current = node;
    } else {
      node.nodes = null; // 无实体的 at-rule（如 @import x;）
    }
  }

  // ------------------------------------------------------------------ decl

  void _decl(List<CssToken> tokens, bool customProperty) {
    final node = CssDecl();
    _init(node);

    var last = tokens[tokens.length - 1];
    if (last.type == ';') {
      semicolon = true;
      tokens.removeLast();
    }

    while (tokens[0].type != 'word') {
      if (tokens.length == 1) {
        throw CssSyntaxError('Unknown word ${tokens[0].content}');
      }
      node.raws.before = (node.raws.before ?? '') + tokens.removeAt(0).content;
    }

    node.prop = '';
    while (tokens.isNotEmpty) {
      final type = tokens[0].type;
      if (type == ':' || type == 'space' || type == 'comment') break;
      node.prop += tokens.removeAt(0).content;
    }

    node.raws.between = '';

    while (tokens.isNotEmpty) {
      final token = tokens.removeAt(0);
      if (token.type == ':') {
        node.raws.between = node.raws.between! + token.content;
        break;
      } else {
        if (token.type == 'word' && RegExp(r'\w').hasMatch(token.content)) {
          throw CssSyntaxError('Unknown word ${token.content}');
        }
        node.raws.between = node.raws.between! + token.content;
      }
    }

    if (node.prop.startsWith('_') || node.prop.startsWith('*')) {
      node.raws.before = (node.raws.before ?? '') + node.prop[0];
      node.prop = node.prop.substring(1);
    }

    final firstSpaces = <CssToken>[];
    while (tokens.isNotEmpty) {
      final next = tokens[0].type;
      if (next != 'space' && next != 'comment') break;
      firstSpaces.add(tokens.removeAt(0));
    }

    _scanImportant(node, tokens);

    final hasWord =
        tokens.any((t) => t.type != 'space' && t.type != 'comment');
    if (hasWord) {
      node.raws.between =
          node.raws.between! + firstSpaces.map((t) => t.content).join();
      firstSpaces.clear();
    }
    _raw(node, 'value', [...firstSpaces, ...tokens], customProperty);

    if (node.value.contains(':') && !customProperty) {
      _checkMissedSemicolon(tokens);
    }
  }

  void _scanImportant(CssDecl node, List<CssToken> tokens) {
    for (var i = tokens.length - 1; i >= 0; i--) {
      final token = tokens[i];
      final lower = token.content.toLowerCase();
      if (lower == '!important') {
        node.important = true;
        var string = _stringFrom(tokens, i);
        string = _spacesFromEnd(tokens) + string;
        if (string != ' !important') node.raws.important = string;
        break;
      } else if (lower == 'important') {
        final cache = List<CssToken>.of(tokens);
        var str = '';
        for (var j = i; j > 0; j--) {
          final type = cache[j].type;
          if (str.trimLeft().startsWith('!') && type != 'space') break;
          str = cache.removeLast().content + str;
        }
        if (str.trimLeft().startsWith('!')) {
          node.important = true;
          node.raws.important = str;
          tokens
            ..clear()
            ..addAll(cache);
        }
      }
      if (token.type != 'space' && token.type != 'comment') break;
    }
  }

  void _checkMissedSemicolon(List<CssToken> tokens) {
    final colon = _colonIndex(tokens);
    if (colon == -1) return;
    var founded = 0;
    CssToken? token;
    for (var j = colon - 1; j >= 0; j--) {
      token = tokens[j];
      if (token.type != 'space') {
        founded += 1;
        if (founded == 2) break;
      }
    }
    throw CssSyntaxError('Missed semicolon');
  }

  int _colonIndex(List<CssToken> tokens) {
    var brackets = 0;
    CssToken? prev;
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final type = token.type;
      if (type == '(') brackets += 1;
      if (type == ')') brackets -= 1;
      if (brackets == 0 && type == ':') {
        if (prev == null) {
          throw CssSyntaxError('Double colon');
        } else if (prev.type == 'word' && prev.content == 'progid') {
          continue;
        } else {
          return i;
        }
      }
      prev = token;
    }
    return -1;
  }

  // ------------------------------------------------------------------ misc

  void _comment(CssToken token) {
    final node = CssComment();
    _init(node);
    final text = token.content.substring(2, token.content.length - 2);
    if (RegExp(r'^\s*$').hasMatch(text)) {
      node.text = '';
      node.raws.left = text;
      node.raws.right = '';
    } else {
      final match = RegExp(r'^(\s*)([^]*\S)(\s*)$').firstMatch(text)!;
      node.text = match[2]!;
      node.raws.left = match[1]!;
      node.raws.right = match[3]!;
    }
  }

  void _emptyRule(CssToken token) {
    final node = CssRule();
    _init(node);
    node.selector = '';
    node.raws.between = '';
    current = node;
  }

  void _end() {
    if (current.nodes != null && current.nodes!.isNotEmpty) {
      current.raws.semicolon = semicolon;
    }
    semicolon = false;
    current.raws.after = (current.raws.after ?? '') + spaces;
    spaces = '';
    if (current.parent != null) {
      current = current.parent!;
    } else {
      throw CssSyntaxError('Unexpected }');
    }
  }

  void _endFile() {
    if (current.parent != null) {
      throw CssSyntaxError('Unclosed block');
    }
    if (current.nodes != null && current.nodes!.isNotEmpty) {
      current.raws.semicolon = semicolon;
    }
    current.raws.after = (current.raws.after ?? '') + spaces;
  }

  void _freeSemicolon(CssToken token) {
    spaces += token.content;
    if (current.nodes != null) {
      final prev = current.nodes!.isEmpty ? null : current.nodes!.last;
      if (prev is CssRule && prev.raws.ownSemicolon == null) {
        prev.raws.ownSemicolon = spaces;
        spaces = '';
      }
    }
  }

  void _init(CssNode node) {
    current.push(node);
    node.raws.before = spaces;
    spaces = '';
    if (node.type != 'comment') semicolon = false;
  }

  // ------------------------------------------------------------- other/rule

  void _other(CssToken start) {
    var end = false;
    var colon = false;
    CssToken? bracket;
    final brackets = <String>[];
    final customProperty = start.content.startsWith('--');

    final tokens = <CssToken>[];
    CssToken? token = start;
    while (token != null) {
      final type = token.type;
      tokens.add(token);

      if (type == '(' || type == '[') {
        bracket ??= token;
        brackets.add(type == '(' ? ')' : ']');
      } else if (customProperty && colon && type == '{') {
        bracket ??= token;
        brackets.add('}');
      } else if (brackets.isEmpty) {
        if (type == ';') {
          if (colon) {
            _decl(tokens, customProperty);
            return;
          } else {
            break;
          }
        } else if (type == '{') {
          _rule(tokens);
          return;
        } else if (type == '}') {
          tokenizer.back(tokens.removeLast());
          end = true;
          break;
        } else if (type == ':') {
          colon = true;
        }
      } else if (brackets.isNotEmpty && type == brackets.last) {
        brackets.removeLast();
        if (brackets.isEmpty) bracket = null;
      }

      token = tokenizer.nextToken();
    }

    if (tokenizer.endOfFile()) end = true;
    if (brackets.isNotEmpty) {
      throw CssSyntaxError('Unclosed bracket');
    }

    if (end && colon) {
      if (!customProperty) {
        while (tokens.isNotEmpty) {
          final type = tokens[tokens.length - 1].type;
          if (type != 'space' && type != 'comment') break;
          tokenizer.back(tokens.removeLast());
        }
      }
      _decl(tokens, customProperty);
    } else {
      throw CssSyntaxError('Unknown word ${tokens.isEmpty ? '' : tokens[0].content}');
    }
  }

  void _rule(List<CssToken> tokens) {
    tokens.removeLast();
    final node = CssRule();
    _init(node);
    node.raws.between = _spacesAndCommentsFromEnd(tokens);
    _raw(node, 'selector', tokens);
    current = node;
  }

  // ---------------------------------------------------------------- helpers

  void _raw(CssNode node, String prop, List<CssToken> tokens,
      [bool customProperty = false]) {
    final length = tokens.length;
    var value = '';
    var clean = true;
    for (var i = 0; i < length; i += 1) {
      final token = tokens[i];
      final type = token.type;
      if (type == 'space' && i == length - 1 && !customProperty) {
        clean = false;
      } else if (type == 'comment') {
        final prev = i > 0 ? tokens[i - 1].type : 'empty';
        final next = i + 1 < length ? tokens[i + 1].type : 'empty';
        final safePrev = prev == 'empty' || prev == 'space';
        final safeNext = next == 'empty' || next == 'space';
        if (!safePrev && !safeNext) {
          if (value.endsWith(',')) {
            clean = false;
          } else {
            value += token.content;
          }
        } else {
          clean = false;
        }
      } else {
        value += token.content;
      }
    }
    if (!clean) {
      final raw = tokens.map((t) => t.content).join();
      node.raws.values[prop] = CssRawValue(raw, value);
    }
    _setNodeProp(node, prop, value);
  }

  void _setNodeProp(CssNode node, String prop, String value) {
    switch (node) {
      case CssRule n:
        if (prop == 'selector') n.selector = value;
      case CssAtRule n:
        if (prop == 'params') n.params = value;
      case CssDecl n:
        if (prop == 'value') n.value = value;
      default:
        break;
    }
  }

  String _spacesAndCommentsFromEnd(List<CssToken> tokens) {
    var spaces = '';
    while (tokens.isNotEmpty) {
      final lastTokenType = tokens[tokens.length - 1].type;
      if (lastTokenType != 'space' && lastTokenType != 'comment') break;
      spaces = tokens.removeLast().content + spaces;
    }
    return spaces;
  }

  String _spacesAndCommentsFromStart(List<CssToken> tokens) {
    var spaces = '';
    while (tokens.isNotEmpty) {
      final next = tokens[0].type;
      if (next != 'space' && next != 'comment') break;
      spaces += tokens.removeAt(0).content;
    }
    return spaces;
  }

  String _spacesFromEnd(List<CssToken> tokens) {
    var spaces = '';
    while (tokens.isNotEmpty) {
      final lastTokenType = tokens[tokens.length - 1].type;
      if (lastTokenType != 'space') break;
      spaces = tokens.removeLast().content + spaces;
    }
    return spaces;
  }

  String _stringFrom(List<CssToken> tokens, int from) {
    var result = '';
    for (var i = from; i < tokens.length; i++) {
      result += tokens[i].content;
    }
    tokens.removeRange(from, tokens.length);
    return result;
  }
}

/// postcss parse(): source -> Root.
CssRoot parseCss(String source) => CssParser(source).parse();
