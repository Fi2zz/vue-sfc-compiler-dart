import 'dart:convert';

import 'ast.dart';
import 'swc_ffi.dart';

Location? _getSourceLocation(Map<String, dynamic> mm) {
  final loc = mm['loc'] as Map<String, dynamic>?;
  final span = mm['span'] as Map<String, dynamic>?;
  final s = loc == null
      ? (mm['loc_start'] as Map<String, dynamic>?)
      : (loc['start'] as Map<String, dynamic>?);
  final e = loc == null
      ? (mm['loc_end'] as Map<String, dynamic>?)
      : (loc['end'] as Map<String, dynamic>?);
  if (s == null || e == null) return null;
  final startIndex =
      (mm['start'] as num?)?.toInt() ??
      (span != null ? (span['start'] as num?)?.toInt() : null) ??
      0;
  final endIndex =
      (mm['end'] as num?)?.toInt() ??
      (span != null ? (span['end'] as num?)?.toInt() : null) ??
      0;
  return Location(
    start: Position(
      line: (s['line'] as num).toInt(),
      column: (s['column'] as num).toInt(),
      index: startIndex,
    ),
    end: Position(
      line: (e['line'] as num).toInt(),
      column: (e['column'] as num).toInt(),
      index: endIndex,
    ),
    filename: '',
  );
}

class SwcParser {
  final SwcFFI _ffi = SwcFFI.load();

