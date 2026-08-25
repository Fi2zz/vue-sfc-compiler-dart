// Dart counterpart of tools/batch_dom_ast_official.mjs: parse() each input
// with lib/compiler_dom.dart and serialize the same whitelisted,
// fixed-key-order AST view. See the contract comment there.
import 'dart:convert';
import 'dart:io';
import 'package:vue_sfc_parser/compiler_dom.dart';
import 'package:vue_sfc_parser/template/tmpl_ast.dart';

Map<String, Object?> _loc(TmplLoc loc) => {
  's': [loc.start.offset, loc.start.line, loc.start.column],
  'e': [loc.end.offset, loc.end.line, loc.end.column],
  'src': loc.source,
};

Map<String, Object?> _ser(TmplNode n) {
  final o = <String, Object?>{'type': n.type};
  switch (n.type) {
    case ntRoot:
      n as RootNode;
      o['source'] = n.source;
      o['children'] = [for (final c in n.children) _ser(c)];
    case ntElement:
      n as ElementNode;
      o['tag'] = n.tag;
      o['ns'] = n.ns;
      o['tagType'] = n.tagType;
      if (n.isSelfClosing) o['isSelfClosing'] = true;
      o['props'] = [for (final p in n.props) _ser(p)];
      o['children'] = [for (final c in n.children) _ser(c)];
    case ntText || ntComment:
      o['content'] = (n as dynamic).content as String;
    case ntSimpleExpression:
      n as SimpleExpression;
      o['content'] = n.content;
      o['isStatic'] = n.static_;
      o['constType'] = n.constType;
    case ntInterpolation:
      o['content'] = _ser((n as InterpolationNode).content);
    case ntAttribute:
      n as AttributeNode;
      o['name'] = n.name;
      o['nameLoc'] = _loc(n.nameLoc);
      o['value'] = n.value == null ? null : _ser(n.value!);
    case ntDirective:
      n as DirectiveNode;
      o['name'] = n.name;
      o['rawName'] = n.rawName;
      if (n.exp != null) o['exp'] = _ser(n.exp!);
      if (n.arg != null) o['arg'] = _ser(n.arg!);
      o['modifiers'] = [for (final m in n.modifiers) _ser(m)];
    default:
      throw StateError('unexpected node type ${n.type} in parse output');
  }
  o['loc'] = _loc(n.loc);
  return o;
}

void main(List<String> args) {
  final inputs = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final outDir = args[1];
  Directory(outDir).createSync(recursive: true);
  for (final input in inputs) {
    final id = input['id'] as String;
    String out;
    try {
      out = jsonEncode(_ser(parse(input['source'] as String)));
    } catch (_) {
      out = 'THROW';
    }
    File('$outDir/${id.replaceAll('/', '__')}.txt').writeAsStringSync('$out\n');
  }
  stdout.writeln('done');
}
