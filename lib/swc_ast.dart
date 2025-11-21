import 'sfc_ast.dart';

class Loc {
  final int line;
  final int column;
  Loc({required this.line, required this.column});
}

class Node {
  final int start;
  final int end;
  final Loc locStart;
  final Loc locEnd;
  Node({
    required this.start,
    required this.end,
    required this.locStart,
    required this.locEnd,
  });

  int get lineNumber => locStart.line;
  int get columnNumber => locStart.column;
  int get endLineNumber => locEnd.line;
  int get endColumnNumber => locEnd.column;
}

sealed class ModuleItem {}

sealed class SwcImportSpecifier {}

class SwcImportDefaultSpecifier extends SwcImportSpecifier {
  final Node span;
  final String local;
  SwcImportDefaultSpecifier({required this.span, required this.local});
}

class SwcImportNamespaceSpecifier extends SwcImportSpecifier {
  final Node span;
  final String local;
  SwcImportNamespaceSpecifier({required this.span, required this.local});
}

class SwcImportNamedSpecifier extends SwcImportSpecifier {
  final Node span;
  final String local;
  final String? importedIdent;
  final String? importedStr;
  final String? importKind;
  SwcImportNamedSpecifier({
    required this.span,
    required this.local,
    this.importedIdent,
    this.importedStr,
    this.importKind,
  });
}

class ImportDecl extends ModuleItem {
  final Node node;
  final String src;
  final List<SwcImportSpecifier> specifiers;
  ImportDecl({required this.node, required this.src, required this.specifiers});
}

sealed class SwcExportSpecifier {}

class SwcExportNamedSpecifier extends SwcExportSpecifier {
  final Node span;
  final String? localIdent;
  final String? exportedIdent;
  final String? exportedStr;
  final String? exportKind;
  SwcExportNamedSpecifier({
    required this.span,
    this.localIdent,
    this.exportedIdent,
    this.exportedStr,
    this.exportKind,
  });
}

class SwcExportNamespaceAlias extends SwcExportSpecifier {
  final Node span;
  final String exportedIdent;
  SwcExportNamespaceAlias({required this.span, required this.exportedIdent});
}

class ExportNamedDecl extends ModuleItem {
  final Node node;
  final List<SwcExportSpecifier> specifiers;
  final String? src;
  ExportNamedDecl({required this.node, required this.specifiers, this.src});
}

class ExportAllDecl extends ModuleItem {
  final Node node;
  final String src;
  final String? exportedIdent;
  ExportAllDecl({required this.node, required this.src, this.exportedIdent});
}

class ExportFnDeclItem extends ModuleItem {
  final Node node;
  final String name;
  ExportFnDeclItem({required this.node, required this.name});
}

class ExportClassDeclItem extends ModuleItem {
  final Node node;
  final String name;
  ExportClassDeclItem({required this.node, required this.name});
}

class ExportDefaultExpr extends ModuleItem {
  final Node node;
  final Node? objSpan;
  ExportDefaultExpr({required this.node, this.objSpan});
}

class ExportDefaultDecl extends ModuleItem {
  final Node node;
  ExportDefaultDecl({required this.node});
}

class CallExpr extends ModuleItem {
  final Node node;
  final String? calleeIdent;
  final List<String> args;
  final List<String>? typeArgs;
  final String? text;
  final String? typeArgText;
  final List<String>? typeArgKinds;
  final List<String>? typeRefIdents;
  final List<List<TSPropertySignature>>? typeLiteralProps;
  CallExpr({
    required this.node,
    this.calleeIdent,
    required this.args,
    this.typeArgs,
    this.text,
    this.typeArgText,
    this.typeArgKinds,
    this.typeRefIdents,
    this.typeLiteralProps,
  });
}

class TSPropertySignature {
  final String key;
  final String? typeAnn;
  final bool optional;
  TSPropertySignature({
    required this.key,
    this.typeAnn,
    required this.optional,
  });
}

class TSTypeAliasDecl extends ModuleItem {
  final Node node;
  final String id;
  final List<TSPropertySignature> members;
  TSTypeAliasDecl({
    required this.node,
    required this.id,
    required this.members,
  });
}

class TSInterfaceDecl extends ModuleItem {
  final Node node;
  final String id;
  final List<TSPropertySignature> members;
  TSInterfaceDecl({
    required this.node,
    required this.id,
    required this.members,
  });
}

class VarDeclItem extends ModuleItem {
  final Node node;
  final String declKind; // 'const' | 'let' | 'var'
  final Identifier nameExpr;
  final List<String> names;
  final bool inited;
  final String? initText;
  final String? initCalleeIdent;
  final Expression? initExpr;
  final List<String>? initTypeArgs;
  final SWCArrayBindingPattern? arrayPattern;
  final SWCObjectBindingPattern? objectPattern;
  final String? patternTypeAnnText;
  VarDeclItem({
    required this.node,
    required this.declKind,
    required this.nameExpr,
    required this.names,
    required this.inited,
    this.initText,
    this.initCalleeIdent,
    this.initExpr,
    this.initTypeArgs,
    this.arrayPattern,
    this.objectPattern,
    this.patternTypeAnnText,
  });