  Program parseProgram({required String code, required String language}) =>
      parse(code: code, language: language);
  Program parse({required String code, required String language}) {
    final jsonStr = _ffi.parse(code, language: language, keepComments: true);
    Map<String, dynamic> decoded;
    try {
      decoded = json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      throw StateError('SWC parse error: $e');
    }
    if (decoded.containsKey('error')) {
      throw StateError('SWC parse error: ${decoded['error']}');
    }

    final bodyJson = decoded['body'] as List<dynamic>? ?? const [];
    final commentJson = decoded['comments'] as List<dynamic>? ?? const [];
    List<Statement> body = [];
    List<Comment> comments = [];
    int? firstStart;
    int? lastEnd;
    for (final it in bodyJson) {
      final mm = it as Map<String, dynamic>;
      final s = (mm['start'] as num?)?.toInt();
      final e = (mm['end'] as num?)?.toInt();
      if (s != null) {
        firstStart = (firstStart == null)
            ? s
            : (s < firstStart ? s : firstStart);
      }
      if (e != null) {
        lastEnd = (lastEnd == null) ? e : (e > lastEnd ? e : lastEnd);
      }
    }
    for (final c in commentJson) {
      final cm = c as Map<String, dynamic>;
      final kind = cm['kind'] as String? ?? 'Line';
      final text = cm['text'] as String? ?? '';
      final sp = cm['span'] as Map<String, dynamic>?;
      Location? loc;
      int? cs;
      int? ce;
      if (sp != null) {
        final ls = sp['loc_start'] as Map<String, dynamic>?;
        final le = sp['loc_end'] as Map<String, dynamic>?;
        cs = (sp['start'] as num?)?.toInt();
        ce = (sp['end'] as num?)?.toInt();
        if (ls != null && le != null) {
          loc = Location(
            start: Position(
              line: (ls['line'] as num).toInt(),
              column: (ls['column'] as num).toInt(),
              index: 0,
            ),
            end: Position(
              line: (le['line'] as num).toInt(),
              column: (le['column'] as num).toInt(),
              index: 0,
            ),
            filename: '',
          );
        }
      }
      String? placement;
      if (ce != null && firstStart != null && ce <= firstStart) {
        placement = 'leading';
      } else if (cs != null && lastEnd != null && cs >= lastEnd) {
        placement = 'trailing';
      } else {
        placement = 'inner';
      }
      if (kind == 'Block') {
        comments.add(CommentBlock(value: text, loc: loc, placement: placement));
      } else {
        comments.add(CommentLine(value: text, loc: loc, placement: placement));
      }
    }
    for (final it in bodyJson) {
      final mm = it as Map<String, dynamic>;
      final t = mm['type'] as String?;
      if (t == null) continue;
      switch (t) {
        case 'ImportDeclaration':
          {
            final specs = <Object>[];
            for (final s in (mm['specifiers'] as List<dynamic>? ?? const [])) {
              final sm = s as Map<String, dynamic>;
              final kind = sm['kind'] as String?;
              if (kind == 'Default') {
                specs.add(
                  ImportDefaultSpecifier(
                    local: Identifier(name: sm['local'] as String),
                  ),
                );
              } else if (kind == 'Namespace') {
                specs.add(
                  ImportNamespaceSpecifier(
                    local: Identifier(name: sm['local'] as String),
                  ),
                );
              } else if (kind == 'Named') {
                final importedStr = sm['imported_str'] as String?;
                final importedIdent = sm['imported_ident'] as String?;
                final imported = importedStr != null
                    ? StringLiteral(value: importedStr)
                    : Identifier(
                        name: importedIdent ?? (sm['local'] as String),
                      );
                specs.add(
                  ImportSpecifier(
                    local: Identifier(name: sm['local'] as String),
                    imported: imported,
                    importKind: sm['import_kind'] as String?,
                  ),
                );
              }
            }
            body.add(
              ImportDeclaration(
                specifiers: specs,
                source: StringLiteral(value: mm['src'] as String),
                loc: _getSourceLocation(mm),
              ),
            );
            break;
          }
        case 'ExportNamedDeclaration':
          {
            final specs = <Object>[];
            final decl = mm['declaration'] as Map<String, dynamic>?;
            if (decl != null) {
              final dt = decl['type'] as String?;
              final dn = decl['name'] as String?;
              if (dt == 'FunctionDeclaration' || dt == 'ClassDeclaration') {
                final nm = dn ?? '';
                specs.add(
                  ExportSpecifier(
                    local: Identifier(name: nm),
                    exported: Identifier(name: nm),
                  ),
                );
              }
            }
            for (final s in (mm['specifiers'] as List<dynamic>? ?? const [])) {
              final sm = s as Map<String, dynamic>;
              final kind = sm['kind'] as String?;
              if (kind == 'Named') {
                final local =
                    sm['local_ident'] as String? ??
                    sm['exported_ident'] as String? ??
                    '';
                final exportedStr = sm['exported_str'] as String?;
                final exportedIdent = sm['exported_ident'] as String? ?? local;
                final exported = exportedStr != null
                    ? StringLiteral(value: exportedStr)
                    : Identifier(name: exportedIdent);
                specs.add(
                  ExportSpecifier(
                    local: Identifier(name: local),
                    exported: exported,
                    exportKind: sm['export_kind'] as String?,
                  ),
                );
              } else if (kind == 'NamespaceAlias') {
                specs.add(
                  ExportNamespaceSpecifier(
                    exported: Identifier(name: sm['exported_ident'] as String),
                  ),
                );
              }
            }
            body.add(
              ExportNamedDeclaration(
                declaration: null,
                specifiers: specs,
                source: mm['source'] == null
                    ? null
                    : StringLiteral(value: mm['source'] as String),

                loc: _getSourceLocation(mm),
              ),
            );
            break;
          }
        case 'ExportFunctionDeclaration':
          {
            final name = mm['name'] as String? ?? '';
            body.add(
              ExportNamedDeclaration(
                declaration: null,
                specifiers: [
                  ExportSpecifier(
                    local: Identifier(name: name),
                    exported: Identifier(name: name),
                  ),
                ],
                source: null,

                loc: _getSourceLocation(mm),
              ),
            );
            break;
          }
        case 'ExportClassDeclaration':
          {
            final name = mm['name'] as String? ?? '';
            body.add(
              ExportNamedDeclaration(
                declaration: null,
                specifiers: [
                  ExportSpecifier(
                    local: Identifier(name: name),
                    exported: Identifier(name: name),
                  ),
                ],
                source: null,

                loc: _getSourceLocation(mm),
              ),
            );
            break;
          }
        case 'ExportAllDeclaration':
          {
            final alias = mm['exported_ident'] as String?;
            body.add(
              ExportAllDeclartion(
                source: StringLiteral(value: mm['src'] as String),
                exported: alias == null ? null : Identifier(name: alias),
                loc: _getSourceLocation(mm),
                text: (mm['text'] as String?) ?? '',
              ),
            );
            break;
          }
        case 'ExportDefaultDecl':
        case 'ExportDefaultExpr':
          {
            final props = mm['obj_props'] as List<dynamic>?;
            if (props != null) {
              List<Object> properties = _readObjectProps(props);
              body.add(
                ExportDefaultDeclaration(
                  declaration: ObjectExpression(properties: properties),
                  loc: _getSourceLocation(mm),
                ),
              );
            } else {
              final objSpan = mm['obj_span'] as Map<String, dynamic>?;
              if (objSpan != null) {
                final s = (objSpan['start'] as num).toInt();
                final e = (objSpan['end'] as num).toInt();
                final bytes = utf8.encode(code);
                final ss = s.clamp(0, bytes.length);
                final ee = e.clamp(0, bytes.length);
                final objText = ee <= ss
                    ? ''
                    : utf8.decode(bytes.sublist(ss, ee)).trimRight();
                body.add(
                  ExportDefaultDeclaration(
                    declaration: Identifier(text: objText, name: ''),
                    loc: _getSourceLocation(mm),
                  ),
                );
              } else {
                body.add(
                  ExportDefaultDeclaration(
                    declaration: NullLiteral(),
                    loc: _getSourceLocation(mm),
                  ),
                );
              }
            }
            break;
          }
        case 'ExportDefaultDeclaration':
          {
            body.add(
              ExportDefaultDeclaration(
                declaration: NullLiteral(),
                loc: _getSourceLocation(mm),
              ),
            );
            break;
          }
        case 'VariableDeclaration':
          {
            // ignore: avoid_print
            print('VD keys: ${mm.keys.toList()}');
            final name = mm['name'] as String? ?? '';
            Expression? initExpr;
            final initText = mm['init_text'] as String?;
            final objectPattern = mm['object_pattern'];
            BindingPattern? pattern;
            final initObjectProps = mm['init_object_props'] as List<dynamic>?;
            // ignore: avoid_print
            print(
              'init_object_props type: ${mm['init_object_props']?.runtimeType}',
            );
            // ignore: avoid_print
            print('init_expr_kind: ${mm['init_expr_kind']}');
            // ignore: avoid_print
            if (initObjectProps != null)
              print('init_object_props len: ${initObjectProps.length}');
            if (initObjectProps != null) {
              final properties = _readObjectProps(initObjectProps);
              initExpr = ObjectExpression(properties: properties);
            } else if (objectPattern != null) {
              final props = <ObjectBindingProperty>[];
              final op = objectPattern;
              final list = (op is List)
                  ? op
                  : ((op is Map<String, dynamic>)
                        ? (op['properties'] as List<dynamic>? ?? const [])
                        : const []);
              ObjectBindingPattern? readNested(Object? nested) {
                if (nested == null) return null;
                final list = (nested is List)
                    ? nested
                    : ((nested is Map<String, dynamic>)
                          ? (nested['properties'] as List<dynamic>? ?? const [])
                          : const []);
                final innerProps = <ObjectBindingProperty>[];
                for (final ip in list) {
                  final im = ip as Map<String, dynamic>;
                  final key = im['key'] as String? ?? '';
                  final aliasName = im['alias'] as String?;
                  final defText = im['default_text'] as String?;
                  Identifier? alias = aliasName == null
                      ? null
                      : Identifier(name: aliasName);
                  Expression? def;
                  if (defText != null) {
                    final dt = defText.trim();
                    if (dt == 'null') {
                      def = NullLiteral();
                    } else if (dt == 'true' || dt == 'false') {
                      def = BooleanLiteral(value: dt == 'true');
                    } else if (num.tryParse(dt) != null) {
                      def = NumberLiteral(value: num.parse(dt));
                    } else if ((dt.startsWith('"') && dt.endsWith('"')) ||
                        (dt.startsWith('\'') && dt.endsWith('\''))) {
                      final sv = dt.length >= 2
                          ? dt.substring(1, dt.length - 1)
                          : dt;
                      def = StringLiteral(stringValue: sv);
                    } else {
                      def = Identifier(text: dt, name: dt);
                    }
                  }
                  innerProps.add(
                    ObjectBindingProperty(
                      key: key,
                      alias: alias,
                      defaultValue: def,
                    ),
                  );
                }
                return ObjectBindingPattern(properties: innerProps);
              }

              for (final p in list) {
                final pm = p as Map<String, dynamic>;
                final key = pm['key'] as String? ?? '';
                final aliasName = pm['alias'] as String?;
                final defText = pm['default_text'] as String?;
                final nested = pm['nested'];
                Identifier? alias = aliasName == null
                    ? null
                    : Identifier(name: aliasName);
                Expression? def;
                if (defText != null) {
                  final dt = defText.trim();
                  if (dt == 'null') {
                    def = NullLiteral();
                  } else if (dt == 'true' || dt == 'false') {
                    def = BooleanLiteral(value: dt == 'true');
                  } else if (num.tryParse(dt) != null) {
                    def = NumberLiteral(value: num.parse(dt));
                  } else if ((dt.startsWith('"') && dt.endsWith('"')) ||
                      (dt.startsWith('\'') && dt.endsWith('\''))) {
                    final sv = dt.length >= 2
                        ? dt.substring(1, dt.length - 1)
                        : dt;
                    def = StringLiteral(stringValue: sv);
                  } else {
                    def = Identifier(text: dt, name: dt);
                  }
                }
                final nestedPat = readNested(nested);
                props.add(
                  ObjectBindingProperty(
                    key: key,
                    alias: alias,
                    defaultValue: def,
                    nested: nestedPat,
                  ),
                );
              }
              pattern = ObjectBindingPattern(properties: props);
            } else if (mm['array_pattern'] != null) {
              final elements = <ArrayBindingElement>[];
              final ap = mm['array_pattern'];
              final list = (ap is List)
                  ? ap
                  : ((ap is Map<String, dynamic>)
                        ? (ap['elements'] as List<dynamic>? ?? const [])
                        : const []);
              for (final e in list) {
                final em = e as Map<String, dynamic>;
                final nameEl = em['name'] as String?;
                final defText = em['default_text'] as String?;
                final isRest = em['is_rest'] as bool? ?? false;
                final target = nameEl == null
                    ? Identifier(name: '')
                    : Identifier(name: nameEl);
                Expression? def;
                if (defText != null) {
                  final dt = defText.trim();
                  if (dt == 'null') {
                    def = NullLiteral();
                  } else if (dt == 'true' || dt == 'false') {
                    def = BooleanLiteral(value: dt == 'true');
                  } else if (num.tryParse(dt) != null) {
                    def = NumberLiteral(value: num.parse(dt));
                  } else if ((dt.startsWith('"') && dt.endsWith('"')) ||
                      (dt.startsWith('\'') && dt.endsWith('\''))) {
                    final sv = dt.length >= 2
                        ? dt.substring(1, dt.length - 1)
                        : dt;
                    def = StringLiteral(stringValue: sv);
                  } else {
                    def = Identifier(text: dt, name: dt);
                  }
                }
                elements.add(
                  ArrayBindingElement(
                    target: target,
                    defaultValue: def,
                    isRest: isRest,
                  ),
                );
              }
              pattern = ArrayBindingPattern(elements: elements);
            } else if (initText != null) {
              var itext = initText.trim();
              final initSpan = mm['init_span'] as Map<String, dynamic>?;
              if (initSpan != null) {
                final s = (initSpan['start'] as num).toInt();
                final e = (initSpan['end'] as num).toInt();
                final bytes = utf8.encode(code);
                final ss = s.clamp(0, bytes.length);
                final ee = e.clamp(0, bytes.length);
                itext = ee <= ss
                    ? itext
                    : utf8.decode(bytes.sublist(ss, ee)).trimRight();
                if (itext.endsWith(';')) {
                  itext = itext.substring(0, itext.length - 1);
                }
              }
              final initCallee = mm['init_callee_ident'] as String?;
              if (initCallee != null && initCallee.isNotEmpty) {
                Expression parseValueText(String t) {
                  final tt = t.trim();
                  if (tt == 'null') return NullLiteral();
                  if (tt == 'true' || tt == 'false') {
                    return BooleanLiteral(value: tt == 'true');
                  }
                  final numVal = num.tryParse(tt);
                  if (numVal != null) return NumberLiteral(value: numVal);
                  if ((tt.startsWith('"') && tt.endsWith('"')) ||
                      (tt.startsWith('\'') && tt.endsWith('\''))) {
                    final sv = tt.length >= 2
                        ? tt.substring(1, tt.length - 1)
                        : tt;
                    return StringLiteral(stringValue: sv, text: tt);
                  }
                  return Identifier(text: tt, name: tt);
                }

                final rawArgs = (mm['init_args'] as List<dynamic>? ?? const []);
                final argObjProps =
                    (mm['init_arg_object_props'] as List<dynamic>? ?? const []);
                final args = <Expression>[];
                for (int i = 0; i < rawArgs.length; i++) {
                  final objProps = (i < argObjProps.length)
                      ? (argObjProps[i] as List<dynamic>)
                      : const [];
                  if (objProps.isNotEmpty) {
                    final entries = <MapLiteralEntry>[];
                    for (final kv in objProps) {
                      final km = kv as Map<String, dynamic>;
                      final keyText = km['key'] as String? ?? '';
                      final valText = km['value_text'] as String? ?? '';
                      entries.add(
                        MapLiteralEntry(
                          keyText: keyText,
                          value: parseValueText(valText),
                        ),
                      );
                    }
                    args.add(SetOrMapLiteral(elements: entries));
                  } else {
                    final t = (rawArgs[i] as String).trim();
                    args.add(parseValueText(t));
                  }
                }

                final fcall = FunctionCallExpression(
                  methodName: Identifier(name: initCallee),
                  argumentList: ArgumentList(arguments: args),
                  typeArgumentText: mm['init_type_argument_text'] as String?,
                  text: itext,
                );
                initExpr = fcall;
              } else {
                if (itext == 'null') {
                  initExpr = NullLiteral();
                } else if (itext == 'true' || itext == 'false') {
                  initExpr = BooleanLiteral(value: itext == 'true');
                } else if (num.tryParse(itext) != null) {
                  initExpr = NumberLiteral(value: num.parse(itext));
                } else {
                  print('$name $itext');
                  initExpr = Identifier(text: itext, name: itext);
                }
              }
            }

            final v = VariableDeclaration(
              initExpr,
              name: Identifier(name: name),
              declKind: (mm['decl_kind'] as String?) ?? 'const',
              pattern: pattern,
              extra: {
                if (mm['init_type_argument_text'] != null)
                  'init_type_argument_text': mm['init_type_argument_text'],
                if (mm['init_type_arg_kinds'] != null)
                  'init_type_arg_kinds': mm['init_type_arg_kinds'],
                if (mm['init_type_ref_idents'] != null)
                  'init_type_ref_idents': mm['init_type_ref_idents'],
                if (mm['init_type_literal_props'] != null)
                  'init_type_literal_props': mm['init_type_literal_props'],
                if (mm['init_type_union_components'] != null)
                  'init_type_union_components':
                      mm['init_type_union_components'],
                'init_typeParameters': _buildTypeParams(mm, prefix: 'init_'),
                if (mm['init_args'] != null) 'init_args': mm['init_args'],
                if (mm['init_arg_object_props'] != null)
                  'init_arg_object_props': mm['init_arg_object_props'],
                if (mm['init_callee_ident'] != null)
                  'init_callee_ident': mm['init_callee_ident'],
              },
            );
            body.add(
              ExpressionStatement(
                expression: v,
                declaration: v,
                loc: _getSourceLocation(mm),
              ),
            );
            break;
          }
        case 'CallExpression':
          {
            String callee = (mm['callee_ident'] as String?) ?? '';
            final text = mm['text'] as String?;
            if ((callee.isEmpty) && text != null && text.isNotEmpty) {
              final s = text.trim();
              final dot = s.lastIndexOf('.');
              if (dot >= 0) {
                final tail = s.substring(dot + 1);
                final par = tail.indexOf('(');
                callee = par >= 0 ? tail.substring(0, par) : tail;
              } else {
                final par = s.indexOf('(');
                callee = par >= 0 ? s.substring(0, par) : s;
              }
            }
            List<dynamic> rawArgs = (mm['args'] as List<dynamic>? ?? const []);
            List<dynamic> argObjProps =
                (mm['arg_object_props'] as List<dynamic>? ?? const []);
            Expression parseValueText(String t) {
              final tt = t.trim();
              if (tt == 'null') return NullLiteral();
              if (tt == 'true' || tt == 'false') {
                return BooleanLiteral(value: tt == 'true');
              }
              final numVal = num.tryParse(tt);
              if (numVal != null) return NumberLiteral(value: numVal);
              if ((tt.startsWith('"') && tt.endsWith('"')) ||
                  (tt.startsWith('\'') && tt.endsWith('\''))) {
                final sv = tt.length >= 2 ? tt.substring(1, tt.length - 1) : tt;
                return StringLiteral(stringValue: sv, text: tt);
              }
              return Identifier(text: tt, name: tt);
            }

            final args = <Expression>[];
            for (int i = 0; i < rawArgs.length; i++) {
              final objProps = (i < argObjProps.length)
                  ? argObjProps[i] as List<dynamic>
                  : const [];
              if (objProps.isNotEmpty) {
                final elements = <MapLiteralEntry>[];
                for (final kv in objProps) {
                  final km = kv as Map<String, dynamic>;
                  final kind = km['kind'] as String? ?? 'KeyValue';
                  if (kind == 'KeyValue') {
                    final keyKind = km['key_kind'] as String?;
                    final computed = km['computed'] as bool? ?? false;
                    final keyText = km['key_text'] as String? ?? '';
                    final valueKind = km['value_kind'] as String?;
                    final valueText = km['value_text'] as String? ?? '';
                    final func = km['func'] as Map<String, dynamic>?;
                    Object key;
                    if (computed) {
                      key = Identifier(
                        text: km['key_expr_text'] as String? ?? '',
                        name: extractIdentifierName(
                          km['key_expr_text'] as String? ?? '',
                        ),
                      );
                    } else {
                      key = Identifier(name: keyText);
                      if (keyKind == 'String')
                        key = StringLiteral(stringValue: keyText);
                      if (keyKind == 'Numeric')
                        key = NumericLiteral(value: num.tryParse(keyText) ?? 0);
                      if (keyKind == 'BigInt')
                        key = BigIntLiteral(value: keyText);
                    }
                    Expression value;
                    if (func != null) {
                      final isAsync = func['async'] as bool? ?? false;
                      final isGen = func['generator'] as bool? ?? false;
                      final params = _readParams(
                        func['params'] as List<dynamic>? ?? const [],
                      );
                      final txt = func['text'] as String?;
                      if (isGen) {
                        value = FunctionExpression(
                          id: null,
                          params: params,
                          body: const BlockStatement(body: [], directives: []),
                          generator: true,
                          async: isAsync,
                          text: txt ?? '',
                        );
                      } else {
                        value = ArrowFunctionExpression(
                          params: params,
                          body: const BlockStatement(body: [], directives: []),
                          async: isAsync,
                          expression: false,
                          text: txt ?? '',
                        );
                      }
                    } else {
                      if (valueKind == 'String') {
                        value = StringLiteral(stringValue: valueText);
                      } else if (valueKind == 'Number') {
                        value = NumericLiteral(
                          value: num.tryParse(valueText) ?? 0,
                        );
                      } else if (valueKind == 'Boolean') {
                        value = BooleanLiteral(value: valueText == 'true');
                      } else if (valueKind == 'Null') {
                        value = const NullLiteral();
                      } else {
                        value = parseValueText(valueText);
                      }
                    }
                    elements.add(
                      MapLiteralEntry(
                        keyText: keyText,
                        value: value,
                        extra: {
                          'kind': 'KeyValue',
                          if (km['op'] != null) 'op': km['op'],
                        },
                      ),
                    );
                  } else if (kind == 'Method' ||
                      kind == 'Getter' ||
                      kind == 'Setter') {
                    final func =
                        km['func'] as Map<String, dynamic>? ?? const {};
                    final isAsync = func['async'] as bool? ?? false;
                    final isGen = func['generator'] as bool? ?? false;
                    final params = _readParams(
                      func['params'] as List<dynamic>? ?? const [],
                    );
                    final txt = func['text'] as String?;
                    final keyText = km['key_text'] as String? ?? '';
                    final Expression value = isGen
                        ? FunctionExpression(
                            id: null,
                            params: params,
                            body: const BlockStatement(
                              body: [],
                              directives: [],
                            ),
                            generator: true,
                            async: isAsync,
                            text: txt ?? '',
                          )
                        : ArrowFunctionExpression(
                            params: params,
                            body: const BlockStatement(
                              body: [],
                              directives: [],
                            ),
                            async: isAsync,
                            expression: false,
                            text: txt ?? '',
                          );
                    elements.add(
                      MapLiteralEntry(
                        keyText: keyText,
                        value: value,
                        extra: {'kind': kind},
                      ),
                    );
                  } else if (kind == 'Spread') {
                    // 忽略 Spread（SetOrMapLiteral 不支持）。
                  }
                }
                args.add(SetOrMapLiteral(elements: elements));
              } else {
                final t = (rawArgs[i] as String).trim();
                args.add(parseValueText(t));
              }
            }
            final argList = ArgumentList(arguments: args);

            // print('callee $callee $argList');
            final fcall = FunctionCallExpression(
              methodName: Identifier(name: callee),
              argumentList: argList,
              typeArgumentText: mm['type_argument_text'] as String?,
              text: text,
              extra: {
                if (mm['type_union_components'] != null)
                  'type_union_components': mm['type_union_components'],
                'typeParameters': _buildTypeParams(mm, prefix: ''),
              },
            );
            body.add(
              ExpressionStatement(
                expression: fcall,
                loc: _getSourceLocation(mm),
                text: text,
              ),
            );
            break;
          }
        case 'FunctionDeclaration':
          {
            final name = mm['name'] as String? ?? '';
            final text = mm['text'] as String?;
            body.add(
              FunctionDeclaration(
                id: Identifier(name: name),
                params: const [],
                body: const BlockStatement(body: [], directives: []),
                generator: (mm['generator'] as bool?) ?? false,
                async: (mm['async'] as bool?) ?? false,
                loc: _getSourceLocation(mm),
                text: text ?? '',
              ),
            );
            break;
          }
        case 'ClassDeclaration':
          {
            body.add(
              ExpressionStatement(
                expression: Identifier(name: mm['name'] as String),
                loc: _getSourceLocation(mm),
              ),
            );
            break;
          }
        default:
          break;
      }
    }
    return Program(
      body: body,
      directives: const [],
      sourceType: 'module',
      comments: comments,
    );
  }

