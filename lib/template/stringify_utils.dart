// Ports of shared.cjs.js helpers used by stringifyStatic (compiler-dom):
// escapeHtml / toDisplayString / normalizeClass / normalizeStyle /
// stringifyStyle, plus JS String()/truthiness/JSON.stringify semantics
// and the known-attribute tables.

/// JS `undefined` sentinel: distinct from null (`v != null` excludes both,
/// but `String(undefined)` is 'undefined' while `String(null)` is 'null').
final class JsUndefined {
  const JsUndefined();
}

const jsUndefined = JsUndefined();

// --- JS coercion semantics -------------------------------------------------

bool jsTruthy(Object? v) {
  if (v == null || v is JsUndefined) return false;
  if (v is bool) return v;
  if (v is num) return v != 0 && !(v is double && v.isNaN);
  if (v is String) return v.isNotEmpty;
  return true;
}

/// JS `String(value)` coercion.
String jsStr(Object? v) {
  if (v is String) return v;
  if (v == null) return 'null';
  if (v is JsUndefined) return 'undefined';
  if (v is bool) return '$v';
  if (v is num) return jsNumToString(v);
  if (v is List) {
    return v
        .map((e) => e == null || e is JsUndefined ? '' : jsStr(e))
        .join(',');
  }
  return '[object Object]';
}

/// JS `Number.prototype.toString()` for the ranges templates produce.
String jsNumToString(num v) {
  if (v is double && v.isNaN) return 'NaN';
  if (v == double.infinity) return 'Infinity';
  if (v == double.negativeInfinity) return '-Infinity';
  final d = v.toDouble();
  if (d == 0) return '0'; // also covers -0
  final abs = d.abs();
  if (abs >= 1e-6 && abs < 1e21) return _fixedNotation(d);
  return d.toString(); // Dart exponential matches JS (e.g. 1e+21, 1.5e-7)
}

String _fixedNotation(double d) {
  if (d == d.truncateToDouble()) return d.truncate().toString();
  var s = d.toString();
  if (!s.contains('e')) return s;
  // Expand Dart's exponential form into JS fixed notation (1.23e-5 range).
  final parts = s.split('e');
  final exp = int.parse(parts[1]);
  final mantissa = parts[0].replaceAll('.', '').replaceFirst('-', '');
  final sign = d < 0 ? '-' : '';
  final dot = parts[0].replaceFirst('-', '').indexOf('.');
  final intDigits = dot < 0 ? mantissa.length : dot;
  final shift = exp + intDigits;
  if (shift <= 0) return '${sign}0.${'0' * -shift}$mantissa';
  if (shift >= mantissa.length) {
    return '$sign$mantissa${'0' * (shift - mantissa.length)}';
  }
  return '$sign${mantissa.substring(0, shift)}.${mantissa.substring(shift)}';
}

// --- JSON.stringify --------------------------------------------------------

/// JS `JSON.stringify(value, null, indent)`; indent < 0 means compact.
/// Non-finite numbers become null, undefined object props are skipped,
/// undefined array items become null.
String jsJsonString(Object? v, [int indent = -1]) => _jsonAt(v, indent, 0);

String _jsonAt(Object? v, int indent, int depth) {
  if (v == null || v is JsUndefined) return 'null';
  if (v is bool) return '$v';
  if (v is num) return _jsonNum(v);
  if (v is String) return _jsonStr(v);
  if (v is List) return _jsonList(v, indent, depth);
  if (v is Map) return _jsonMap(v, indent, depth);
  return 'null';
}

String _jsonNum(num v) {
  if (v is double && !v.isFinite) return 'null';
  return jsNumToString(v);
}

String _jsonStr(String s) {
  final buf = StringBuffer('"');
  for (final unit in s.codeUnits) {
    buf.write(switch (unit) {
      0x22 => '\\"',
      0x5C => '\\\\',
      0x08 => '\\b',
      0x09 => '\\t',
      0x0A => '\\n',
      0x0C => '\\f',
      0x0D => '\\r',
      < 0x20 => '\\u${unit.toRadixString(16).padLeft(4, '0')}',
      _ => String.fromCharCode(unit),
    });
  }
  return '$buf"';
}

