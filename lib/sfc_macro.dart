import 'ts_ast.dart';
import 'swc_parser.dart';
import 'swc_ast.dart';

class MacrosParserResult {
  final CompilationUnit compilationUnit;
  final Module rootModule;
  MacrosParserResult(this.compilationUnit, this.rootModule);
}

class Parser {
  static MacrosParserResult parse(String content, {String language = 'ts'}) {
    final sp = SwcParser();
    final Module m = sp.parse(code: content, language: language);
    final cu = _convertSwc(m, content);
    return MacrosParserResult(cu, m);
  }
}

CompilationUnit _convertSwc(Module m, String src) {
  final statements = <ExpressionStatement>[];
  final alias = <String, List<PropSignature>>{};
  for (final item in m.body) {
    if (item is TSTypeAliasDecl) {
      final props = <PropSignature>[];
      for (final p in item.members) {
        props.add(
          PropSignature(name: p.key, type: p.typeAnn, required: !p.optional),
        );
      }
      alias[item.id] = props;
    } else if (item is TSInterfaceDecl) {
      final props = <PropSignature>[];
      for (final p in item.members) {
        props.add(
          PropSignature(name: p.key, type: p.typeAnn, required: !p.optional),
        );
      }
      alias[item.id] = props;
    }
  }
  for (final item in m.body) {
    if (item is VarDeclItem) {
      final declText = src.substring(
        item.node.start.clamp(0, src.length),
        item.node.end.clamp(0, src.length),
      );

      BindingPattern? pat;
      if (item.arrayPattern != null) {
        final els = <ArrayBindingElement>[];
        for (final e in item.arrayPattern!.elements) {
          final id = e.name == null
              ? null
              : Identifier(
                  startByte: item.node.start,
                  endByte: item.node.end,
                  text: e.name!,
                );
          final def = e.defaultText == null
              ? null
              : _parseSimpleExpression(
                  e.defaultText!,
                  item.node.start,
                  item.node.end,
                );
          els.add(
            ArrayBindingElement(
              startByte: item.node.start,
              endByte: item.node.end,
              text: declText,
              target: id,
              defaultValue: def,
              isRest: e.isRest,
              index: e.index,
            ),
          );
        }
        pat = ArrayBindingPattern(
          startByte: item.node.start,
          endByte: item.node.end,
          text: declText,
          elements: els,
          typeIndexMap: const [],
          typeAnnotationText: item.arrayPattern!.patternTypeAnnText,
        );
      } else if (item.objectPattern != null) {
        ObjectBindingPattern buildObj(SWCObjectBindingPattern op) {
          final props = <ObjectBindingProperty>[];
          for (final p in op.properties) {
            final alias = p.alias == null
                ? null
                : Identifier(
                    startByte: item.node.start,
                    endByte: item.node.end,
                    text: p.alias!,
                  );
            final def = p.defaultText == null
                ? null
                : _parseSimpleExpression(
                    p.defaultText!,
                    item.node.start,
                    item.node.end,
                  );
            final nested = p.nested == null ? null : buildObj(p.nested!);
            props.add(
              ObjectBindingProperty(
                startByte: item.node.start,
                endByte: item.node.end,
                text: declText,
                key: p.key,
                alias: alias,
                defaultValue: def,
                nested: nested,
              ),
            );
          }
          return ObjectBindingPattern(
            startByte: item.node.start,
            endByte: item.node.end,
            text: declText,
            properties: props,
            typeKeyMap: const {},
            typeAnnotationText: op.patternTypeAnnText,
          );
        }

        pat = buildObj(item.objectPattern!);
      }

      final varDecl = VariableDeclaration(
        item.initExpr,
        startByte: item.node.start,
        endByte: item.node.end,
        text: declText,
        name: item.nameExpr,
        pattern: pat,
        declKind: item.declKind,
      );

      statements.add(
        ExpressionStatement(
          startByte: item.node.start,
          endByte: item.node.end,
          text: declText,
          expression: varDecl,
        ),
      );

      // Deprecated VariableDeclarator path removed; unified VariableDeclaration only.
    }

    if (item is FnDeclItem) {
      final declText = src.substring(
        item.node.start.clamp(0, src.length),
        item.node.end.clamp(0, src.length),
      );
      final nameId = Identifier(
        startByte: item.node.start,
        endByte: item.node.end,
        text: item.name,
      );
      final varDecl = VariableDeclaration(
        null,
        startByte: item.node.start,
        endByte: item.node.end,
        text: declText,
        name: nameId,
        pattern: null,
      );
      statements.add(
        ExpressionStatement(
          startByte: item.node.start,
          endByte: item.node.end,
          text: declText,
          expression: varDecl,
        ),
      );
    }

    if (item is ClassDeclItem) {
      final declText = src.substring(
        item.node.start.clamp(0, src.length),
        item.node.end.clamp(0, src.length),
      );
      final nameId = Identifier(
        startByte: item.node.start,
        endByte: item.node.end,
        text: item.name,
      );
      final varDecl = VariableDeclaration(
        null,
        startByte: item.node.start,
        endByte: item.node.end,
        text: declText,
        name: nameId,
        pattern: null,
      );
      statements.add(
        ExpressionStatement(
          startByte: item.node.start,
          endByte: item.node.end,
          text: declText,
          expression: varDecl,
        ),
      );
    }

    if (item is CallExpr) {
      final ident = item.calleeIdent ?? '';
      final idExpr = Identifier(
        startByte: item.node.start,
        endByte: item.node.end,
        text: ident,
      );
      final args = <Expression>[];
      for (final a in item.args) {
        final t = a.trim();
        args.add(_parseSimpleExpression(t, item.node.start, item.node.end));
      }
      final argList = ArgumentList(
        startByte: item.node.start,
        endByte: item.node.end,
        text: src.substring(
          item.node.start.clamp(0, src.length),
          item.node.end.clamp(0, src.length),
        ),
        arguments: args,
      );
      final fcall = FunctionCallExpression(
        startByte: item.node.start,
        endByte: item.node.end,
        text: src.substring(
          item.node.start.clamp(0, src.length),
          item.node.end.clamp(0, src.length),
        ),
        methodName: idExpr,
        argumentList: argList,
        typeArgumentText: item.typeArgs == null
            ? null
            : '<${item.typeArgs!.join(', ')}>',
        typeArgumentProps: ident == 'defineProps'
            ? _extractTypePropsFromSwc(item.typeArgs, alias)
            : const [],
      );
      statements.add(
        ExpressionStatement(
          startByte: item.node.start,
          endByte: item.node.end,
          text: fcall.text,
          expression: fcall,
        ),
      );
    }
  }
  return CompilationUnit(
    startByte: 0,
    endByte: src.length,
    text: src,
    statements: statements,
  );
}