  TSTypeParameterInstantiation? _buildTypeParams(
    Map<String, dynamic> mm, {
    required String prefix,
  }) {
    final kinds =
        mm['${prefix}type_arg_kinds'] as List<dynamic>? ??
        mm['type_arg_kinds'] as List<dynamic>?;
    final names =
        mm['${prefix}type_parameters'] as List<dynamic>? ??
        mm['type_parameters'] as List<dynamic>?;
    final unions =
        mm['${prefix}type_union_components'] as List<dynamic>? ??
        mm['type_union_components'] as List<dynamic>?;
    final unionsStruct =
        mm['${prefix}type_union_components_struct'] as List<dynamic>? ??
        mm['type_union_components_struct'] as List<dynamic>?;
    final literalProps =
        mm['${prefix}type_literal_props'] as List<dynamic>? ??
        mm['type_literal_props'] as List<dynamic>?;
    if (kinds == null || names == null) return null;
    final params = <TSType>[];
    for (int i = 0; i < kinds.length; i++) {
      final k = kinds[i] as String? ?? 'other';
      if (k == 'union') {
        final types = <TSType>[];
        if (unionsStruct != null && i < unionsStruct.length) {
          final list = unionsStruct[i] as List<dynamic>;
          for (final e in list) {
            types.add(_unionStructItemToType(e as Map<String, dynamic>));
          }
        } else {
          final comps = unions != null && i < unions.length
              ? unions[i] as List<dynamic>
              : const [];
          for (final c in comps) {
            final s = (c as String).trim();
            if (s == 'string') {
              types.add(const TSStringKeyword());
            } else if (s == 'number') {
              types.add(const TSNumberKeyword());
            } else if (s == 'boolean') {
              types.add(const TSBooleanKeyword());
            } else if (s == 'null') {
              types.add(const TSNullKeyword());
            } else if (s == 'undefined') {
              types.add(const TSUndefinedKeyword());
            } else if (s.startsWith('{')) {
              types.add(TSLiteralType(text: s));
            } else if ((s.startsWith('"') && s.endsWith('"')) ||
                (s.startsWith('\'') && s.endsWith('\''))) {
              types.add(TSLiteralType(text: s));
            } else if (s == 'true' || s == 'false') {
              types.add(TSLiteralType(text: s));
            } else if (num.tryParse(s) != null) {
              types.add(TSLiteralType(text: s));
            } else if (s.endsWith('[]')) {
              final et = s.substring(0, s.length - 2).trim();
              types.add(TSArrayType(elementType: _parseTypeFromText(et)));
            } else if (s.startsWith('Array<') && s.endsWith('>')) {
              final et = s.substring(6, s.length - 1).trim();
              types.add(TSArrayType(elementType: _parseTypeFromText(et)));
            } else if (s.startsWith('[') && s.endsWith(']')) {
              final inner = s.substring(1, s.length - 1);
              final List<TSType> els = inner
                  .split(',')
                  .map((e) => _parseTypeFromText(e.trim()))
                  .toList()
                  .cast<TSType>();
              types.add(TSTupleType(elementTypes: els));
            } else {
              types.add(TSTypeReference(name: extractIdentifierName(s)));
            }
          }
        }
        params.add(TSUnionType(types: types));
      } else if (k == 'type_ref') {
        final nm = (i < names.length) ? (names[i] as String? ?? '') : '';
        params.add(TSTypeReference(name: extractIdentifierName(nm)));
      } else if (k == 'type_literal') {
        final memList = (literalProps != null && i < literalProps.length)
            ? (literalProps[i] as List<dynamic>)
            : const [];
        params.add(TSObjectType(members: _membersFromStruct(memList)));
      } else {
        final nm = (i < names.length) ? (names[i] as String? ?? '') : '';
        params.add(TSLiteralType(text: nm));
      }
    }
    return TSTypeParameterInstantiation(params: params);
  }

