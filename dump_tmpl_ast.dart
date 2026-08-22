import 'dart:convert';
import 'dart:io';
import 'package:vue_sfc_parser/template/dom_options.dart';
import 'package:vue_sfc_parser/template/tmpl_ast.dart';
import 'package:vue_sfc_parser/template/tmpl_parser.dart';

String enc(String t) => jsonEncode(t);
String loc(TmplNode n) => '@${n.loc.start.offset}-${n.loc.end.offset}';

String dumpProp(TmplNode p) {
  if (p is AttributeNode) {
    final v = p.value;
    return 'ATTR ${p.name} ${v != null ? enc(v.content) : "noval"} ${loc(p)}';
  }
  final d = p as DirectiveNode;
  final a = d.arg;
  final arg = a is SimpleExpression
      ? '${a.content}${a.static_ ? ":s" : ":d"}'
      : '-';
  final e = d.exp;
  final exp = e is SimpleExpression ? e.content : '-';
  final mods = d.modifiers.map((m) => m.content).join(',');
  return 'DIR ${d.name} raw=${d.rawName} arg=$arg exp=${enc(exp)} mods=[$mods] ${loc(p)}';
}

void walk(TmplNode n, int d, List<String> lines) {
  final pad = '  ' * d;
  if (n is ElementNode) {
    lines.add(
        '${pad}EL ${n.tag} ns=${n.ns} tagType=${n.tagType} self=${n.isSelfClosing ? 1 : 0} ${loc(n)}');
    for (final p in n.props) {
      lines.add('$pad  ${dumpProp(p)}');
    }
    for (final c in n.children) {
      walk(c, d + 1, lines);
    }
  } else if (n is TextNode) {
    lines.add('${pad}TEXT ${enc(n.content)} ${loc(n)}');
  } else if (n is CommentNode) {
    lines.add('${pad}COMMENT ${enc(n.content)} ${loc(n)}');
  } else if (n is InterpolationNode) {
    final c = n.content;
    lines.add(
        '${pad}INTERP ${enc(c is SimpleExpression ? c.content : "<compound>")} ${loc(n)} exp@${c.loc.start.offset}-${c.loc.end.offset}');
  }
}

void main(List<String> args) {
  final list = jsonDecode(File('samples_tmpl.json').readAsStringSync()) as List;
  final e = list.firstWhere((x) => x['name'] == args[0]);
  final sfc = e['sfc'] as String;
  final m = RegExp(r'<template>([\s\S]*)</template>').firstMatch(sfc)!;
  final source = m.group(1)!;
  final root = baseParse(source, domParserOptions());
  final lines = <String>[];
  for (final c in root.children) {
    walk(c, 0, lines);
  }
  print(lines.join('\n'));
}
