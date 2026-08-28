// Constant-expression evaluator backing evaluateConstant: replaces the
// official `new Function('return (' + content + ')')()` with a tree-sitter
// AST walk implementing JS literal/operator semantics.
import 'dart:math' as math;

import '../../ts_parser.dart';

import '../../script/src_view.dart';
import '../stringify_utils.dart';

/// Evaluate a JS constant expression source (already known constType >=
/// CAN_STRINGIFY). Throws StateError on constructs outside the supported
/// constant subset.
final class _ConstEvalImpl {
  final SrcView view;

  _ConstEvalImpl(String source) : view = SrcView(source);

  Object? run() {
    final root = TSParser().parse(code: view.content, language: 'ts');
    return _eval(_unwrap(root));
  }

  AstNode _unwrap(AstNode node) {
    const wrappers = {
      'program',
      'expression_statement',
      'parenthesized_expression',
      'as_expression',
      'satisfies_expression',
      'non_null_expression',
    };
    var cur = node;
    while (wrappers.contains(cur.type) && cur.children.isNotEmpty) {
      cur = cur.children.first;
    }
    return cur;
  }

  Object? _eval(AstNode node) => switch (node.type) {
    'number' => parseJsNumber(view.textOf(node)),
    'string' => parseJsString(view.textOf(node)),
    'true' => true,
    'false' => false,
    'null' => null,
    'identifier' => _evalIdentifier(view.textOf(node)),
    'template_string' => _evalTemplate(node),
    'unary_expression' => _evalUnary(node),
    'binary_expression' => _evalBinary(node),
    'ternary_expression' => _evalTernary(node),
    'parenthesized_expression' => _eval(node.children.first),
    'array' => _evalArray(node),
    'object' => _evalObject(node),
    'sequence_expression' => _eval(node.children.last),
    _ => throw StateError('constEval: unsupported node ${node.type}'),
  };

  Object? _evalIdentifier(String name) => switch (name) {
    'undefined' => jsUndefined,
    'NaN' => double.nan,
    'Infinity' => double.infinity,
    _ => throw StateError('constEval: free identifier $name'),
  };

  Object? _evalUnary(AstNode node) {
    final arg = node.children.last;
    final op = view.content
        .substring(view.charOf(node.startByte), view.charOf(arg.startByte))
        .trim();
    final v = _eval(arg);
    return switch (op) {
      '-' => -jsToNum(v),
      '+' => jsToNum(v),
      '!' => !jsTruthy(v),
      '~' => ~jsToInt32(v),
      'void' => jsUndefined,
      'typeof' => jsTypeof(v),
      _ => throw StateError('constEval: unsupported unary $op'),
    };
  }

  Object? _evalBinary(AstNode node) {
    final left = node.children[0];
    final right = node.children[1];
    final op = view.content
        .substring(view.charOf(left.endByte), view.charOf(right.startByte))
        .trim();
    final l = _eval(left);
    if (op == '&&') return jsTruthy(l) ? _eval(right) : l;
    if (op == '||') return jsTruthy(l) ? l : _eval(right);
    if (op == '??') return (l == null || l is JsUndefined) ? _eval(right) : l;
    return applyJsBinary(op, l, _eval(right));
  }

  Object? _evalTernary(AstNode node) {
    return jsTruthy(_eval(node.children[0]))
        ? _eval(node.children[1])
        : _eval(node.children[2]);
  }

  Object? _evalArray(AstNode node) {
    final res = <Object?>[];
    for (final c in node.children) {
      if (c.type == 'spread_element') {
        final v = _eval(c.children.first);
        if (v is! List) {
          throw StateError('constEval: spread of non-array');
        }
        res.addAll(v);
      } else {
        res.add(_eval(c));
      }
    }
    return res;
  }

  Object? _evalObject(AstNode node) {
    final res = <String, Object?>{};
    for (final c in node.children) {
      if (c.type != 'pair') {
        throw StateError('constEval: unsupported object member ${c.type}');
      }
      res[_objectKey(c.children[0])] = _eval(c.children[1]);
    }
    return res;
  }

  String _objectKey(AstNode key) => switch (key.type) {
    'property_identifier' => view.textOf(key),
    'string' => parseJsString(view.textOf(key)),
    'number' => jsNumToString(parseJsNumber(view.textOf(key))),
    _ => throw StateError('constEval: unsupported key ${key.type}'),
  };

  Object? _evalTemplate(AstNode node) {
    for (final c in node.children) {
      if (c.type == 'template_substitution') {
        throw StateError('constEval: template substitution unsupported');
      }
    }
    final text = view.textOf(node);
    return unescapeJsString(text.substring(1, text.length - 1));
  }
}