  TSType _parseTypeFromText(String s) {
    final t = s.trim();
    if (t.isEmpty) return const TSAnyKeyword();
    if (t == 'string') return TSStringKeyword();
    if (t == 'number') return TSNumberKeyword();
    if (t == 'boolean') return TSBooleanKeyword();
    if (t == 'null') return TSNullKeyword();
    if (t == 'undefined') return TSUndefinedKeyword();
    if (t.endsWith('[]')) {
      final et = t.substring(0, t.length - 2).trim();
      return TSArrayType(elementType: _parseTypeFromText(et));
    }
    if (t.startsWith('Array<') && t.endsWith('>')) {
      final et = t.substring(6, t.length - 1).trim();
      return TSArrayType(elementType: _parseTypeFromText(et));
    }
    if (t.startsWith('(') && t.endsWith(')')) {
      final inner = t.substring(1, t.length - 1);
      return TSParenthesizedType(type: _parseTypeFromText(inner));
    }
    if (t.startsWith('[') && t.endsWith(']')) {
      final inner = t.substring(1, t.length - 1);
      final parts = inner
          .split(',')
          .map((e) => _parseTypeFromText(e.trim()))
          .toList();
      return TSTupleType(elementTypes: parts);
    }
    final lb = t.indexOf('[');
    if (lb > 0 && t.endsWith(']')) {
      final obj = t.substring(0, lb).trim();
      final idx = t.substring(lb + 1, t.length - 1).trim();
      return TSIndexedAccessType(
        objectType: _parseTypeFromText(obj),
        indexType: _parseTypeFromText(idx),
      );
    }
    if (t.startsWith('{')) return TSLiteralType(text: t);
    // Mapped type / Index signature detection from text
    if (t.startsWith('{') && t.endsWith('}')) {
      final inner = t.substring(1, t.length - 1).trim();
      // detect mapped: starts with optional 'readonly ' then '[' then ' in '
      final ro = inner.startsWith('readonly ');
      final trimmed = ro ? inner.substring('readonly '.length).trim() : inner;
      final lb = trimmed.indexOf('[');
      final rb = trimmed.indexOf(']');
      if (lb == 0 && rb > lb) {
        final bracket = trimmed.substring(lb + 1, rb);
        final inPos = bracket.indexOf(' in ');
        if (inPos > 0) {
          final paramName = bracket.substring(0, inPos).trim();
          final srcText = bracket.substring(inPos + 4).trim();
          // after ']' expect ':', with optional '?'
          final after = trimmed.substring(rb + 1).trim();
          final opt = after.startsWith('?');
          final colonPos = after.indexOf(':');
          if (colonPos >= 0) {
            final valText = after.substring(colonPos + 1).trim();
            return TSMappedType(
              paramName: paramName,
              sourceType: _parseTypeFromText(srcText),
              valueType: _parseTypeFromText(valText),
              readonly: ro,
              optional: opt,
            );
          }
        } else {
          // index signature: inside bracket like 'key: string'
          final colonPos = bracket.indexOf(':');
          if (colonPos > 0) {
            final keyName = bracket.substring(0, colonPos).trim();
            final keyTypeText = bracket.substring(colonPos + 1).trim();
            // after ']' expect ':' value type
            final after = trimmed.substring(rb + 1).trim();
            final cpos = after.indexOf(':');
            if (cpos >= 0) {
              final valueText = after.substring(cpos + 1).trim();
              return TSIndexSignature(
                keyName: keyName,
                keyType: _parseTypeFromText(keyTypeText),
                valueType: _parseTypeFromText(valueText),
              );
            }
          }
        }
      }
    }
    if (t.contains('|')) {
      final parts = t
          .split('|')
          .map((e) => _parseTypeFromText(e.trim()))
          .toList();
      return TSUnionType(types: parts);
    }
    if (t.startsWith('keyof ')) {
      final at = t.substring(6).trim();
      return TSKeyofType(argument: _parseTypeFromText(at));
    }
    if (t.contains(' extends ') && t.contains(' ? ') && t.contains(' : ')) {
      final parts = t.split(' extends ');
      if (parts.length >= 2) {
        final check = parts[0].trim();
        final rest = parts.sublist(1).join(' extends ');
        final qpos = rest.indexOf(' ? ');
        final lastColon = rest.lastIndexOf(' : ');
        if (qpos >= 0 && lastColon > qpos) {
          final ext = rest.substring(0, qpos).trim();
          final tru = rest.substring(qpos + 3, lastColon).trim();
          final fal = rest.substring(lastColon + 3).trim();
          return TSConditionalType(
            checkType: _parseTypeFromText(check),
            extendsType: _parseTypeFromText(ext),
            trueType: _parseTypeFromText(tru),
            falseType: _parseTypeFromText(fal),
          );
        }
      }
    }
    if (t.contains('&')) {
      final parts = t
          .split('&')
          .map((e) => _parseTypeFromText(e.trim()))
          .toList();
      return TSIntersectionType(types: parts);
    }
    return TSTypeReference(name: extractIdentifierName(t));
  }

