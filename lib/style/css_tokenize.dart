// Verbatim port of postcss lib/tokenize.js.
// Token: [type, content, startOffset, endOffset?] modeled as a list.
class CssToken {
  final String type;
  final String content;
  final int start; // token[2]
  final int? end; // token[3]
  CssToken(this.type, this.content, this.start, [this.end]);
}

const _atEndChars = '\t\n\f\r "#\'()/;[\\]{}';
const _wordEndChars = '\t\n\f\r !"\'():;@[\\]{}';

bool _isAtEndChar(String c) => _atEndChars.contains(c);

bool _isWordEndChar(String c) => _wordEndChars.contains(c);

int _indexOfAtEnd(String css, int from) {
  for (var i = from; i < css.length; i++) {
    if (_isAtEndChar(css[i])) return i;
  }
  return -1;
}

/// RE_WORD_END = /[\t\n\f\r !"#'():;@[\\\]{}]|\/(?=\*)/g
int _indexOfWordEnd(String css, int from) {
  for (var i = from; i < css.length; i++) {
    final c = css[i];
    if (_isWordEndChar(c)) return i;
    if (c == '/' && i + 1 < css.length && css[i + 1] == '*') return i;
  }
  return -1;
}

class CssSyntaxError implements Exception {
  final String reason;
  final int offset;
  final int? endOffset;
  CssSyntaxError(this.reason, this.offset, [this.endOffset]);
  @override
  String toString() => reason;
}

class CssTokenizer {
  final String css;
  int pos = 0;
  final List<CssToken> _returned = [];
  final List<CssToken> _buffer = [];

  CssTokenizer(this.css);

  int position() => pos;

  bool endOfFile() => _returned.isEmpty && pos >= css.length;

  void back(CssToken token) => _returned.add(token);

  Never _unclosed(String what) =>
      throw CssSyntaxError('Unclosed $what', pos);

  CssToken? nextToken({bool ignoreUnclosed = false}) {
    if (_returned.isNotEmpty) return _returned.removeLast();
    if (pos >= css.length) return null;
    final code = css.codeUnitAt(pos);
    CssToken token;
    if (_isWhitespaceCode(code)) {
      token = _readSpace();
    } else {
      token = _readNonSpace(code, ignoreUnclosed);
    }
    pos++;
    return token;
  }

  bool _isWhitespaceCode(int code) =>
      code == 0x0A || code == 0x20 || code == 0x09 || code == 0x0D || code == 0x0C;

  CssToken _readSpace() {
    var next = pos;
    int code;
    do {
      next += 1;
      code = next < css.length ? css.codeUnitAt(next) : -1;
    } while (_isWhitespaceCode(code));
    final token = CssToken('space', css.substring(pos, next), pos);
    pos = next - 1;
    return token;
  }

  CssToken _readNonSpace(int code, bool ignoreUnclosed) {
    switch (code) {
      case 0x5B: // [
      case 0x5D: // ]
      case 0x7B: // {
      case 0x7D: // }
      case 0x3A: // :
      case 0x3B: // ;
      case 0x29: // )
        final c = String.fromCharCode(code);
        return CssToken(c, c, pos);
      case 0x28: // (
        return _readOpenParen(ignoreUnclosed);
      case 0x27: // '
      case 0x22: // "
        return _readString(code, ignoreUnclosed);
      case 0x40: // @
        return _readAtWord();
      case 0x5C: // backslash
        return _readEscape();
      default:
        return _readWordOrComment(code, ignoreUnclosed);
    }
  }

  CssToken _readOpenParen(bool ignoreUnclosed) {
    final prev = _buffer.isEmpty ? '' : _buffer.removeLast().content;
    final n = pos + 1 < css.length ? css.codeUnitAt(pos + 1) : -1;
    final opensUrl = prev == 'url' &&
        n != 0x27 &&
        n != 0x22 &&
        !_isWhitespaceCode(n) &&
        n != -1;
    if (opensUrl) return _readUrlBrackets(ignoreUnclosed);
    final next = css.indexOf(')', pos + 1);
    final content = next == -1 ? '' : css.substring(pos, next + 1);
    if (next == -1 || _badBracket(content)) {
      return CssToken('(', '(', pos);
    }
    final token = CssToken('brackets', content, pos, next);
    pos = next;
    return token;
  }

