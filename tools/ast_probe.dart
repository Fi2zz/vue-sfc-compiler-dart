// English comments per ~/REPO rule.
// Probe: parse one source snippet (stdin) through the oxc-backed chain
// and print the mapped AstNode tree, for inspecting mapper output.
// Usage: dart tools/ast_probe.dart [lang]   (source on stdin)

import 'dart:convert';
import 'dart:io';

import 'package:vue_sfc_parser/ts_parser.dart';

Future<void> main(List<String> args) async {
  final lang = args.isEmpty ? 'ts' : args.first;
  final code = await utf8.decoder.bind(stdin).join();
  _printTree(TSParser().parse(code: code, language: lang), '');
}

void _printTree(AstNode node, String indent) {
  print(
    '$indent${node.type} [${node.startByte},${node.endByte}) '
    '@${node.startRow}:${node.startColumn}',
  );
  for (final c in node.children) {
    _printTree(c, '$indent  ');
  }
}