  List<TSPropertySignature> _membersFromStruct(List<dynamic> mems) {
    final members = <TSPropertySignature>[];
    for (final mmbr in mems) {
      final mmj = mmbr as Map<String, dynamic>;
      String key = mmj['key'] as String? ?? '';
      final optional = mmj['optional'] as bool? ?? false;
      final typeAnnText = mmj['type_ann'] as String?;
      final indexKeyName = mmj['index_key_name'] as String?;
      final indexKeyAnn = mmj['index_key_ann'] as String?;
      final mappedParam = mmj['mapped_param'] as String?;
      final mappedSrc = mmj['mapped_source_text'] as String?;
      if (indexKeyName != null) {
        final kt = (indexKeyAnn ?? '').trim();
        key = '[' + indexKeyName + (kt.isEmpty ? '' : ': ' + kt) + ']';
      } else if (mappedParam != null) {
        final src = (mappedSrc ?? '').trim();
        key = '[' + mappedParam + (src.isEmpty ? '' : ' in ' + src) + ']';
      }
      TSType? tt;
      if (typeAnnText != null && typeAnnText.isNotEmpty) {
        final s = typeAnnText.trim();
        if (s == 'string')
          tt = TSStringKeyword();
        else if (s == 'number')
          tt = TSNumberKeyword();
        else if (s == 'boolean')
          tt = TSBooleanKeyword();
        else if (s == 'null')
          tt = TSNullKeyword();
        else if (s == 'undefined')
          tt = TSUndefinedKeyword();
        else if (s.startsWith('{')) {
          final tstruct = mmj['type_ann_struct'] as Map<String, dynamic>?;
          final smems = tstruct == null
              ? const []
              : (tstruct['members'] as List<dynamic>? ?? const []);
          tt = TSObjectType(members: _membersFromStruct(smems));
        } else {
          tt = TSTypeReference(name: extractIdentifierName(s));
        }
      }
      members.add(
        TSPropertySignature(
          key: Identifier(name: key),
          optional: optional,
          typeAnnotation: tt == null
              ? null
              : TSTypeAnnotation(typeAnnotation: tt),
        ),
      );
    }
    return members;
  }