  // RE_BAD_BRACKET = /.[\r\n"'(/\\]/
  bool _badBracket(String content) {
    if (content.length < 2) return false;
    return RegExp(r'[\r\n"\x27(/\\]').hasMatch(content.substring(1));
  }

  CssToken _readUrlBrackets(bool ignoreUnclosed) {
    var next = pos;
    var escaped = false;
    while (true) {
      escaped = false;
      next = css.indexOf(')', next + 1);
      if (next == -1) {
        if (ignoreUnclosed) {
          next = pos;
          break;
        }
        _unclosed('bracket');
      }
      var escapePos = next;
      while (css.codeUnitAt(escapePos - 1) == 0x5C) {
        escapePos -= 1;
        escaped = !escaped;
      }
      if (!escaped) break;
    }
    final token = CssToken('brackets', css.substring(pos, next + 1), pos, next);
    pos = next;
    return token;
  }

  CssToken _readString(int quoteCode, bool ignoreUnclosed) {
    final quote = String.fromCharCode(quoteCode);
    var next = pos;
    var escaped = false;
    while (true) {
      escaped = false;
      next = css.indexOf(quote, next + 1);
      if (next == -1) {
        if (ignoreUnclosed) {
          next = pos + 1;
          break;
        }
        _unclosed('string');
      }
      var escapePos = next;
      while (css.codeUnitAt(escapePos - 1) == 0x5C) {
        escapePos -= 1;
        escaped = !escaped;
      }
      if (!escaped) break;
    }
    final token = CssToken('string', css.substring(pos, next + 1), pos, next);
    pos = next;
    return token;
  }

  CssToken _readAtWord() {
    final hit = _indexOfAtEnd(css, pos + 1);
    final next = hit == -1 ? css.length - 1 : hit - 1;
    final token = CssToken('at-word', css.substring(pos, next + 1), pos, next);
    pos = next;
    return token;
  }

  CssToken _readEscape() {
    var next = pos;
    var escape = true;
    while (next + 1 < css.length && css.codeUnitAt(next + 1) == 0x5C) {
      next += 1;
      escape = !escape;
    }
    final code = next + 1 < css.length ? css.codeUnitAt(next + 1) : -1;
    final escapable = code != 0x2F && !_isWhitespaceCode(code) && code != -1;
    if (escape && escapable) {
      next += 1;
      if (_isHexChar(css[next])) {
        while (next + 1 < css.length && _isHexChar(css[next + 1])) {
          next += 1;
        }
        if (next + 1 < css.length && css.codeUnitAt(next + 1) == 0x20) {
          next += 1;
        }
      }
    }
    final token = CssToken('word', css.substring(pos, next + 1), pos, next);
    pos = next;
    return token;
  }

  bool _isHexChar(String c) => RegExp(r'[\da-fA-F]').hasMatch(c);

  CssToken _readWordOrComment(int code, bool ignoreUnclosed) {
    if (code == 0x2F && pos + 1 < css.length && css.codeUnitAt(pos + 1) == 0x2A) {
      return _readComment(ignoreUnclosed);
    }
    final hit = _indexOfWordEnd(css, pos + 1);
    final next = hit == -1 ? css.length - 1 : hit - 1;
    final token = CssToken('word', css.substring(pos, next + 1), pos, next);
    _buffer.add(token);
    pos = next;
    return token;
  }

  CssToken _readComment(bool ignoreUnclosed) {
    var next = css.indexOf('*/', pos + 2) + 1;
    if (next == 0) {
      if (ignoreUnclosed) {
        next = css.length;
      } else {
        _unclosed('comment');
      }
    }
    final token = CssToken('comment', css.substring(pos, next + 1), pos, next);
    pos = next;
    return token;
  }
}
