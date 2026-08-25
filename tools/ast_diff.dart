// English comments per ~/REPO rule.
// Golden-tree regression gate for the oxc-backed TS parser chain
// (OxcFFI + OxcMapper). The committed baseline tools/ast_golden.jsonl
// pins the full mapped AstNode tree of every corpus entry; any mapper
// edit or oxc bump that changes node type/spans/children order fails
// here instead of silently shifting consumer behavior.
// Run from the repo root:
//   dart tools/ast_diff.dart            # replay corpus vs golden baseline
//   dart tools/ast_diff.dart --record   # regenerate the baseline

import 'dart:convert';
import 'dart:io';

import 'package:vue_sfc_parser/ts_parser.dart';

const _corpusPath = 'tools/ast_corpus.jsonl';
const _goldenPath = 'tools/ast_golden.jsonl';

void main(List<String> args) {
  final corpus = _readJsonl(_corpusPath);
  if (args.contains('--record')) {
    _record(corpus);
  } else {
    _replay(corpus, _readJsonl(_goldenPath));
  }
}

List<Map<String, dynamic>> _readJsonl(String path) {
  return File(path)
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .map((l) => jsonDecode(l) as Map<String, dynamic>)
      .toList();
}

void _record(List<Map<String, dynamic>> corpus) {
  final parser = TSParser();
  final out = StringBuffer();
  for (final e in corpus) {
    final root = parser.parse(
      code: e['code'] as String,
      language: e['language'] as String,
    );
    out.writeln(
      jsonEncode({
        'code': e['code'],
        'language': e['language'],
        'tree': root.toJson(),
      }),
    );
  }
  File(_goldenPath).writeAsStringSync(out.toString());
  print('recorded ${corpus.length} golden trees -> $_goldenPath');
}

void _replay(
  List<Map<String, dynamic>> corpus,
  List<Map<String, dynamic>> golden,
) {
  if (golden.length != corpus.length) {
    stderr.writeln(
      'baseline/corpus size mismatch (${golden.length} vs '
      '${corpus.length}); run: dart tools/ast_diff.dart --record',
    );
    exitCode = 2;
    return;
  }
  final parser = TSParser();
  var exact = 0;
  for (var i = 0; i < corpus.length; i++) {
    if (!_inputsUnchanged(corpus[i], golden[i])) {
      stderr.writeln(
        '#$i corpus entry changed since baseline; '
        'run: dart tools/ast_diff.dart --record',
      );
      exitCode = 2;
      continue;
    }
    if (_diffEntry(parser, corpus[i], golden[i]['tree'], i) == null) {
      exact++;
    }
  }
  print('EXACT: $exact / ${corpus.length}');
  if (exact != corpus.length) exitCode = 1;
}

bool _inputsUnchanged(Map<String, dynamic> entry, Map<String, dynamic> golden) {
  return golden['tree'] is Map &&
      entry['code'] == golden['code'] &&
      entry['language'] == golden['language'];
}

/// Parse one corpus entry and report the first divergence from its golden
/// tree; returns null on exact match.
String? _diffEntry(
  TSParser parser,
  Map<String, dynamic> entry,
  Object? expectedTree,
  int index,
) {
  final code = entry['code'] as String;
  final language = entry['language'] as String;
  final tree = parser.parse(code: code, language: language).toJson();
  final diff = _firstDiff(expectedTree, tree, 'root');
  if (diff != null) {
    print('#$index [$language] $diff :: ${_preview(code)}');
  }
  return diff;
}

String _preview(String code) {
  final flat = code.replaceAll('\n', ' ');
  return flat.length <= 60 ? flat : '${flat.substring(0, 60)}...';
}

/// First differing leaf between two decoded JSON trees, or null when equal.
String? _firstDiff(Object? expected, Object? actual, String path) {
  if (expected is Map && actual is Map) {
    return _diffFields(expected, actual, path);
  }
  if (expected is List && actual is List) {
    return _diffItems(expected, actual, path);
  }
  return expected == actual ? null : '$path: $expected != $actual';
}

String? _diffFields(Map expected, Map actual, String path) {
  if (expected.length != actual.length) {
    return '$path: field count ${expected.length} != ${actual.length}';
  }
  for (final key in expected.keys) {
    if (!actual.containsKey(key)) return '$path.$key: missing';
    final d = _firstDiff(expected[key], actual[key], '$path.$key');
    if (d != null) return d;
  }
  return null;
}

String? _diffItems(List expected, List actual, String path) {
  if (expected.length != actual.length) {
    return '$path: item count ${expected.length} != ${actual.length}';
  }
  for (var i = 0; i < expected.length; i++) {
    final d = _firstDiff(expected[i], actual[i], '$path[$i]');
    if (d != null) return d;
  }
  return null;
}