  TSType _unionStructItemToType(Map<String, dynamic> m) {
    final kind = m['kind'] as String? ?? 'other';
    switch (kind) {
      case 'string_keyword':
        return const TSStringKeyword();
      case 'number_keyword':
        return const TSNumberKeyword();
      case 'boolean_keyword':
        return const TSBooleanKeyword();
      case 'null_keyword':
        return const TSNullKeyword();
      case 'undefined_keyword':
        return const TSUndefinedKeyword();
      case 'array':
        return TSArrayType(
          elementType: _parseTypeFromText((m['element_text'] as String?) ?? ''),
          readonly: (m['readonly'] as bool?) ?? false,
        );
      case 'tuple':
        return TSTupleType(
          elementTypes: (m['elements'] as List<dynamic>? ?? const [])
              .map((e) => _parseTypeFromText(e as String))
              .toList(),
        );
      case 'indexed_access':
        return TSIndexedAccessType(
          objectType: _parseTypeFromText((m['object_text'] as String?) ?? ''),
          indexType: _parseTypeFromText((m['index_text'] as String?) ?? ''),
        );
      case 'intersection':
        return TSIntersectionType(
          types: (m['elements'] as List<dynamic>? ?? const [])
              .map((e) => _parseTypeFromText(e as String))
              .toList(),
        );
      case 'keyof':
        return TSKeyofType(
          argument: _parseTypeFromText((m['arg_text'] as String?) ?? ''),
        );
      case 'conditional':
        return TSConditionalType(
          checkType: _parseTypeFromText((m['check_text'] as String?) ?? ''),
          extendsType: _parseTypeFromText((m['extends_text'] as String?) ?? ''),
          trueType: _parseTypeFromText((m['true_text'] as String?) ?? ''),
          falseType: _parseTypeFromText((m['false_text'] as String?) ?? ''),
        );
      case 'infer':
        final cons = (m['constraint_text'] as String?) ?? '';
        return TSInferType(
          name: (m['param_name'] as String?) ?? '',
          constraint: cons.isEmpty ? null : _parseTypeFromText(cons),
        );
      case 'object_literal':
        return TSObjectType(
          members: _membersFromStruct(
            m['members'] as List<dynamic>? ?? const [],
          ),
        );
      case 'string_literal':
      case 'boolean_literal':
      case 'number_literal':
        return TSLiteralType(text: (m['text'] as String?) ?? '');
      case 'type_ref':
        return TSTypeReference(
          name: extractIdentifierName((m['name'] as String?) ?? ''),
        );
      default:
        return TSLiteralType(text: (m['text'] as String?) ?? '');
    }
  }

  Object _readKey(Map<String, dynamic> pm) {
    final kind = pm['key_kind'] as String?;
    final computed = pm['computed'] as bool? ?? false;
    if (computed) {
      final t = pm['key_expr_text'] as String? ?? '';
      return Identifier(text: t, name: extractIdentifierName(t));
    }
    switch (kind) {
      case 'Ident':
        return Identifier(name: (pm['key_text'] as String?) ?? '');
      case 'String':
        return StringLiteral(stringValue: (pm['key_text'] as String?) ?? '');
      case 'Numeric':
        final tx = (pm['key_text'] as String?) ?? '';
        final nv = num.tryParse(tx) ?? 0;
        return NumericLiteral(value: nv);
      case 'BigInt':
        return BigIntLiteral(value: (pm['key_text'] as String?) ?? '');
      default:
        final t = (pm['key_text'] as String?) ?? '';
        return Identifier(text: t, name: extractIdentifierName(t));
    }
  }