  /// Convert this SWC variable declaration item into a unified TS `VariableDeclaration`.
  ///
  /// Provide `text` as the full source slice of the declaration and an optional
  /// `pattern` converted from SWC binding pattern structures when destructuring.
  VariableDeclaration toVariableDeclaration({
    required String text,
    BindingPattern? pattern,
  }) {
    return VariableDeclaration(
      initExpr,
      startByte: node.start,
      endByte: node.end,
      text: text,
      name: nameExpr,
      pattern: pattern,
      declKind: declKind,
    );
  }
}

class FnDeclItem extends ModuleItem {
  final Node node;
  final String name;
  final String? text;
  final bool? isAsync;
  final bool? isGenerator;
  final List<SwcFnParam>? params;
  final String? returnTypeText;
  FnDeclItem({required this.node, required this.name, this.text, this.isAsync, this.isGenerator, this.params, this.returnTypeText});
}

class ClassDeclItem extends ModuleItem {
  final Node node;
  final String name;
  final String? superClass;
  final List<String>? implements;
  final List<String>? decorators;
  final List<SwcClassMember>? members;
  ClassDeclItem({required this.node, required this.name, this.superClass, this.implements, this.decorators, this.members});
}

class SwcFnParam {
  final String? name;
  final String? defaultText;
  final bool isRest;
  final String? typeAnnText;
  SwcFnParam({this.name, this.defaultText, required this.isRest, this.typeAnnText});
}

class SwcClassMember {
  final String kind; // Constructor | Method | Getter | Setter | Property | StaticBlock
  final bool? isStatic;
  final bool? isAsync;
  final bool? isGenerator;
  final String? key;
  SwcClassMember({required this.kind, this.isStatic, this.isAsync, this.isGenerator, this.key});
}

class TSDeclareFunctionItem extends ModuleItem {
  final Node node;
  final String name;
  TSDeclareFunctionItem({required this.node, required this.name});
}

class StaticBlockItem extends ModuleItem {
  final Node node;
  final int bodyLen;
  StaticBlockItem({required this.node, required this.bodyLen});
}

class TSModuleBlockItem extends ModuleItem {
  final Node node;
  final int bodyLen;
  TSModuleBlockItem({required this.node, required this.bodyLen});
}

class Module {
  final List<ModuleItem> body;
  Module({required this.body});
}

String nodeLocationString(Node n) {
  return '${n.lineNumber}:${n.columnNumber}-${n.endLineNumber}:${n.endColumnNumber}';
}

String printNodeWithLocation(ModuleItem it) {
  if (it is ImportDecl) {
    return 'Import ${it.src} @ ' + nodeLocationString(it.node);
  } else if (it is ExportNamedDecl) {
    return 'ExportNamed @ ' + nodeLocationString(it.node);
  } else if (it is ExportAllDecl) {
    return 'ExportAll ${it.src} @ ' + nodeLocationString(it.node);
  } else if (it is ExportDefaultExpr) {
    return 'ExportDefaultExpr @ ' + nodeLocationString(it.node);
  } else if (it is ExportDefaultDecl) {
    return 'ExportDefaultDecl @ ' + nodeLocationString(it.node);
  } else if (it is ExportFnDeclItem) {
    return 'ExportFn ${it.name} @ ' + nodeLocationString(it.node);
  } else if (it is ExportClassDeclItem) {
    return 'ExportClass ${it.name} @ ' + nodeLocationString(it.node);
  } else if (it is CallExpr) {
    return 'Call ${it.calleeIdent ?? ''} @ ' + nodeLocationString(it.node);
  } else if (it is VarDeclItem) {
    return 'Var ${it.nameExpr.name} @ ' + nodeLocationString(it.node);
  } else if (it is FnDeclItem) {
    return 'Fn ${it.name} @ ' + nodeLocationString(it.node);
  } else if (it is ClassDeclItem) {
    return 'Class ${it.name} @ ' + nodeLocationString(it.node);
  } else if (it is TSDeclareFunctionItem) {
    return 'TSDeclareFn ${it.name} @ ' + nodeLocationString(it.node);
  } else if (it is StaticBlockItem) {
    return 'StaticBlock @ ' + nodeLocationString(it.node);
  } else if (it is TSModuleBlockItem) {
    return 'TSModuleBlock @ ' + nodeLocationString(it.node);
  }
  return 'Node @ unknown';
}

List<ModuleItem> findItemsByStartLine(Module m, int line) {
  final out = <ModuleItem>[];
  for (final it in m.body) {
    Node? n;
    if (it is ImportDecl) n = it.node;
    else if (it is ExportNamedDecl) n = it.node;
    else if (it is ExportAllDecl) n = it.node;
    else if (it is ExportDefaultExpr) n = it.node;
    else if (it is ExportDefaultDecl) n = it.node;
    else if (it is ExportFnDeclItem) n = it.node;
    else if (it is ExportClassDeclItem) n = it.node;
    else if (it is CallExpr) n = it.node;
    else if (it is VarDeclItem) n = it.node;
    else if (it is FnDeclItem) n = it.node;
    else if (it is ClassDeclItem) n = it.node;
    else if (it is TSDeclareFunctionItem) n = it.node;
    else if (it is StaticBlockItem) n = it.node;
    else if (it is TSModuleBlockItem) n = it.node;
    if (n != null && n.lineNumber == line) out.add(it);
  }
  return out;
}

