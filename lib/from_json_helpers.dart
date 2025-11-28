part of 'ast.dart';

/// Utility: read comments list.
List<Comment>? readComments(dynamic v) {
  if (v == null) return null;
  final xs = v as List;
  return xs.map((e) {
    final m = e as Map<String, dynamic>;
    final t = m['type'] as String;
    final placement = m['placement'] as String?;
    final c = t == 'CommentBlock'
        ? commentBlockFromJson(m)
        : commentLineFromJson(m);
    // enrich placement if present in JSON map
    if (placement != null) {
      if (c is CommentBlock) {
        return CommentBlock(
          value: c.value,
          // start: c.start,
          // end: c.end,
          loc: c.loc,
          ignore: c.ignore,
          placement: placement,
        );
      }
      if (c is CommentLine) {
        return CommentLine(
          value: c.value,
          loc: c.loc,
          ignore: c.ignore,
          placement: placement,
        );
      }
    }
    return c;
  }).toList();
}

/// Normalize Program-level comments by hoisting all comments found in body
/// and descendants to Program's `leadingComments`/`innerComments`/`trailingComments`.
/// Classification is position-based relative to the first/last top-level
/// statement: comments ending before the first start → leading; starting after
/// the last end → trailing; others → inner. Original JSON is mutated in place:
/// comment keys are removed from child nodes to avoid duplication.
void normalizeProgramJson(Map<String, dynamic> m) {
  int? firstStart;
  int? lastEnd;
  final body = m['body'];
  if (body is List) {
    for (final it in body) {
      if (it is Map<String, dynamic>) {
        final s = (it['start'] as num?)?.toInt();
        final e = (it['end'] as num?)?.toInt();
        if (s != null) {
          firstStart = (firstStart == null)
              ? s
              : (s < firstStart ? s : firstStart);
        }
        if (e != null) {
          lastEnd = (lastEnd == null) ? e : (e > lastEnd ? e : lastEnd);
        }
      }
    }
  }

  final leading = <Map<String, dynamic>>[];
  final inner = <Map<String, dynamic>>[];
  final trailing = <Map<String, dynamic>>[];

  void classifyAndCollect(List<dynamic>? arr) {
    if (arr == null) return;
    for (final e in arr) {
      if (e is Map<String, dynamic>) {
        final cs = (e['start'] as num?)?.toInt();
        final ce = (e['end'] as num?)?.toInt();
        if (ce != null && firstStart != null && ce <= firstStart) {
          e['placement'] = 'leading';
          leading.add(e);
        } else if (cs != null && lastEnd != null && cs >= lastEnd) {
          e['placement'] = 'trailing';
          trailing.add(e);
        } else {
          e['placement'] = 'inner';
          inner.add(e);
        }
      }
    }
  }

  void hoistNode(Map<String, dynamic> node) {
    classifyAndCollect(node['leadingComments'] as List<dynamic>?);
    classifyAndCollect(node['innerComments'] as List<dynamic>?);
    classifyAndCollect(node['trailingComments'] as List<dynamic>?);
    node.remove('leadingComments');
    node.remove('innerComments');
    node.remove('trailingComments');
    for (final entry in node.entries) {
      final v = entry.value;
      if (v is Map<String, dynamic>) {
        hoistNode(v);
      } else if (v is List) {
        for (final el in v) {
          if (el is Map<String, dynamic>) hoistNode(el);
        }
      }
    }
  }

  // Traverse body and descendants
  if (body is List) {
    for (final it in body) {
      if (it is Map<String, dynamic>) hoistNode(it);
    }
  }

  // Merge all program-level comments into a single parallel `comments` array
  final existing =
      (m['comments'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .toList() ??
      <Map<String, dynamic>>[];
  final all = <Map<String, dynamic>>[];
  all.addAll(existing);
  all.addAll(leading);
  all.addAll(inner);
  all.addAll(trailing);
  if (all.isNotEmpty) m['comments'] = dedupeComments(all);
}

List<Map<String, dynamic>> dedupeComments(List<Map<String, dynamic>> xs) {
  final seen = <String>{};
  final out = <Map<String, dynamic>>[];
  for (final c in xs) {
    final sig = '${c['type']}|${c['value']}|${c['start']}|${c['end']}';
    if (seen.add(sig)) out.add(c);
  }
  return out;
}

/// Utility: read range [start,end].
List<int>? readRange(dynamic v) {
  if (v == null) return null;
  final xs = v as List;
  return xs.map((e) => (e as num).toInt()).toList();
}

/// Utility: generic list reader.
List<T> readList<T>(dynamic v, T Function(Map<String, dynamic>) f) {
  if (v == null) return const [];
  final xs = v as List;
  return xs.map((e) => f(e as Map<String, dynamic>)).toList();
}

/// Utility: mixed list (Expression | SpreadElement | ArgumentPlaceholder).
List<Object?> readMixedList(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs
      .map((e) => TsAstFactory.fromJsonAny(e as Map<String, dynamic>))
      .toList();
}

/// Utility: optional pattern list (null | PatternLike) for ArrayPattern.
List<Object?> readOptionalPatternList(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs.map((e) {
    if (e == null) return null;
    final m = e as Map<String, dynamic>;
    return TsAstFactory.fromJsonExpressionOrPatternLike(m);
  }).toList();
}

/// Utility: optional expression list (null | Expression) for ArrayExpression.
List<Object?> readOptionalExpressionList(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs.map((e) {
    if (e == null) return null;
    final m = e as Map<String, dynamic>;
    return TsAstFactory.fromJsonExpression(m);
  }).toList();
}

/// Utility: object expression props.
List<Object> readObjProps(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs
      .map((e) => TsAstFactory.fromJsonObjectMember(e as Map<String, dynamic>))
      .toList();
}

/// Utility: object pattern props.
List<Object> readObjPatternProps(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs
      .map(
        (e) =>
            TsAstFactory.fromJsonObjectPatternProp(e as Map<String, dynamic>),
      )
      .toList();
}

/// Utility: function parameter list.
List<Object> readFunctionParameters(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs
      .map(
        (e) =>
            TsAstFactory.fromJsonFunctionParameter(e as Map<String, dynamic>),
      )
      .toList();
}

/// Utility: import specifiers list.
List<Object> readImportSpecifiers(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs
      .map(
        (e) => TsAstFactory.fromJsonImportSpecifier(e as Map<String, dynamic>),
      )
      .toList();
}

/// Utility: export specifiers list.
List<Object> readExportSpecifiers(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs
      .map(
        (e) => TsAstFactory.fromJsonExportSpecifier(e as Map<String, dynamic>),
      )
      .toList();
}