  List<Object> _readObjectProps(List<dynamic> props) {
    final out = <Object>[];
    for (final p in props) {
      final pm = p as Map<String, dynamic>;
      final kind = pm['kind'] as String? ?? 'KeyValue';
      final key = _readKey(pm);
      final computed = (pm['computed'] as bool?) ?? false;
      if (kind == 'KeyValue') {
        final vk = pm['value_kind'] as String?;
        final vt = pm['value_text'] as String?;
        Expression? val;
        if (vk != null) {
          switch (vk) {
            case 'String':
              val = StringLiteral(stringValue: vt ?? '');
              break;
            case 'Number':
              final nv = num.tryParse(vt ?? '0') ?? 0;
              val = NumericLiteral(value: nv);
              break;
            case 'Boolean':
              val = BooleanLiteral(value: (vt == 'true'));
              break;
            case 'Null':
              val = const NullLiteral();
              break;
          }
        }
        final fn = pm['func'] as Map<String, dynamic>?;
        if (fn != null) {
          final params = _readParams(
            fn['params'] as List<dynamic>? ?? const [],
          );
          final isAsync = fn['async'] as bool? ?? false;
          final isGen = fn['generator'] as bool? ?? false;
          final txt = fn['text'] as String?;
          final bodyStmts = _readStmts(
            fn['body_stmts'] as List<dynamic>? ?? const [],
          );
          final bodyExprText = fn['body_expr_text'] as String?;
          if (isGen) {
            val = FunctionExpression(
              id: null,
              params: params,
              body: BlockStatement(body: bodyStmts, directives: const []),
              generator: true,
              async: isAsync,
              text: txt ?? '',
            );
          } else {
            Object bodyNode;
            if (bodyExprText != null && bodyExprText.isNotEmpty) {
              bodyNode = _parseValueText(bodyExprText);
            } else {
              bodyNode = BlockStatement(body: bodyStmts, directives: const []);
            }
            val = ArrowFunctionExpression(
              params: params,
              body: bodyNode,
              async: isAsync,
              expression: bodyNode is! BlockStatement,
              text: txt ?? '',
            );
          }
        }
        out.add(
          ObjectProperty(
            key: key,
            value: val ?? Identifier(name: ''),
            computed: computed,
            shorthand: false,
          ),
        );
      } else if (kind == 'Method' || kind == 'Getter' || kind == 'Setter') {
        final fn = pm['func'] as Map<String, dynamic>? ?? const {};
        final isAsync = fn['async'] as bool? ?? false;
        final isGen = fn['generator'] as bool? ?? false;
        final params = _readParams(fn['params'] as List<dynamic>? ?? const []);
        final txt = fn['text'] as String?;
        final bodyStmtsJson = fn['body_stmts'] as List<dynamic>? ?? const [];
        final bodyStmts = _readStmts(bodyStmtsJson);
        out.add(
          ObjectMethod(
            kind: kind == 'Method'
                ? 'method'
                : (kind == 'Getter' ? 'get' : 'set'),
            key: key,
            params: params,
            body: BlockStatement(body: bodyStmts, directives: const []),
            computed: computed,
            generator: isGen,
            async: isAsync,
            extra: txt == null ? null : {'text': txt},
          ),
        );
      } else if (kind == 'Spread') {
        final at = pm['arg_text'] as String? ?? '';
        final arg = Identifier(text: at, name: extractIdentifierName(at));
        out.add(SpreadElement(argument: arg));
      }
    }
    return out;
  }

  List<Object> _readParams(List<dynamic> params) {
    final out = <Object>[];
    for (final p in params) {
      final pm = p as Map<String, dynamic>;
      final k = pm['param_kind'] as String? ?? 'ident';
      if (k == 'ident') {
        out.add(Identifier(name: (pm['name'] as String?) ?? ''));
      } else if (k == 'rest') {
        out.add(
          RestElement(
            argument: Identifier(name: (pm['name'] as String?) ?? ''),
          ),
        );
      } else if (k == 'object') {
        final props = <Object>[];
        for (final ip in (pm['properties'] as List<dynamic>? ?? const [])) {
          final im = ip as Map<String, dynamic>;
          final keyName = (im['key'] as String?) ?? '';
          final aliasName = im['alias'] as String? ?? keyName;
          final defText = im['default_text'] as String?;
          final nested = im['nested'];
          Object val;
          if (nested is Map<String, dynamic>) {
            val = _paramToPattern(nested);
          } else if (defText != null) {
            val = AssignmentPattern(
              left: Identifier(name: aliasName),
              right: _parseValueText(defText),
            );
          } else {
            val = Identifier(name: aliasName);
          }
          props.add(
            ObjectProperty(
              key: Identifier(name: keyName),
              value: val,
              computed: false,
              shorthand: aliasName == keyName,
            ),
          );
        }
        out.add(ObjectPattern(properties: props));
      } else if (k == 'array') {
        final elems = <Object?>[];
        for (final el in (pm['elements'] as List<dynamic>? ?? const [])) {
          if (el is Map<String, dynamic>) {
            elems.add(_paramToPattern(el));
          } else {
            elems.add(null);
          }
        }
        out.add(ArrayPattern(elements: elems));
      } else if (k == 'assign') {
        final left = pm['left'] as Map<String, dynamic>? ?? const {};
        final defText = pm['default_text'] as String? ?? '';
        out.add(
          AssignmentPattern(
            left: _paramToPattern(left),
            right: _parseValueText(defText),
          ),
        );
      } else {
        final t = pm['text'] as String? ?? '';
        out.add(Identifier(text: t, name: extractIdentifierName(t)));
      }
    }
    return out;
  }

  List<Statement> _readStmts(List<dynamic> stmts) {
    final out = <Statement>[];
    for (final s in stmts) {
      final sm = s as Map<String, dynamic>;
      final t = sm['type'] as String? ?? '';
      switch (t) {
        case 'VariableDeclaration':
          {
            final name = sm['name'] as String? ?? '';
            final initText = sm['init_text'] as String?;
            Expression? init;
            if (initText != null) init = _parseValueText(initText);
            final v = VariableDeclaration(
              init,
              name: Identifier(name: name),
              declKind: (sm['decl_kind'] as String?) ?? 'const',
            );
            out.add(ExpressionStatement(expression: v, declaration: v));
            break;
          }
        case 'CallExpression':
          {
            String callee = (sm['callee_ident'] as String?) ?? '';
            final rawArgs = (sm['args'] as List<dynamic>? ?? const []);
            final args = <Expression>[];
            for (final a in rawArgs) {
              args.add(_parseValueText(a as String));
            }
            final fcall = FunctionCallExpression(
              methodName: Identifier(name: callee),
              argumentList: ArgumentList(arguments: args),
            );
            out.add(ExpressionStatement(expression: fcall));
            break;
          }
        case 'ReturnStatement':
          {
            final ttext = sm['arg_text'] as String?;
            final arg = ttext == null ? null : _parseValueText(ttext);
            out.add(ReturnStatement(argument: arg));
            break;
          }
        case 'BreakStatement':
          {
            final label = sm['label'] as String?;
            out.add(
              BreakStatement(
                label: label == null ? null : Identifier(name: label),
              ),
            );
            break;
          }
        case 'ContinueStatement':
          {
            final label = sm['label'] as String?;
            out.add(
              ContinueStatement(
                label: label == null ? null : Identifier(name: label),
              ),
            );
            break;
          }
        case 'IfStatement':
          {
            final testText = sm['test_text'] as String? ?? '';
            final cons = _readStmts(
              sm['consequent_stmts'] as List<dynamic>? ?? const [],
            );
            final alt = _readStmts(
              sm['alternate_stmts'] as List<dynamic>? ?? const [],
            );
            out.add(
              IfStatement(
                test: _parseValueText(testText),
                consequent: BlockStatement(body: cons, directives: const []),
                alternate: alt.isEmpty
                    ? null
                    : BlockStatement(body: alt, directives: const []),
              ),
            );
            break;
          }
        case 'ForStatement':
          {
            final initText = sm['init_text'] as String?;
            final testText = sm['test_text'] as String?;
            final updateText = sm['update_text'] as String?;
            final body = _readStmts(
              sm['body_stmts'] as List<dynamic>? ?? const [],
            );
            out.add(
              ForStatement(
                init: initText == null
                    ? null
                    : Identifier(
                        text: initText,
                        name: extractIdentifierName(initText),
                      ),
                test: testText == null ? null : _parseValueText(testText),
                update: updateText == null ? null : _parseValueText(updateText),
                body: BlockStatement(body: body, directives: const []),
              ),
            );
            break;
          }
        case 'WhileStatement':
          {
            final testText = sm['test_text'] as String? ?? '';
            final body = _readStmts(
              sm['body_stmts'] as List<dynamic>? ?? const [],
            );
            out.add(
              WhileStatement(
                test: _parseValueText(testText),
                body: BlockStatement(body: body, directives: const []),
              ),
            );
            break;
          }
        case 'SwitchStatement':
          {
            final testText = sm['test_text'] as String? ?? '';
            final casesJson = sm['cases'] as List<dynamic>? ?? const [];
            final cases = <SwitchCase>[];
            for (final c in casesJson) {
              final cm = c as Map<String, dynamic>;
              final tt = cm['test_text'] as String?;
              final cons = _readStmts(
                cm['consequent_stmts'] as List<dynamic>? ?? const [],
              );
              cases.add(
                SwitchCase(
                  test: tt == null ? null : _parseValueText(tt),
                  consequent: cons,
                ),
              );
            }
            out.add(
              SwitchStatement(
                discriminant: _parseValueText(testText),
                cases: cases,
              ),
            );
            break;
          }
        case 'ThrowStatement':
          {
            final argText = sm['arg_text'] as String? ?? '';
            out.add(ThrowStatement(argument: _parseValueText(argText)));
            break;
          }
        case 'DoWhileStatement':
          {
            final testText = sm['test_text'] as String? ?? '';
            final body = _readStmts(
              sm['body_stmts'] as List<dynamic>? ?? const [],
            );
            out.add(
              DoWhileStatement(
                body: BlockStatement(body: body, directives: const []),
                test: _parseValueText(testText),
              ),
            );
            break;
          }
        case 'ExpressionStatement':
          {
            final exprJson = sm['expr'] as Map<String, dynamic>?;
            if (exprJson != null) {
              final expr = _readExpr(exprJson);
              out.add(ExpressionStatement(expression: expr));
            } else {
              final text = sm['text'] as String? ?? '';
              out.add(
                ExpressionStatement(
                  expression: Identifier(
                    text: text,
                    name: extractIdentifierName(text),
                  ),
                  text: text,
                ),
              );
            }
            break;
          }
        default:
          break;
      }
    }
    return out;
  }