String _jsonList(List<Object?> list, int indent, int depth) {
  if (list.isEmpty) return '[]';
  final items = list.map((e) => _jsonAt(e, indent, depth + 1)).toList();
  return _jsonJoin('[', ']', items, indent, depth);
}

String _jsonMap(Map<Object?, Object?> map, int indent, int depth) {
  final entries = <String>[];
  map.forEach((k, v) {
    if (v is JsUndefined) return;
    entries.add('${_jsonStr(jsStr(k))}${indent < 0 ? ':' : ': '}'
        '${_jsonAt(v, indent, depth + 1)}');
  });
  if (entries.isEmpty) return '{}';
  return _jsonJoin('{', '}', entries, indent, depth);
}

String _jsonJoin(
    String open, String close, List<String> items, int indent, int depth) {
  if (indent < 0) return '$open${items.join(',')}$close';
  final pad = ' ' * (indent * (depth + 1));
  final padEnd = ' ' * (indent * depth);
  return '$open\n$pad${items.join(',\n$pad')}\n$padEnd$close';
}

// --- escapeHtml ------------------------------------------------------------

final _escapeRE = RegExp(r'''["'&<>]''');

String escapeHtml(Object? value) {
  final str = jsStr(value);
  if (!_escapeRE.hasMatch(str)) return str;
  return str.replaceAllMapped(
      _escapeRE,
      (m) => switch (m[0]) {
            '"' => '&quot;',
            '&' => '&amp;',
            "'" => '&#39;',
            '<' => '&lt;',
            _ => '&gt;',
          });
}

// --- toDisplayString -------------------------------------------------------

String toDisplayString(Object? val) {
  if (val is String) return val;
  if (val == null || val is JsUndefined) return '';
  if (val is List || val is Map) return jsJsonString(val, 2);
  return jsStr(val);
}

// --- normalizeClass / normalizeStyle / stringifyStyle ----------------------

String normalizeClass(Object? value) {
  var res = '';
  if (value is String) {
    res = value;
  } else if (value is List) {
    for (final item in value) {
      final normalized = normalizeClass(item);
      if (normalized.isNotEmpty) res += '$normalized ';
    }
  } else if (value is Map) {
    value.forEach((name, enabled) {
      if (jsTruthy(enabled)) res += '$name ';
    });
  }
  return res.trim();
}

Object? normalizeStyle(Object? value) {
  if (value is List) {
    final res = <String, Object?>{};
    for (final item in value) {
      final normalized =
          item is String ? parseStringStyle(item) : normalizeStyle(item);
      if (normalized is Map<String, Object?>) res.addAll(normalized);
    }
    return res;
  }
  if (value is String || value is Map) return value;
  return null;
}

final _listDelimiterRE = RegExp(r';(?![^(]*\))');
final _styleCommentRE = RegExp(r'/\*[^]*?\*/');

Map<String, Object?> parseStringStyle(String cssText) {
  final ret = <String, Object?>{};
  for (final item in cssText.replaceAll(_styleCommentRE, '').split(_listDelimiterRE)) {
    if (item.isEmpty) continue;
    // 官方 JS 用 /:(.+)/ split 捕获；Dart 的 split 会插入捕获组且 [^] 语义
    // 不同，改为手动首个冒号切分（与 /:(.+)/ 首匹配等价）。
    final colon = item.indexOf(':');
    if (colon <= 0) continue;
    ret[item.substring(0, colon).trim()] = item.substring(colon + 1).trim();
  }
  return ret;
}

String stringifyStyle(Object? styles) {
  if (styles == null || styles is JsUndefined) return '';
  if (styles is String) return styles;
  if (styles is! Map) return '';
  final buf = StringBuffer();
  styles.forEach((key, value) {
    if (value is String || value is num) {
      final k = key.startsWith('--') ? key : _hyphenate(key);
      buf.write('$k:${jsStr(value)};');
    }
  });
  return buf.toString();
}

final _hyphenateRE = RegExp(r'\B([A-Z])');

String _hyphenate(String str) =>
    str.replaceAllMapped(_hyphenateRE, (m) => '-${m[1]!.toLowerCase()}');