List<MapLiteralEntry> _parseObjectElements(String objText) {
  final out = <MapLiteralEntry>[];
  int depth = 0;
  bool inStr = false;
  String quote = '';
  final parts = <String>[];
  final buf = StringBuffer();
  for (int i = 0; i < objText.length; i++) {
    final ch = objText[i];
    if (inStr) {
      buf.write(ch);
      if (ch == quote) inStr = false;
      continue;
    }
    if (ch == '\'' || ch == '"') {
      inStr = true;
      quote = ch;
      buf.write(ch);
      continue;
    }
    if (ch == '{') {
      depth++;
      buf.write(ch);
      continue;
    }
    if (ch == '}') {
      depth--;
      buf.write(ch);
      continue;
    }
    if (ch == ',' && depth == 1) {
      parts.add(buf.toString());
      buf.clear();
      continue;
    }
    buf.write(ch);
  }
  if (buf.isNotEmpty) parts.add(buf.toString());
  for (var p in parts) {
    final kv = p.trim();
    if (kv.isEmpty || kv == '{' || kv == '}') continue;
    final idx = kv.indexOf(':');
    if (idx <= 0) continue;
    var key = kv.substring(0, idx).trim();
    var val = kv.substring(idx + 1).trim();
    if (key.startsWith("'") && key.endsWith("'")) {
      key = key.substring(1, key.length - 1);
    }
    final vexp = _parseSimpleExpression(val.trim(), 0, 0);
    out.add(
      MapLiteralEntry(
        startByte: 0,
        endByte: 0,
        text: kv,
        keyText: key,
        value: vexp,
      ),
    );
  }
  return out;
}