/// Entry point mirroring `new Function('return (' + content + ')')()`.
Object? evalConstantSource(String content) =>
    _ConstEvalImpl('($content)').run();

// --- JS value semantics (view-independent) ---------------------------------

num jsToNum(Object? v) {
  if (v is num) return v;
  if (v is bool) return v ? 1 : 0;
  if (v == null) return 0;
  if (v is String) return _strToNum(v);
  return double.nan;
}

double _strToNum(String s) {
  final t = s.trim();
  if (t.isEmpty) return 0;
  // Number() accepts a sign before the radix prefix ('-0x10' -> -16).
  final sign = t.startsWith('-') ? -1.0 : 1.0;
  final body = (t.startsWith('+') || t.startsWith('-')) ? t.substring(1) : t;
  if (body.startsWith('0x') || body.startsWith('0X')) {
    final digits = body.substring(2);
    final v =
        int.tryParse(digits, radix: 16) ??
        BigInt.tryParse(digits, radix: 16)?.toDouble();
    return v == null ? double.nan : sign * v.toDouble();
  }
  return double.tryParse(t) ?? double.nan;
}

int jsToInt32(Object? v) {
  final n = jsToNum(v);
  if (n is double && (n.isNaN || n.isInfinite)) return 0;
  final i = (n % 4294967296).toInt();
  return i >= 2147483648 ? i - 4294967296 : i;
}

int _jsToUint32(Object? v) => jsToInt32(v) & 0xFFFFFFFF;

String jsTypeof(Object? v) {
  if (v is JsUndefined) return 'undefined';
  if (v == null) return 'object';
  if (v is bool) return 'boolean';
  if (v is num) return 'number';
  if (v is String) return 'string';
  return 'object';
}

Object? applyJsBinary(String op, Object? l, Object? r) {
  if (op == '==' || op == '!=' || op == '===' || op == '!==') {
    return _equality(op, l, r);
  }
  if (op == '<' || op == '<=' || op == '>' || op == '>=') {
    return _comparison(op, l, r);
  }
  if (op == 'in') {
    // `x in obj`: Map literals use key lookup; array literals support
    // integer indices and 'length'. Anything else is outside the constant
    // subset — bail instead of guessing (official `new Function` handles it).
    if (r is Map) return r.containsKey(jsStr(l));
    if (r is List) {
      if (jsStr(l) == 'length') return true;
      final i = jsToNum(l);
      return i is int || (i is double && i == i.truncateToDouble())
          ? i >= 0 && i < r.length
          : false;
    }
    throw StateError('constEval: unsupported `in` right operand');
  }
  return _arithOrBitwise(op, l, r);
}

bool _equality(String op, Object? l, Object? r) {
  final eq = (op == '==' || op == '!=') ? _looseEq(l, r) : _strictEq(l, r);
  return (op == '==' || op == '===') ? eq : !eq;
}

Object? _comparison(String op, Object? l, Object? r) {
  final c = _compareValues(l, r);
  if (c == null) return false;
  return switch (op) {
    '<' => c < 0,
    '<=' => c <= 0,
    '>' => c > 0,
    _ => c >= 0,
  };
}

int? _compareValues(Object? l, Object? r) {
  if (l is String && r is String) return l.compareTo(r);
  final ln = jsToNum(l).toDouble();
  final rn = jsToNum(r).toDouble();
  if (ln.isNaN || rn.isNaN) return null;
  return ln.compareTo(rn);
}

Object? _arithOrBitwise(String op, Object? l, Object? r) {
  switch (op) {
    case '+':
      return (l is String || r is String)
          ? '${jsStr(l)}${jsStr(r)}'
          : jsToNum(l) + jsToNum(r);
    case '-':
      return jsToNum(l) - jsToNum(r);
    case '*':
      return jsToNum(l) * jsToNum(r);
    case '/':
      return jsToNum(l) / jsToNum(r);
    case '%':
      return jsToNum(l).remainder(jsToNum(r));
    case '**':
      // Double arithmetic: JS numbers are doubles, so 2 ** 1024 must yield
      // Infinity rather than wrap around 64-bit int math.
      return math.pow(jsToNum(l).toDouble(), jsToNum(r).toDouble());
  }
  return _bitwise(op, l, r);
}

int _bitwise(String op, Object? l, Object? r) {
  final count = _jsToUint32(r) & 31;
  return switch (op) {
    '&' => jsToInt32(l) & jsToInt32(r),
    '|' => jsToInt32(l) | jsToInt32(r),
    '^' => jsToInt32(l) ^ jsToInt32(r),
    '<<' => _wrap32(jsToInt32(l) << count),
    '>>' => jsToInt32(l) >> count,
    '>>>' => _jsToUint32(l) >>> count,
    _ => throw StateError('constEval: unsupported binary $op'),
  };
}