bool isSwcClassItem(ModuleItem it) {
  return it is ClassDeclItem;
}

String? _extractCalleeName(String? callText) {
  if (callText == null || callText.isEmpty) return null;
  final t = callText.trim();
  int end = t.length;
  final iParen = t.indexOf('(');
  final iGeneric = t.indexOf('<');
  if (iParen >= 0) end = iParen;
  if (iGeneric >= 0 && iGeneric < end) end = iGeneric;
  var prefix = t.substring(0, end).trim();
  if (prefix.isEmpty) return null;
  final dot = prefix.lastIndexOf('.');
  if (dot >= 0) prefix = prefix.substring(dot + 1).trim();
  int i = prefix.length - 1;
  while (i >= 0) {
    final c = prefix.codeUnitAt(i);
    final isAlpha = (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
    final isDigit = (c >= 48 && c <= 57);
    final ok = isAlpha || isDigit || c == 95 || c == 36;
    if (!ok) break;
    i--;
  }
  final candidate = prefix.substring(i + 1);
  return candidate.isEmpty ? prefix : candidate;
}

/// Build a simple TS Expression from raw text (subset: string, number, boolean, null, identifier).
class SWCArrayBindingElement {
  final String? name;
  final String? defaultText;
  final bool isRest;
  final int? index;
  SWCArrayBindingElement({
    this.name,
    this.defaultText,
    this.isRest = false,
    this.index,
  });
}

class SWCArrayBindingPattern {
  final List<SWCArrayBindingElement> elements;
  final String? patternTypeAnnText;
  SWCArrayBindingPattern({required this.elements, this.patternTypeAnnText});
}

class SWCObjectBindingProperty {
  final String key;
  final String? alias;
  final String? defaultText;
  final SWCObjectBindingPattern? nested;
  SWCObjectBindingProperty({
    required this.key,
    this.alias,
    this.defaultText,
    this.nested,
  });
}

class SWCObjectBindingPattern {
  final List<SWCObjectBindingProperty> properties;
  final String? patternTypeAnnText;
  SWCObjectBindingPattern({required this.properties, this.patternTypeAnnText});
}

class SwcDeclaratorAnalysis {
  final String declarationType; // call | variable | function_expression | none
  final String identifier;
  final Map<String, Object?> initDetails;
  final Loc locStart;
  final Loc locEnd;
  SwcDeclaratorAnalysis({
    required this.declarationType,
    required this.identifier,
    required this.initDetails,
    required this.locStart,
    required this.locEnd,
  });
}

List<SwcDeclaratorAnalysis> analyzeSwcDeclarators(Module m) {
  String valueType(Expression? e) {
    if (e == null) return 'None';
    if (e is StringLiteral) return 'String';
    if (e is NumberLiteral) return 'Number';
    if (e is BooleanLiteral) return 'Boolean';
    if (e is NullLiteral) return 'Null';
    if (e is BigIntLiteral) return 'BigInt';
    if (e is ListLiteral) return 'Array';
    if (e is SetOrMapLiteral) return 'Object';
    if (e is Identifier) return 'Identifier';
    return 'Expression';
  }

  bool looksFunctionText(String? t) {
    if (t == null || t.isEmpty) return false;
    final s = t.trim();
    return s.contains('=>') || s.startsWith('function');
  }

  final out = <SwcDeclaratorAnalysis>[];
  for (final it in m.body) {
    if (it is VarDeclItem) {
      final hasDestructure =
          it.arrayPattern != null || it.objectPattern != null;
      void pushOne(String name) {
        if ((it.initCalleeIdent != null && it.initCalleeIdent!.isNotEmpty)) {
          out.add(
            SwcDeclaratorAnalysis(
              declarationType: 'call',
              identifier: name,
              initDetails: {
                'callee': it.initCalleeIdent,
                'typeArgs': it.initTypeArgs,
                'destructure': hasDestructure,
                'text': it.initText,
              },
              locStart: it.node.locStart,
              locEnd: it.node.locEnd,
            ),
          );
        } else if (looksFunctionText(it.initText)) {
          out.add(
            SwcDeclaratorAnalysis(
              declarationType: 'function_expression',
              identifier: name,
              initDetails: {
                'functionText': it.initText,
                'destructure': hasDestructure,
              },
              locStart: it.node.locStart,
              locEnd: it.node.locEnd,
            ),
          );
        } else if (it.initText == null && it.initExpr == null) {
          out.add(
            SwcDeclaratorAnalysis(
              declarationType: 'none',
              identifier: name,
              initDetails: {'destructure': hasDestructure},
              locStart: it.node.locStart,
              locEnd: it.node.locEnd,
            ),
          );
        } else {
          out.add(
            SwcDeclaratorAnalysis(
              declarationType: 'variable',
              identifier: name,
              initDetails: {
                'valueType': valueType(it.initExpr),
                'valueText': _exprText(it.initExpr),
                'destructure': hasDestructure,
              },
              locStart: it.node.locStart,
              locEnd: it.node.locEnd,
            ),
          );
        }
      }

      for (final n in it.names) {
        pushOne(n);
      }
    } else if (it is FnDeclItem) {
      out.add(
        SwcDeclaratorAnalysis(
          declarationType: 'function_declaration',
          identifier: it.name,
          initDetails: {'text': it.text},
          locStart: it.node.locStart,
          locEnd: it.node.locEnd,
        ),
      );
    }
  }
  return out;
}

String? _exprText(Expression? e) {
  if (e == null) return null;
  if (e is StringLiteral) return e.stringValue;
  if (e is NumericLiteral) return e.value.toString();
  if (e is NumberLiteral) return e.value.toString();
  if (e is BooleanLiteral) return e.value.toString();
  if (e is BigIntLiteral) {
    return (e.value is String) ? (e.value as String) : e.value.toString();
  }
  return null;
}

Node _nodeFromJson(Map<String, dynamic> m) {
  if (m['loc'] != null) {
    final loc = m['loc'] as Map<String, dynamic>;
    final ls = loc['start'] as Map<String, dynamic>;
    final le = loc['end'] as Map<String, dynamic>;
    return Node(
      start: (m['start'] as num).toInt(),
      end: (m['end'] as num).toInt(),
      locStart: Loc(
        line: (ls['line'] as num).toInt(),
        column: (ls['column'] as num).toInt(),
      ),
      locEnd: Loc(
        line: (le['line'] as num).toInt(),
        column: (le['column'] as num).toInt(),
      ),
    );
  }
  final ls = m['loc_start'] as Map<String, dynamic>;
  final le = m['loc_end'] as Map<String, dynamic>;
  return Node(
    start: (m['start'] as num).toInt(),
    end: (m['end'] as num).toInt(),
    locStart: Loc(
      line: (ls['line'] as num).toInt(),
      column: (ls['column'] as num).toInt(),
    ),
    locEnd: Loc(
      line: (le['line'] as num).toInt(),
      column: (le['column'] as num).toInt(),
    ),
  );
}

Module swcModuleFromJson(Map<String, dynamic> m) {
  final items = <ModuleItem>[];
  final body = m['body'] as List<dynamic>? ?? const [];
  for (final it in body) {
    final mm = it as Map<String, dynamic>;
    final t = mm['type'] as String;
    switch (t) {
      case 'ImportDeclaration':
        final specs = <SwcImportSpecifier>[];
        for (final s in (mm['specifiers'] as List<dynamic>? ?? const [])) {
          final sm = s as Map<String, dynamic>;
          final kind = sm['kind'] as String;
          switch (kind) {
            case 'Default':
              specs.add(
                SwcImportDefaultSpecifier(
                  span: _nodeFromJson(sm['span']),
                  local: sm['local'] as String,
                ),
              );
              break;
            case 'Namespace':
              specs.add(
                SwcImportNamespaceSpecifier(
                  span: _nodeFromJson(sm['span']),
                  local: sm['local'] as String,
                ),
              );
              break;
            case 'Named':
              specs.add(
                SwcImportNamedSpecifier(
                  span: _nodeFromJson(sm['span']),
                  local: sm['local'] as String,
                  importedIdent: sm['imported_ident'] as String?,
                  importedStr: sm['imported_str'] as String?,
                  importKind: sm['import_kind'] as String?,
                ),
              );
              break;
          }
        }
        items.add(
          ImportDecl(
            node: _nodeFromJson(mm),
            src: mm['src'] as String,
            specifiers: specs,
          ),
        );
        break;
      case 'ExportNamedDeclaration':
        final specs = <SwcExportSpecifier>[];
        for (final s in (mm['specifiers'] as List<dynamic>? ?? const [])) {
          final sm = s as Map<String, dynamic>;
          final kind = sm['kind'] as String;
          switch (kind) {
            case 'Named':
              specs.add(
                SwcExportNamedSpecifier(
                  span: _nodeFromJson(sm['span']),
                  localIdent: sm['local_ident'] as String?,
                  exportedIdent: sm['exported_ident'] as String?,
                  exportedStr: sm['exported_str'] as String?,
                  exportKind: sm['export_kind'] as String?,
                ),
              );
              break;
            case 'NamespaceAlias':
              specs.add(
                SwcExportNamespaceAlias(
                  span: _nodeFromJson(sm['span']),
                  exportedIdent: sm['exported_ident'] as String,
                ),
              );
              break;
          }
        }
        items.add(
          ExportNamedDecl(
            node: _nodeFromJson(mm),
            specifiers: specs,
            src: mm['source'] as String?,
          ),
        );
        break;
      case 'ExportAllDeclaration':
        items.add(
          ExportAllDecl(
            node: _nodeFromJson(mm),
            src: mm['src'] as String,
            exportedIdent: mm['exported_ident'] as String?,
          ),
        );
        break;
      case 'ExportDeclFn':
        items.add(ExportFnDeclItem(node: _nodeFromJson(mm), name: mm['name'] as String));
        break;
      case 'ExportDeclClass':
        items.add(ExportClassDeclItem(node: _nodeFromJson(mm), name: mm['name'] as String));
        break;
      case 'ExportDefaultDeclaration':
        items.add(ExportDefaultDecl(node: _nodeFromJson(mm)));
        break;
      case 'CallExpression':
        final args = (mm['args'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList();
        final typeArgs = mm['type_parameters'] == null
            ? null
            : (mm['type_parameters'] as List<dynamic>)
                  .map((e) => e as String)
                  .toList();
        String? callee = mm['callee_ident'] as String?;
        if (callee == null || callee.isEmpty) {
          callee = _extractCalleeName(mm['text'] as String?);
        }
        final typeArgText = mm['type_argument_text'] as String?;
        List<String>? typeArgKinds;
        if (mm['type_arg_kinds'] != null) {
          typeArgKinds = (mm['type_arg_kinds'] as List<dynamic>)
              .map((e) => e as String)
              .toList();
        }
        List<String>? typeRefIdents;
        if (mm['type_ref_idents'] != null) {
          typeRefIdents = (mm['type_ref_idents'] as List<dynamic>)
              .map((e) => e as String)
              .toList();
        }
        List<List<TSPropertySignature>>? typeLiteralProps;
        if (mm['type_literal_props'] != null) {
          final outer = (mm['type_literal_props'] as List<dynamic>);
          typeLiteralProps = outer.map((lst) {
            final xs = lst as List<dynamic>;
            return xs
                .map(
                  (pm) => TSPropertySignature(
                    key: (pm as Map<String, dynamic>)['key'] as String,
                    typeAnn: pm['type_ann'] as String?,
                    optional: pm['optional'] as bool? ?? false,
                  ),
                )
                .toList();
          }).toList();
        }
        items.add(
          CallExpr(
            node: _nodeFromJson(mm),
            calleeIdent: callee,
            args: args,
            typeArgs: typeArgs,
            text: mm['text'] as String?,
            typeArgText: typeArgText,
            typeArgKinds: typeArgKinds,
            typeRefIdents: typeRefIdents,
            typeLiteralProps: typeLiteralProps,
          ),
        );
        break;
      case 'TSTypeAliasDeclaration':
        final members = <TSPropertySignature>[];
        for (final p in (mm['members'] as List<dynamic>? ?? const [])) {
          final pm = p as Map<String, dynamic>;
          members.add(
            TSPropertySignature(
              key: pm['key'] as String,
              typeAnn: pm['type_ann'] as String?,
              optional: pm['optional'] as bool? ?? false,
            ),
          );
        }
        items.add(
          TSTypeAliasDecl(
            node: _nodeFromJson(mm),
            id: mm['id'] as String,
            members: members,
          ),
        );
        break;
      case 'TSInterfaceDeclaration':
        final members = <TSPropertySignature>[];
        for (final p in (mm['members'] as List<dynamic>? ?? const [])) {
          final pm = p as Map<String, dynamic>;
          members.add(
            TSPropertySignature(
              key: pm['key'] as String,
              typeAnn: pm['type_ann'] as String?,
              optional: pm['optional'] as bool? ?? false,
            ),
          );
        }
        items.add(
          TSInterfaceDecl(
            node: _nodeFromJson(mm),
            id: mm['id'] as String,
            members: members,
          ),
        );
        break;
      case 'VariableDeclaration':
        {
          SWCArrayBindingPattern? arrPat;
          SWCObjectBindingPattern? objPat;
          if (mm['array_pattern'] != null) {
            final ap = mm['array_pattern'] as Map<String, dynamic>;
            final els = <SWCArrayBindingElement>[];
            for (final e in (ap['elements'] as List<dynamic>? ?? const [])) {
              final em = e as Map<String, dynamic>;
              els.add(
                SWCArrayBindingElement(
                  name: em['name'] as String?,
                  defaultText: em['default_text'] as String?,
                  isRest: em['is_rest'] as bool? ?? false,
                  index: (em['index'] as num?)?.toInt(),
                ),
              );
            }
            arrPat = SWCArrayBindingPattern(
              elements: els,
              patternTypeAnnText: ap['pattern_type_ann_text'] as String?,
            );
          }
          SWCObjectBindingPattern? parseObjPat(Map<String, dynamic> op) {
            final props = <SWCObjectBindingProperty>[];
            for (final p in (op['properties'] as List<dynamic>? ?? const [])) {
              final pm = p as Map<String, dynamic>;
              SWCObjectBindingPattern? nested;
              if (pm['nested'] != null) {
                nested = parseObjPat(pm['nested'] as Map<String, dynamic>);
              }
              props.add(
                SWCObjectBindingProperty(
                  key: pm['key'] as String,
                  alias: pm['alias'] as String?,
                  defaultText: pm['default_text'] as String?,
                  nested: nested,
                ),
              );
            }
            return SWCObjectBindingPattern(
              properties: props,
              patternTypeAnnText: op['pattern_type_ann_text'] as String?,
            );
          }

          if (mm['object_pattern'] != null) {
            objPat = parseObjPat(mm['object_pattern'] as Map<String, dynamic>);
          }
          Expression? initExpr;
          if (mm['init_text'] != null) {
            final it = (mm['init_text'] as String).trim();
            if (it == 'null') {
              initExpr = NullLiteral(
                start: (mm['start'] as num).toInt(),
                end: (mm['end'] as num).toInt(),
              );
            } else if (it.endsWith('n')) {
              final body = it.substring(0, it.length - 1);
              final n = num.tryParse(body);
              if (n != null) {
                initExpr = BigIntLiteral(value: BigInt.parse(body));
              }
            } else if (it.startsWith('"') || it.startsWith('\'')) {
              final sv = it.length >= 2 ? it.substring(1, it.length - 1) : it;
              initExpr = StringLiteral(stringValue: sv);
            } else if (it == 'true' || it == 'false') {
              initExpr = BooleanLiteral(value: it == 'true');
            } else if (num.tryParse(it) != null) {
              initExpr = NumberLiteral(value: num.parse(it));
            } else {
              initExpr = Identifier(text: it);
            }
          }
          items.add(
            VarDeclItem(
              node: _nodeFromJson(mm),
              declKind: (mm['decl_kind'] as String?) ?? 'const',
              nameExpr: Identifier(text: mm['name'] as String),
              names: (mm['names'] as List<dynamic>? ?? const [])
                  .map((e) => e as String)
                  .toList(),
              inited: mm['inited'] as bool? ?? false,
              initText: mm['init_text'] as String?,
              initCalleeIdent: mm['init_callee_ident'] as String?,
              initExpr: initExpr,
              initTypeArgs: mm['type_parameters'] == null
                  ? null
                  : (mm['type_parameters'] as List<dynamic>)
                        .map((e) => e as String)
                        .toList(),
              arrayPattern: arrPat,
              objectPattern: objPat,
              patternTypeAnnText: mm['pattern_type_ann_text'] as String?,
            ),
          );
        }
        break;
      case 'FunctionDeclaration':
        List<SwcFnParam>? params;
        if (mm['params'] != null) {
          params = (mm['params'] as List<dynamic>).map((p) {
            final pm = p as Map<String, dynamic>;
            return SwcFnParam(
              name: pm['name'] as String?,
              defaultText: pm['default_text'] as String?,
              isRest: pm['is_rest'] as bool? ?? false,
              typeAnnText: pm['type_ann_text'] as String?,
            );
          }).toList();
        }
        items.add(
          FnDeclItem(
            node: _nodeFromJson(mm),
            name: mm['name'] as String,
            text: mm['text'] as String?,
            isAsync: mm['async'] as bool?,
            isGenerator: mm['generator'] as bool?,
            params: params,
            returnTypeText: mm['return_type'] as String?,
          ),
        );
        break;
      case 'ClassDeclaration':
        List<SwcClassMember>? members;
        if (mm['members'] != null) {
          members = (mm['members'] as List<dynamic>).map((m) {
            final mmx = m as Map<String, dynamic>;
            final kind = mmx['kind'] as String;
            return SwcClassMember(
              kind: kind,
              isStatic: mmx['is_static'] as bool?,
              isAsync: mmx['async'] as bool?,
              isGenerator: mmx['generator'] as bool?,
              key: mmx['key'] as String?,
            );
          }).toList();
        }
        items.add(
          ClassDeclItem(
            node: _nodeFromJson(mm),
            name: mm['name'] as String,
            superClass: mm['super_class'] as String?,
            implements: mm['implements'] == null ? null : (mm['implements'] as List<dynamic>).map((e) => e as String).toList(),
            decorators: mm['decorators'] == null ? null : (mm['decorators'] as List<dynamic>).map((e) => e as String).toList(),
            members: members,
          ),
        );
        break;
      case 'TSDeclareFunction':
        items.add(
          TSDeclareFunctionItem(
            node: _nodeFromJson(mm),
            name: mm['name'] as String,
          ),
        );
        break;
      case 'ImportDecl':
        final specs = <SwcImportSpecifier>[];
        for (final s in (mm['specifiers'] as List<dynamic>? ?? const [])) {
          final sm = s as Map<String, dynamic>;
          final kind = sm['kind'] as String;
          switch (kind) {
            case 'Default':
              specs.add(
                SwcImportDefaultSpecifier(
                  span: _nodeFromJson(sm['span']),
                  local: sm['local'] as String,
                ),
              );
              break;
            case 'Namespace':
              specs.add(
                SwcImportNamespaceSpecifier(
                  span: _nodeFromJson(sm['span']),
                  local: sm['local'] as String,
                ),
              );
              break;
            case 'Named':
              specs.add(
                SwcImportNamedSpecifier(
                  span: _nodeFromJson(sm['span']),
                  local: sm['local'] as String,
                  importedIdent: sm['imported_ident'] as String?,
                  importedStr: sm['imported_str'] as String?,
                  importKind: sm['import_kind'] as String?,
                ),
              );
              break;
          }
        }
        items.add(
          ImportDecl(
            node: _nodeFromJson(mm['span']),
            src: mm['src'] as String,
            specifiers: specs,
          ),
        );
        break;
      case 'ExportNamedDecl':
        final specs = <SwcExportSpecifier>[];
        for (final s in (mm['specifiers'] as List<dynamic>? ?? const [])) {
          final sm = s as Map<String, dynamic>;
          final kind = sm['kind'] as String;
          switch (kind) {
            case 'Named':
              specs.add(
                SwcExportNamedSpecifier(
                  span: _nodeFromJson(sm['span']),
                  localIdent: sm['local_ident'] as String?,
                  exportedIdent: sm['exported_ident'] as String?,
                  exportedStr: sm['exported_str'] as String?,
                  exportKind: sm['export_kind'] as String?,
                ),
              );
              break;
            case 'NamespaceAlias':
              specs.add(
                SwcExportNamespaceAlias(
                  span: _nodeFromJson(sm['span']),
                  exportedIdent: sm['exported_ident'] as String,
                ),
              );
              break;
          }
        }
        items.add(
          ExportNamedDecl(
            node: _nodeFromJson(mm['span']),
            specifiers: specs,
            src: mm['src'] as String?,
          ),
        );
        break;
      case 'ExportAllDecl':
        items.add(
          ExportAllDecl(
            node: _nodeFromJson(mm['span']),
            src: mm['src'] as String,
            exportedIdent: mm['exported_ident'] as String?,
          ),
        );
        break;
      case 'ExportDefaultExpr':
        final objSpan = mm['obj_span'] == null
            ? null
            : _nodeFromJson(mm['obj_span']);
        items.add(
          ExportDefaultExpr(node: _nodeFromJson(mm['span']), objSpan: objSpan),
        );
        break;
      case 'ExportDefaultDecl':
        items.add(ExportDefaultDecl(node: _nodeFromJson(mm['span'])));
        break;
      case 'CallExpr':
        final args = (mm['args'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList();
        final typeArgs = mm['type_args'] == null
            ? null
            : (mm['type_args'] as List<dynamic>)
                  .map((e) => e as String)
                  .toList();
        String? callee = mm['callee_ident'] as String?;
        if (callee == null || callee.isEmpty) {
          callee = _extractCalleeName(mm['text'] as String?);
        }
        final typeArgText = mm['type_argument_text'] as String?;
        List<String>? typeArgKinds;
        if (mm['type_arg_kinds'] != null) {
          typeArgKinds = (mm['type_arg_kinds'] as List<dynamic>)
              .map((e) => e as String)
              .toList();
        }
        List<String>? typeRefIdents;
        if (mm['type_ref_idents'] != null) {
          typeRefIdents = (mm['type_ref_idents'] as List<dynamic>)
              .map((e) => e as String)
              .toList();
        }
        List<List<TSPropertySignature>>? typeLiteralProps;
        if (mm['type_literal_props'] != null) {
          final outer = (mm['type_literal_props'] as List<dynamic>);
          typeLiteralProps = outer.map((lst) {
            final xs = lst as List<dynamic>;
            return xs
                .map(
                  (pm) => TSPropertySignature(
                    key: (pm as Map<String, dynamic>)['key'] as String,
                    typeAnn: pm['type_ann'] as String?,
                    optional: pm['optional'] as bool? ?? false,
                  ),
                )
                .toList();
          }).toList();
        }
        items.add(
          CallExpr(
            node: _nodeFromJson(mm['span']),
            calleeIdent: callee,
            args: args,
            typeArgs: typeArgs,
            text: mm['text'] as String?,
            typeArgText: typeArgText,
            typeArgKinds: typeArgKinds,
            typeRefIdents: typeRefIdents,
            typeLiteralProps: typeLiteralProps,
          ),
        );
        break;
      case 'TSTypeAliasDecl':
        final members = <TSPropertySignature>[];
        for (final p in (mm['members'] as List<dynamic>? ?? const [])) {
          final pm = p as Map<String, dynamic>;
          members.add(
            TSPropertySignature(
              key: pm['key'] as String,
              typeAnn: pm['type_ann'] as String?,
              optional: pm['optional'] as bool? ?? false,
            ),
          );
        }
        items.add(
          TSTypeAliasDecl(
            node: _nodeFromJson(mm['span']),
            id: mm['id'] as String,
            members: members,
          ),
        );
        break;
      case 'TSInterfaceDecl':
        final members = <TSPropertySignature>[];
        for (final p in (mm['members'] as List<dynamic>? ?? const [])) {
          final pm = p as Map<String, dynamic>;
          members.add(
            TSPropertySignature(
              key: pm['key'] as String,
              typeAnn: pm['type_ann'] as String?,
              optional: pm['optional'] as bool? ?? false,
            ),
          );
        }
        items.add(
          TSInterfaceDecl(
            node: _nodeFromJson(mm['span']),
            id: mm['id'] as String,
            members: members,
          ),
        );
        break;

      case 'VarDecl':
        SWCArrayBindingPattern? arrPat;
        SWCObjectBindingPattern? objPat;
        if (mm['array_pattern'] != null) {
          final ap = mm['array_pattern'] as Map<String, dynamic>;
          final els = <SWCArrayBindingElement>[];
          for (final e in (ap['elements'] as List<dynamic>? ?? const [])) {
            final em = e as Map<String, dynamic>;
            els.add(
              SWCArrayBindingElement(
                name: em['name'] as String?,
                defaultText: em['default_text'] as String?,
                isRest: em['is_rest'] as bool? ?? false,
                index: (em['index'] as num?)?.toInt(),
              ),
            );
          }
          arrPat = SWCArrayBindingPattern(
            elements: els,
            patternTypeAnnText: ap['pattern_type_ann_text'] as String?,
          );
        }
        SWCObjectBindingPattern? parseObjPat(Map<String, dynamic> op) {
          final props = <SWCObjectBindingProperty>[];
          for (final p in (op['properties'] as List<dynamic>? ?? const [])) {
            final pm = p as Map<String, dynamic>;
            SWCObjectBindingPattern? nested;
            if (pm['nested'] != null) {
              nested = parseObjPat(pm['nested'] as Map<String, dynamic>);
            }
            props.add(
              SWCObjectBindingProperty(
                key: pm['key'] as String,
                alias: pm['alias'] as String?,
                defaultText: pm['default_text'] as String?,
                nested: nested,
              ),
            );
          }
          return SWCObjectBindingPattern(
            properties: props,
            patternTypeAnnText: op['pattern_type_ann_text'] as String?,
          );
        }
        if (mm['object_pattern'] != null) {
          objPat = parseObjPat(mm['object_pattern'] as Map<String, dynamic>);
        }
        Expression? initExpr;
        if (mm['init_text'] != null) {
          final it = (mm['init_text'] as String).trim();
          if (it == 'null') {
            initExpr = NullLiteral(
              start: mm['init_span'] == null
                  ? (mm['span']['start'] as num).toInt()
                  : (mm['init_span']['start'] as num).toInt(),
              end: mm['init_span'] == null
                  ? (mm['span']['end'] as num).toInt()
                  : (mm['init_span']['end'] as num).toInt(),
            );
          } else if (it.endsWith('n')) {
            final body = it.substring(0, it.length - 1);
            final n = num.tryParse(body);
            if (n != null) {
              initExpr = BigIntLiteral(value: BigInt.parse(body));
            }
          } else if (it.startsWith('"') || it.startsWith('\'')) {
            final sv = it.length >= 2 ? it.substring(1, it.length - 1) : it;
            initExpr = StringLiteral(stringValue: sv);
          } else if (it == 'true' || it == 'false') {
            initExpr = BooleanLiteral(value: it == 'true');
          } else if (num.tryParse(it) != null) {
            initExpr = NumberLiteral(value: num.parse(it));
          } else {
            initExpr = Identifier(text: it);
          }
        }
        items.add(
          VarDeclItem(
            node: _nodeFromJson(mm['span']),
            declKind: (mm['decl_kind'] as String?) ?? 'const',
            nameExpr: Identifier(text: mm['name'] as String),
            names: (mm['names'] as List<dynamic>? ?? const [])
                .map((e) => e as String)
                .toList(),
            inited: mm['inited'] as bool? ?? false,
            initText: mm['init_text'] as String?,
            initCalleeIdent: mm['init_callee_ident'] as String?,
            initExpr: initExpr,
            initTypeArgs: mm['init_type_args'] == null
                ? null
                : (mm['init_type_args'] as List<dynamic>)
                      .map((e) => e as String)
                      .toList(),
            arrayPattern: arrPat,
            objectPattern: objPat,
            patternTypeAnnText: mm['pattern_type_ann_text'] as String?,
          ),
        );
        break;
      case 'FnDecl':
        items.add(
          FnDeclItem(
            node: _nodeFromJson(mm['span']),
            name: mm['name'] as String,
          ),
        );
        break;
      case 'ClassDecl':
        items.add(
          ClassDeclItem(
            node: _nodeFromJson(mm['span']),
            name: mm['name'] as String,
          ),
        );
        break;
      case 'TSDeclareFn':
      case 'DeclareFunction':
        items.add(
          TSDeclareFunctionItem(
            node: _nodeFromJson(mm['span']),
            name: mm['name'] as String,
          ),
        );
        break;
      case 'StaticBlock':
        items.add(
          StaticBlockItem(
            node: _nodeFromJson(mm['span']),
            bodyLen: (mm['body_len'] as num?)?.toInt() ?? 0,
          ),
        );
        break;
      case 'TSModuleBlock':
        items.add(
          TSModuleBlockItem(
            node: _nodeFromJson(mm['span']),
            bodyLen: (mm['body_len'] as num?)?.toInt() ?? 0,
          ),
        );
        break;
      default:
        break;
    }
  }
  return Module(body: items);
}