Expression _parseSimpleExpression(String t, int start, int end) {
  if (t == 'null') {
    return NullLiteral(startByte: start, endByte: end, text: t);
  }
  if (t == 'true' || t == 'false') {
    return BooleanLiteral(
      startByte: start,
      endByte: end,
      text: t,
      value: t == 'true',
    );
  }
  if (t.endsWith('n')) {
    final body = t.substring(0, t.length - 1);
    final n = num.tryParse(body);
    if (n != null) {
      return BigIntLiteral(
        startByte: start,
        endByte: end,
        text: t,
        value: BigInt.parse(body),
      );
    }
  }
  if ((t.isNotEmpty) && (num.tryParse(t) != null)) {
    return NumberLiteral(
      startByte: start,
      endByte: end,
      text: t,
      value: num.parse(t),
    );
  }
  if (t.startsWith('"') || t.startsWith('\'')) {
    final sv = t.length >= 2 ? t.substring(1, t.length - 1) : t;
    return StringLiteral(
      startByte: start,
      endByte: end,
      text: t,
      stringValue: sv,
    );
  }
  if (t.startsWith('{') && t.endsWith('}')) {
    final elements = _parseObjectElements(t);
    return SetOrMapLiteral(
      startByte: start,
      endByte: end,
      text: t,
      elements: elements,
    );
  }
  if (t.startsWith('[') && t.endsWith(']')) {
    return ListLiteral(
      startByte: start,
      endByte: end,
      text: t,
      elements: const [],
    );
  }
  return Identifier(startByte: start, endByte: end, text: t);
}

List<PropSignature> _extractTypePropsFromSwc(
  List<String>? typeArgs,
  Map<String, List<PropSignature>> alias,
) {
  final out = <PropSignature>[];
  if (typeArgs == null || typeArgs.isEmpty) return out;
  final raw = typeArgs.first.trim();
  if (_isSimpleIdentifier(raw)) {
    final props = alias[raw];
    if (props != null) out.addAll(props);
    return out;
  }
  final body = _outerBracesBody(raw);
  if (body == null) return out;
  out.addAll(_parseTypeLiteralProps(body));
  return out;
}

bool _isSimpleIdentifier(String s) {
  if (s.isEmpty) return false;
  final c0 = s.codeUnitAt(0);
  final isAlpha =
      (c0 >= 65 && c0 <= 90) || (c0 >= 97 && c0 <= 122) || c0 == 95 || c0 == 36;
  if (!isAlpha) return false;
  for (int i = 1; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    final ok =
        (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        (c >= 48 && c <= 57) ||
        c == 95 ||
        c == 36;
    if (!ok) return false;
  }
  return true;
}

String? _outerBracesBody(String s) {
  int start = -1;
  int end = -1;
  int depth = 0;
  for (int i = 0; i < s.length; i++) {
    final ch = s[i];
    if (ch == '{') {
      if (depth == 0) start = i + 1;
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        end = i;
        break;
      }
    }
  }
  if (start >= 0 && end >= start) return s.substring(start, end);
  return null;
}

List<PropSignature> _parseTypeLiteralProps(String body) {
  final out = <PropSignature>[];
  int i = 0;
  while (i < body.length) {
    while (i < body.length && _isWhitespace(body.codeUnitAt(i))) i++;
    if (i >= body.length) break;
    final nameStart = i;
    while (i < body.length && _isIdentChar(body.codeUnitAt(i))) i++;
    final name = body.substring(nameStart, i);
    while (i < body.length && _isWhitespace(body.codeUnitAt(i))) i++;
    bool required = true;
    if (i < body.length && body[i] == '?') {
      required = false;
      i++;
      while (i < body.length && _isWhitespace(body.codeUnitAt(i))) i++;
    }
    if (i >= body.length || body[i] != ':') break;
    i++;
    while (i < body.length && _isWhitespace(body.codeUnitAt(i))) i++;
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

bool _isWhitespace(int c) {
  return c == 32 || c == 9 || c == 10 || c == 13;
}

bool _isIdentChar(int c) {
  return (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      (c >= 48 && c <= 57) ||
      c == 95 ||
      c == 36;
}
