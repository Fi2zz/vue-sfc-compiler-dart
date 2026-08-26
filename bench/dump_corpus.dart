// Emits bench/corpus_shared.json - the single source of truth for the fixed
// benchmark tiers, so the Dart and Node runners compile identical inputs.
// Run after any change here: dart run bench/dump_corpus.dart
import 'dart:convert';
import 'dart:io';
import 'corpus_data.dart';

void main() {
  File('bench/corpus_shared.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'tiny': tinyCorpus,
        'ts_heavy': tsHeavyCorpus,
        'tmpl_heavy': tmplHeavyCorpus,
        'error': errorCorpus,
      }));
  stdout.writeln('written bench/corpus_shared.json');
}