int _wrap32(int v) {
  final mod = v % 4294967296;
  return mod >= 2147483648 ? mod - 4294967296 : mod;
}

bool _strictEq(Object? l, Object? r) {
  if (l is JsUndefined || r is JsUndefined) {
    return l is JsUndefined && r is JsUndefined;
  }
  if (l == null || r == null) return l == null && r == null;
  if (l is num && r is num) return l.toDouble() == r.toDouble();
  if (l.runtimeType != r.runtimeType) return false;
  if (l is List || l is Map) return identical(l, r);
  return l == r;
}

bool _looseEq(Object? l, Object? r) {
  if (_strictEq(l, r)) return true;
  if (l == null || l is JsUndefined) {
    return r == null || r is JsUndefined;
  }
  if (r == null || r is JsUndefined) return false;
  if (l is num && r is String) return l == _strToNum(r);
  if (l is String && r is num) return _strToNum(l) == r;
  if (l is bool) return _looseEq(jsToNum(l), r);
  if (r is bool) return _looseEq(l, jsToNum(r));
  // Object (array/object literal) vs primitive: ToPrimitive (join(',') for
  // arrays, '[object Object]' for plain objects) then compare primitives.
  final lp = (l is List || l is Map) ? jsStr(l) : null;
  final rp = (r is List || r is Map) ? jsStr(r) : null;
  if (lp != null || rp != null) {
    return _looseEq(lp ?? l, rp ?? r);
  }
  return false;
}

// --- literal parsing -------------------------------------------------------

num parseJsNumber(String text) {
  final t = text.replaceAll('_', '');
  if (t.endsWith('n')) throw StateError('constEval: bigint unsupported');
  if (t.startsWith('0x') || t.startsWith('0X')) {
    return _parseRadix(t.substring(2), 16);
  }
  if (t.startsWith('0b') || t.startsWith('0B')) {
    return _parseRadix(t.substring(2), 2);
  }
  if (t.startsWith('0o') || t.startsWith('0O')) {
    return _parseRadix(t.substring(2), 8);
  }
  var normalized = t;
  if (normalized.startsWith('.')) normalized = '0$normalized';
  if (normalized.endsWith('.')) normalized = '${normalized}0';
  return double.parse(normalized);
}

/// Radix literal value; beyond 64-bit range falls back to double, matching
/// JS where every numeric literal is a double (e.g. 0xFFFFFFFFFFFFFFFFF).
num _parseRadix(String digits, int radix) {
  final v = int.tryParse(digits, radix: radix);
  if (v != null) return v;
  return BigInt.tryParse(digits, radix: radix)?.toDouble() ??
      (throw StateError('constEval: malformed radix-$radix literal'));
}

/// Unquote ('..'/\"..\" already stripped by caller) JS string escapes.
String parseJsString(String text) =>
    unescapeJsString(text.substring(1, text.length - 1));

String unescapeJsString(String s) {
  if (!s.contains('\\')) return s;
  final buf = StringBuffer();
  var i = 0;
  while (i < s.length) {
    if (s[i] != '\\') {
      buf.write(s[i]);
      i++;
      continue;
    }
    final r = _escapeAt(s, i);
    buf.write(r.$1);
    i = r.$2;
  }
  return buf.toString();
}

(String, int) _escapeAt(String s, int i) {
  final c = i + 1 < s.length ? s[i + 1] : '';
  final simple = _simpleEscapes[c];
  if (simple != null) return (simple, i + 2);
  if (c == 'x') return _hexEscape(s, i);
  if (c == 'u') return _unicodeEscape(s, i);
  if (c == '\n') return ('', i + 2);
  if (c == '\r') {
    return ('', i + (i + 2 < s.length && s[i + 2] == '\n' ? 3 : 2));
  }
  return (c, i + 2);
}

const _simpleEscapes = {
  'n': '\n',
  'r': '\r',
  't': '\t',
  'b': '\u0008',
  'f': '\u000C',
  'v': '\u000B',
  '0': '\u0000',
};

(String, int) _hexEscape(String s, int i) {
  return (
    String.fromCharCode(int.parse(s.substring(i + 2, i + 4), radix: 16)),
    i + 4,
  );
}

(String, int) _unicodeEscape(String s, int i) {
  if (i + 2 < s.length && s[i + 2] == '{') {
    final close = s.indexOf('}', i + 3);
    final code = int.parse(s.substring(i + 3, close), radix: 16);
    return (String.fromCharCode(code), close + 1);
  }
  return (
    String.fromCharCode(int.parse(s.substring(i + 2, i + 6), radix: 16)),
    i + 6,
  );
}
