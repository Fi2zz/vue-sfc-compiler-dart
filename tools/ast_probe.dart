// English comments per ~/REPO rule.
// Probe: parse one source snippet with both the tree-sitter chain and the
// oxc chain, print both AstNode trees and their first divergence.
// Usage: dart tools/ast_probe.dart [lang]   (source on stdin)

import 'dart:convert';
import 'dart:io';

import 'package:vue_sfc_parser/ts_parser.dart';
import 'package:vue_sfc_parser/ts_syntax/oxc_ffi.dart';
import 'package:vue_sfc_parser/ts_syntax/oxc_mapper.dart';

Future<void> main(List<String> args) async {
  final lang = args.isEmpty ? 'ts' : args.first;
  final code = await utf8.decoder.bind(stdin).join();
  final oldRoot = TSParser().parse(code: code, language: lang);
  final payload = OxcFFI.load().parseJson(code, lang);
  final newRoot = OxcMapper(code, language: lang).mapProgram(payload);
  print('=== tree-sitter ===');
  _printTree(oldRoot, '');
  print('=== oxc mapped ===');
  _printTree(newRoot, '');
  final divergence = firstDivergence(oldRoot, newRoot);
  print(divergence ?? 'TREES EQUAL');
}

void _printTree(AstNode node, String indent) {
  print('$indent${node.type} [${node.startByte},${node.endByte}) '
      '@${node.startRow}:${node.startColumn}');
  for (final c in node.children) {
    _printTree(c, '$indent  ');
  }
}

/// Human-readable first divergence between two trees, or null when equal.
String? firstDivergence(AstNode a, AstNode b) {
  if (a.type != b.type) {
    return 'type: ${a.type} != ${b.type} @[${a.startByte},${a.endByte})';
  }
  if (a.startByte != b.startByte || a.endByte != b.endByte) {
    return 'span ${a.type}: [${a.startByte},${a.endByte}) != '
        '[${b.startByte},${b.endByte})';
  }
  if (a.startRow != b.startRow || a.startColumn != b.startColumn) {
    return 'point ${a.type}: ${a.startRow}:${a.startColumn} != '
        '${b.startRow}:${b.startColumn}';
  }
  if (a.children.length != b.children.length) {
    return 'child count ${a.type}: ${a.children.length} != ${b.children.length}';
  }
  for (var i = 0; i < a.children.length; i++) {
    final d = firstDivergence(a.children[i], b.children[i]);
    if (d != null) return '${a.type} > $d';
  }
  return null;
}
