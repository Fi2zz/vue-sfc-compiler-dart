import 'dart:convert';
import 'dart:io';
import 'package:vue_sfc_parser/ts_parser.dart';
Future<void> main(List<String> args) async {
  final lang = args.isEmpty ? 'ts' : args.first;
  final code = await utf8.decoder.bind(stdin).join();
  final root = TSParser().parse(code: code, language: lang);
  void p(AstNode n, String i) {
    print('$i${n.type} [${n.startByte},${n.endByte}) @${n.startRow}:${n.startColumn}-${n.endRow}:${n.endColumn}');
    n.children.forEach((c) => p(c, '$i  '));
  }
  p(root, '');
}