  Expression _readExpr(Map<String, dynamic> m) {
    final t = m['expr_type'] as String? ?? '';
    switch (t) {
      case 'BinaryExpression':
        return BinaryExpression(
          operator: (m['operator'] as String? ?? ''),
          left: _parseValueText(m['left_text'] as String? ?? ''),
          right: _parseValueText(m['right_text'] as String? ?? ''),
        );
      case 'AssignmentExpression':
        return AssignmentExpression(
          operator: (m['operator'] as String? ?? ''),
          left: _parseValueText(m['left_text'] as String? ?? ''),
          right: _parseValueText(m['right_text'] as String? ?? ''),
        );
      case 'ConditionalExpression':
        return ConditionalExpression(
          test: _parseValueText(m['test_text'] as String? ?? ''),
          consequent: _parseValueText(m['cons_text'] as String? ?? ''),
          alternate: _parseValueText(m['alt_text'] as String? ?? ''),
        );
      case 'MemberExpression':
        {
          final obj = _parseValueText(m['object_text'] as String? ?? '');
          final computed = m['computed'] as bool? ?? false;
          final propText = m['property_text'] as String? ?? '';
          final prop = computed
              ? _parseValueText(propText)
              : Identifier(name: propText);
          return MemberExpression(
            object: obj,
            property: prop,
            computed: computed,
          );
        }
      case 'NewExpression':
        {
          final calleeText = m['callee_text'] as String? ?? '';
          final argsRaw = m['args'] as List<dynamic>? ?? const [];
          final args = argsRaw
              .map((e) => _parseValueText(e as String))
              .toList();
          return NewExpression(
            callee: Identifier(
              text: calleeText,
              name: extractIdentifierName(calleeText),
            ),
            arguments: args,
          );
        }
      case 'UnaryExpression':
        return UnaryExpression(
          operator: m['operator'] as String? ?? '',
          argument: _parseValueText(m['argument_text'] as String? ?? ''),
          prefix: true,
        );
      case 'UpdateExpression':
        return UpdateExpression(
          operator: m['operator'] as String? ?? '',
          argument: _parseValueText(m['argument_text'] as String? ?? ''),
          prefix: (m['prefix'] as bool? ?? false),
        );
      default:
        return Identifier(
          text: (m['text'] as String? ?? ''),
          name: extractIdentifierName(m['text'] as String? ?? ''),
        );
    }
  }

  Object _paramToPattern(Map<String, dynamic> m) {
    final k = m['param_kind'] as String? ?? 'ident';
    if (k == 'ident') return Identifier(name: (m['name'] as String?) ?? '');
    if (k == 'rest')
      return RestElement(
        argument: Identifier(name: (m['name'] as String?) ?? ''),
      );
    if (k == 'object') {
      final props = <Object>[];
      for (final ip in (m['properties'] as List<dynamic>? ?? const [])) {
        final im = ip as Map<String, dynamic>;
        final keyName = (im['key'] as String?) ?? '';
        final aliasName = im['alias'] as String? ?? keyName;
        final defText = im['default_text'] as String?;
        final nested = im['nested'];
        Object val;
        if (nested is Map<String, dynamic>) {
          val = _paramToPattern(nested);
        } else if (defText != null) {
          val = AssignmentPattern(
            left: Identifier(name: aliasName),
            right: _parseValueText(defText),
          );
        } else {
          val = Identifier(name: aliasName);
        }
        props.add(
          ObjectProperty(
            key: Identifier(name: keyName),
            value: val,
            computed: false,
            shorthand: aliasName == keyName,
          ),
        );
      }
      return ObjectPattern(properties: props);
    }
    if (k == 'array') {
      final elems = <Object?>[];
      for (final el in (m['elements'] as List<dynamic>? ?? const [])) {
        if (el is Map<String, dynamic>) {
          elems.add(_paramToPattern(el));
        } else {
          elems.add(null);
        }
      }
      return ArrayPattern(elements: elems);
    }
    if (k == 'assign') {
      final left = m['left'] as Map<String, dynamic>? ?? const {};
      final defText = m['default_text'] as String? ?? '';
      return AssignmentPattern(
        left: _paramToPattern(left),
        right: _parseValueText(defText),
      );
    }
    final t = m['text'] as String? ?? '';
    return Identifier(text: t, name: extractIdentifierName(t));
  }

  Expression _parseValueText(String t) {
    final tt = t.trim();
    if (tt == 'null') return const NullLiteral();
    if (tt == 'true' || tt == 'false')
      return BooleanLiteral(value: tt == 'true');
    final numVal = num.tryParse(tt);
    if (numVal != null) return NumericLiteral(value: numVal);
    if ((tt.startsWith('"') && tt.endsWith('"')) ||
        (tt.startsWith('\'') && tt.endsWith('\''))) {
      final sv = tt.length >= 2 ? tt.substring(1, tt.length - 1) : tt;
      return StringLiteral(stringValue: sv, text: tt);
    }
    return Identifier(text: tt, name: tt);
  }
}
