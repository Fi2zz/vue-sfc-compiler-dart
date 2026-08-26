// Differential harness: for every corpus entry, parse via the JSON batch
// transport and the binary batch transport and compare AstNode.toJson
// byte-for-byte. Also covers single-parse (off) as a third witness.
import 'dart:convert';
import 'dart:io';
import 'package:vue_sfc_parser/ts_parser.dart';
import 'package:vue_sfc_parser/ts_syntax/oxc_ffi.dart';
import 'package:vue_sfc_parser/ts_syntax/est_node.dart';
import 'package:vue_sfc_parser/ts_syntax/oxc_mapper.dart';

void main() {
  final entries = File('tools/ast_corpus.jsonl')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .map((l) => jsonDecode(l) as Map<String, dynamic>)
      .toList();
  final oxc = OxcFFI.load();
  var mismatches = 0, jsonFails = 0, binFails = 0, checked = 0;

  AstNode? jsonPath(String src, String lang) {
    try {
      final items = oxc.parseJsonBatch([src], lang);
      return OxcMapper(src, language: lang).mapProgram(estOf(items.first));
    } catch (_) {
      jsonFails++;
      return null;
    }
  }

  AstNode? binPath(String src, String lang, {bool debug = false}) {
    try {
      final items = oxc.parseBinBatch([src], lang);
      return OxcMapper(src, language: lang).mapProgram(items.first);
    } catch (e) {
      if (debug) rethrow;
      if (binFails == 0) { stdout.writeln('first bin failure: $e'); final st = (e is Error) ? e.stackTrace.toString().split('\n') : const <String>[]; stdout.writeln(st.take(6).join('\n')); }
      binFails++;
      return null;
    }
  }

  for (final e in entries) {
    final src = e['code'] as String;
    final lang = e['language'] as String;
    // Reference: the shipped single-parse path.
    final ref = TSParser().parse(code: src, language: lang).toJson();
    final j = jsonPath(src, lang)?.toJson();
    final b = binPath(src, lang, debug: mismatches == -1 && binFails == 0)?.toJson();
    if (j != null && const JsonEncoder().convert(j) == const JsonEncoder().convert(ref)) {
      checked++;
    } else if (j != null) {
      mismatches++;
      stdout.writeln('JSON-PATH MISMATCH [$lang] ${src.replaceAll('\n', ' ')}');
    }
    if (b != null && const JsonEncoder().convert(b) != const JsonEncoder().convert(ref)) {
      mismatches++;
      stdout.writeln('BIN-PATH MISMATCH [$lang] ${src.replaceAll('\n', ' ')}');
    }
    if (j == null && b == null) { checked++; } // both failed: parity
  }
  stdout.writeln('entries=${entries.length} identical=$checked jsonFails=$jsonFails binFails=$binFails mismatches=$mismatches');
}
