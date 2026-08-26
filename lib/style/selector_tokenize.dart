// Port of postcss-selector-parser tokenizer (dist tokenize.js).
// Only token type + [start, end) offsets are kept; line/column tracking is
// omitted because it never affects parsing decisions or stringified output.

// Token types mirror token-types.js: single-char tokens use their char code;
// multi-char kinds use negative ids.
const int tkAmpersand = 38;
const int tkAsterisk = 42;
const int tkAt = 64;
const int tkComma = 44;
const int tkColon = 58;
const int tkSemicolon = 59;
const int tkOpenParenthesis = 40;
const int tkCloseParenthesis = 41;
const int tkOpenSquare = 91;
const int tkCloseSquare = 93;
const int tkDollar = 36;
const int tkTilde = 126;
const int tkCaret = 94;
const int tkPlus = 43;
const int tkEquals = 61;
const int tkPipe = 124;
const int tkGreaterThan = 62;
const int tkSpace = 32;
const int tkSingleQuote = 39;
const int tkDoubleQuote = 34;
const int tkSlash = 47;
const int tkBang = 33;
const int tkBackslash = 92;
const int tkCr = 13;
const int tkFeed = 12;
const int tkNewline = 10;
const int tkTab = 9;
const int tkStr = tkSingleQuote;
const int tkComment = -1;
const int tkWord = -2;
const int tkCombinator = -3;

const _unescapable = {tkTab, tkNewline, tkCr, tkFeed};

const _wordDelimiters = {
  tkSpace,
  tkTab,
  tkNewline,
  tkCr,
  tkFeed,
  tkAmpersand,
  tkAsterisk,
  tkBang,
  tkComma,
  tkColon,
  tkSemicolon,
  tkOpenParenthesis,
  tkCloseParenthesis,
  tkOpenSquare,
  tkCloseSquare,
  tkSingleQuote,
  tkDoubleQuote,
  tkPlus,
  tkPipe,
  tkTilde,
  tkGreaterThan,
  tkEquals,
  tkDollar,
  tkCaret,
  tkSlash,
};

final Set<int> _hex = '0123456789abcdefABCDEF'.codeUnits.toSet();

/// Selector token: [start, end) code-unit offsets into the source string.
final class SelTok {
  final int type;
  final int start;
  final int end;
  const SelTok(this.type, this.start, this.end);
}

final class SelSyntaxError implements Exception {
  final String message;
  SelSyntaxError(this.message);
  @override
  String toString() => 'Error: $message';
}

int _codeAt(String css, int i) => i < css.length ? css.codeUnitAt(i) : -1;

/// Last index of the escape sequence starting at the `\` in [start].
int _consumeEscape(String css, int start) {
  var next = start;
  var code = _codeAt(css, next + 1);
  if (_unescapable.contains(code)) {
    return next;
  }
  if (_hex.contains(code)) {
    var hexDigits = 0;
    do {
      next++;
      hexDigits++;
      code = _codeAt(css, next + 1);
    } while (_hex.contains(code) && hexDigits < 6);
    if (hexDigits < 6 && code == tkSpace) next++;
  } else {
    next++;
  }
  return next;
}

/// Last index of the word beginning at [start].
int _consumeWord(String css, int start) {
  var next = start;
  while (true) {
    final code = _codeAt(css, next);
    if (_wordDelimiters.contains(code)) return next - 1;
    if (code == tkBackslash) {
      next = _consumeEscape(css, next) + 1;
    } else {
      next++;
    }
    if (next >= css.length) break;
  }
  return next - 1;
}

List<SelTok> tokenizeSelector(String css) {
  final tokens = <SelTok>[];
  final length = css.length;
  var start = 0;
  while (start < length) {
    final code = css.codeUnitAt(start);
    int type;
    int end;
    switch (code) {
      case tkSpace || tkTab || tkNewline || tkCr || tkFeed:
        var next = start;
        int c;
        do {
          next += 1;
          c = _codeAt(css, next);
        } while (c == tkSpace ||
            c == tkNewline ||
            c == tkTab ||
            c == tkCr ||
            c == tkFeed);
        type = tkSpace;
        end = next;
      case tkPlus || tkGreaterThan || tkTilde || tkPipe:
        var next = start;
        int c;
        do {
          next += 1;
          c = _codeAt(css, next);
        } while (c == tkPlus ||
            c == tkGreaterThan ||
            c == tkTilde ||
            c == tkPipe);
        type = tkCombinator;
        end = next;
      case tkAsterisk ||
          tkAmpersand ||
          tkBang ||
          tkComma ||
          tkEquals ||
          tkDollar ||
          tkCaret ||
          tkOpenSquare ||
          tkCloseSquare ||
          tkColon ||
          tkSemicolon ||
          tkOpenParenthesis ||
          tkCloseParenthesis:
        type = code;
        end = start + 1;
      case tkSingleQuote || tkDoubleQuote:
        final quote = code == tkSingleQuote ? "'" : '"';
        var next = start;
        bool escaped;
        while (true) {
          escaped = false;
          next = css.indexOf(quote, next + 1);
          if (next == -1) throw SelSyntaxError('Unclosed quote');
          var escapePos = next;
          while (_codeAt(css, escapePos - 1) == tkBackslash) {
            escapePos -= 1;
            escaped = !escaped;
          }
          if (!escaped) break;
        }
        type = tkStr;
        end = next + 1;
      default:
        if (code == tkSlash && _codeAt(css, start + 1) == tkAsterisk) {
          var next = css.indexOf('*/', start + 2) + 1;
          if (next == 0) throw SelSyntaxError('Unclosed comment');
          type = tkComment;
          end = next + 1;
        } else if (code == tkSlash) {
          type = tkSlash;
          end = start + 1;
        } else {
          final next = _consumeWord(css, start);
          type = tkWord;
          end = next + 1;
        }
    }
    tokens.add(SelTok(type, start, end));
    start = end;
  }
  return tokens;
}
