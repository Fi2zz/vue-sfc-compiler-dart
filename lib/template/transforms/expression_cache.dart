// Expression-parse batching: pre-collect every default-wrapped expression
// source a template transform will request, parse them in one shot, and let
// _parseExpression serve hits from cache (misses fall back individually).
// Two fill strategies, compared in PERF_BENCHMARK.md:
//   ffi    - one oxc_parse_batch round-trip returning a JSON array
//   concat - one existing TSParser.parse of "[e0,e1,...]" + span rebase
import 'dart:convert';

import '../../ts_parser.dart';
import '../../ts_syntax/oxc_ffi.dart';
import '../../ts_syntax/est_node.dart';
import '../../ts_syntax/oxc_mapper.dart';
import '../tmpl_ast.dart';

/// Ordered unique `(raw)` wrapped sources for interpolation contents,
/// directive expressions and dynamic args. Rare flag variants (asParams /
/// asRawStatements) intentionally not collected; those call sites fall back
/// to per-expression parsing.
List<String> collectExpressionSources(TmplNode root) {
  final out = <String>{};
  void visit(TmplNode n) {
    if (n is InterpolationNode) {
      _addExpr(out, n.content);
    } else if (n is ElementNode) {
      for (final p in n.props) {
        if (p is! DirectiveNode) continue;
        // v-for: the whole `x in y` exp has no consumer (transformExpression
        // skips it); finalizeForParseResult processes parseResult.source
        // instead, so collect that (null when for-parse failed).
        if (p.name == 'for') {
          _addExpr(out, p.forParseResult?.source);
        } else {
          _addExpr(out, p.exp);
        }
        final arg = p.arg;
        if (arg is SimpleExpression && !arg.static_) _addExpr(out, arg);
      }
    }
    for (final c in childrenOf(n)) {
      visit(c);
    }
  }

  visit(root);
  return out.toList();
}

void _addExpr(Set<String> out, TmplNode? n) {
  if (n is SimpleExpression && n.content.trim().isNotEmpty) {
    out.add('(${n.content})');
  }
}

List<TmplNode> childrenOf(TmplNode n) {
  if (n is RootNode) return n.children;
  if (n is ElementNode) return n.children;
  return const [];
}

/// Strategy A: one oxc_parse_batch round-trip; each item decodes through the
/// regular single-parse mapping path. Whole-batch failure leaves the cache
/// untouched so every entry falls back individually.
void fillExpressionCacheFfi(
  Map<String, AstNode> cache,
  List<String> sources, {
  bool binary = false,
}) {
  if (sources.isEmpty) return;
  final oxc = OxcFFI.load();
  final List<EstNode> items;
  try {
    items = binary
        ? oxc.parseBinBatch(sources, 'ts')
        : [for (final m in oxc.parseJsonBatch(sources, 'ts')) estOf(m)];
  } catch (_) {
    return;
  }
  if (items.length != sources.length) return;
  for (var i = 0; i < sources.length; i++) {
    cache[sources[i]] = _payloadRoot(items[i], sources[i]);
  }
}

AstNode _payloadRoot(EstNode payload, String source) {
  final mapper = OxcMapper(source, language: 'ts');
  if (payload['ok'] == true) return mapper.mapProgram(payload);
  return mapper.errorTree();
}

/// Strategy B: one parse of `[e0,e1,...]`; every element subtree is copied
/// out with byte spans rebased to its standalone `(raw)` coordinates and
/// re-wrapped as program > expression_statement, matching the shape a
/// per-expression parse would have produced.
void fillExpressionCacheConcat(
  Map<String, AstNode> cache,
  List<String> sources,
) {
  if (sources.isEmpty) return;
  final text = '[${sources.join(',')}]';
  final root = TSParser().parse(code: text, language: 'ts');
  if (_hasError(root)) return;
  final array = _rootArray(root);
  if (array == null || array.children.length != sources.length) return;

  // All offsets below are UTF-8 bytes: oxc spans (el.startByte/endByte) are
  // byte-based, so cursor/len/line-starts must be byte-based too. UTF-16
  // indices would shift every element after the first multi-byte character.
  final textBytes = utf8.encode(text);
  final sourceBytes = [for (final s in sources) utf8.encode(s)];

  var cursor = 1; // just past '['
  for (var i = 0; i < sources.length; i++) {
    final el = array.children[i];
    final len = sourceBytes[i].length;
    while (cursor < el.startByte && textBytes[cursor] != 0x28) {
      cursor++;
    }
    final lines = _lineStarts(sourceBytes[i]);
    final endPt = _pointAt(lines, len);
    final sub = _rebase(el, cursor, lines);
    cache[sources[i]] = AstNode(
      type: 'program',
      startByte: 0,
      endByte: len,
      startRow: 0,
      startColumn: 0,
      endRow: endPt.$1,
      endColumn: endPt.$2,
      children: [
        AstNode(
          type: 'expression_statement',
          startByte: 0,
          endByte: len,
          startRow: 0,
          startColumn: 0,
          endRow: endPt.$1,
          endColumn: endPt.$2,
          children: [sub],
        ),
      ],
    );
    cursor += len + 1; // element + comma, in bytes
  }
}

AstNode? _rootArray(AstNode root) {
  for (final st in root.children) {
    for (final c in st.children) {
      if (c.type == 'array') return c;
    }
  }
  return null;
}

bool _hasError(AstNode node) {
  if (node.type == 'ERROR') return true;
  return node.children.any(_hasError);
}

/// Deep copy with byte-span shift and recomputed points against [lineStarts],
/// the line table of the shifted (standalone) source slice.
AstNode _rebase(AstNode n, int delta, List<int> lineStarts) {
  final s = n.startByte - delta;
  final e = n.endByte - delta;
  final sp = _pointAt(lineStarts, s);
  final ep = _pointAt(lineStarts, e);
  return AstNode(
    type: n.type,
    startByte: s,
    endByte: e,
    startRow: sp.$1,
    startColumn: sp.$2,
    endRow: ep.$1,
    endColumn: ep.$2,
    children: [for (final c in n.children) _rebase(c, delta, lineStarts)],
  );
}

List<int> _lineStarts(List<int> bytes) {
  final starts = <int>[0];
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] == 0x0A) starts.add(i + 1);
  }
  return starts;
}

(int, int) _pointAt(List<int> starts, int offset) {
  var lo = 0;
  var hi = starts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    if (starts[mid] <= offset) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return (lo, offset - starts[lo]);
}
