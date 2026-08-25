// English comments per ~/REPO rule.
// ast_diff harness: for every corpus entry, parse with both the tree-sitter
// chain and the oxc chain (oxc_ffi + OxcMapper) and recursively compare the
// two AstNode trees. Reports exact-match count and divergence families.
// Run: dart tools/ast_diff.dart [--census]

import 'dart:convert';
import 'dart:io';

import 'package:vue_sfc_parser/ts_parser.dart';
import 'package:vue_sfc_parser/ts_syntax/oxc_ffi.dart';
import 'package:vue_sfc_parser/ts_syntax/oxc_mapper.dart';

import 'ast_probe.dart' show firstDivergence;

void main(List<String> args) {
  final entries = _readCorpus('tools/ast_corpus.jsonl');
  final report = DiffReport();
  final tsParser = TSParser();
  final oxc = OxcFFI.load();
  for (final e in entries) {
    report.total++;
    _runOne(e, tsParser, oxc, report);
  }
  report.printSummary(census: args.contains('--census'));
}

List<Map<String, dynamic>> _readCorpus(String path) {
  return File(path)
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .map((l) => jsonDecode(l) as Map<String, dynamic>)
      .toList();
}

void _runOne(
  Map<String, dynamic> entry,
  TSParser tsParser,
  OxcFFI oxc,
  DiffReport report,
) {
  final code = entry['code'] as String;
  final language = entry['language'] as String;
  final oldRoot = _tryTreeSitter(tsParser, code, language, report);
  if (oldRoot == null) return;
  if (report.collectCensus) _census(oldRoot, report.nodeTypeCensus);
  final newRoot = _tryOxc(oxc, code, language, report);
  if (newRoot == null) return;
  final divergence = firstDivergence(oldRoot, newRoot);
  report.recordDivergence(code, language, divergence);
}

AstNode? _tryTreeSitter(
  TSParser parser,
  String code,
  String language,
  DiffReport report,
) {
  try {
    return parser.parse(code: code, language: language);
  } catch (_) {
    report.treeSitterFailed++;
    return null;
  }
}

AstNode? _tryOxc(OxcFFI oxc, String code, String language, DiffReport report) {
  try {
    final payload = oxc.parseJson(code, language);
    return OxcMapper(code, language: language).mapProgram(payload);
  } on UnimplementedError catch (e) {
    report.recordUnmapped('$e', code);
    return null;
  } catch (e) {
    report.oxcFailures.add('[$language] $e :: ${_preview(code)}');
    return null;
  }
}

String _preview(String code) {
  final flat = code.replaceAll('\n', ' ');
  return flat.length <= 60 ? flat : '${flat.substring(0, 60)}...';
}

void _census(AstNode node, Map<String, int> census) {
  census[node.type] = (census[node.type] ?? 0) + 1;
  for (final c in node.children) {
    _census(c, census);
  }
}

/// Counters and divergence families gathered over the whole corpus.
class DiffReport {
  int total = 0;
  int exact = 0;
  int treeSitterFailed = 0;
  bool collectCensus = false;
  final oxcFailures = <String>[];
  final unmappedTypes = <String, int>{};
  final divergenceKinds = <String, int>{};
  final divergenceSamples = <String, String>{};
  final nodeTypeCensus = <String, int>{};

  void recordDivergence(String code, String language, String? divergence) {
    if (divergence == null) {
      exact++;
      return;
    }
    final kind = divergence.split(':').first;
    divergenceKinds[kind] = (divergenceKinds[kind] ?? 0) + 1;
    divergenceSamples.putIfAbsent(
      kind,
      () => '[$language] $divergence :: ${_preview(code)}',
    );
  }

  void recordUnmapped(String error, String code) {
    final type = error.replaceAll('oxc mapper: unmapped node ', '');
    unmappedTypes[type] = (unmappedTypes[type] ?? 0) + 1;
    divergenceSamples.putIfAbsent('unmapped:$type', () => _preview(code));
  }

  void printSummary({bool census = false}) {
    collectCensus = census;
    print('corpus entries: $total');
    print('EXACT: $exact / $total');
    print('tree-sitter failed: $treeSitterFailed');
    _printUnmapped();
    _printDivergences();
    if (oxcFailures.isNotEmpty) {
      print('--- oxc chain failures (first 5) ---');
      oxcFailures.take(5).forEach(print);
    }
    if (census) _printCensus();
  }

  void _printUnmapped() {
    if (unmappedTypes.isEmpty) return;
    print('--- unmapped node types (${unmappedTypes.length}) ---');
    final sorted = unmappedTypes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted) {
      print('${e.key}: ${e.value}   e.g. ${divergenceSamples['unmapped:${e.key}']}');
    }
  }

  void _printDivergences() {
    if (divergenceKinds.isEmpty) return;
    print('--- divergence kinds (${divergenceKinds.length}) ---');
    final sorted = divergenceKinds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted) {
      print('${e.key}: ${e.value}   e.g. ${divergenceSamples[e.key]}');
    }
  }

  void _printCensus() {
    print('--- tree-sitter node type census (${nodeTypeCensus.length}) ---');
    final sorted = nodeTypeCensus.keys.toList()..sort();
    for (final t in sorted) {
      print('$t: ${nodeTypeCensus[t]}');
    }
  }
}
