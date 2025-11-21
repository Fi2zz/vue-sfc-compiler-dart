import 'package:vue_sfc_parser/sfc_ast.dart';
import 'package:vue_sfc_parser/sfc_module_to_compilation_unit.dart';

List<PropSignature> parseTypeLiteralProps(String body) {
  final out = <PropSignature>[];
  int i = 0;
  while (i < body.length) {
    while (i < body.length && isWhitespace(body.codeUnitAt(i))) {
      i++;
    }
    if (i >= body.length) break;
    final nameStart = i;
    while (i < body.length && isIdentChar(body.codeUnitAt(i))) {
      i++;
    }
    final name = body.substring(nameStart, i);
    while (i < body.length && isWhitespace(body.codeUnitAt(i))) {
      i++;
    }
    bool required = true;
    if (i < body.length && body[i] == '?') {
      required = false;
      i++;
      while (i < body.length && isWhitespace(body.codeUnitAt(i))) {
        i++;
      }
    }
    if (i >= body.length || body[i] != ':') break;
    i++;
    while (i < body.length && isWhitespace(body.codeUnitAt(i))) {
      i++;
    }
    final typeStart = i;
    int depthPar = 0, depthBrack = 0, depthAngle = 0;
    bool inStr = false;
    String quote = '';
    while (i < body.length) {
      final ch = body[i];
      if (inStr) {
        if (ch == quote) inStr = false;
        i++;
        continue;
      }
      if (ch == '\'' || ch == '"') {
        inStr = true;
        quote = ch;
        i++;
        continue;
      }
      if (ch == '(') {
        depthPar++;
        i++;
        continue;
      }
      if (ch == ')') {
        depthPar--;
        i++;
        continue;
      }
      if (ch == '[') {
        depthBrack++;
        i++;
        continue;
      }
      if (ch == ']') {
        depthBrack--;
        i++;
        continue;
      }
      if (ch == '<') {
        depthAngle++;
        i++;
        continue;
      }
      if (ch == '>') {
        depthAngle--;
        i++;
        continue;
      }
      if (ch == ';' && depthPar == 0 && depthBrack == 0 && depthAngle == 0) {
        break;
      }
      i++;
    }
    final typeText = body.substring(typeStart, i).trim();
    out.add(PropSignature(name: name, type: typeText, required: required));
    if (i < body.length && body[i] == ';') i++;
  }
  return out;
}
