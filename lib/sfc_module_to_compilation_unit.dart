import 'dart:convert';

import 'package:vue_sfc_parser/logger.dart';
import 'package:vue_sfc_parser/error_report.dart';
import 'package:vue_sfc_parser/parse_export_default_decl.dart';
import 'package:vue_sfc_parser/parse_simple_expression.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';
import 'package:vue_sfc_parser/swc_ast.dart';

CompilationUnit swcModuleToCompilationUnit(
  Module m,
  String src, {
  bool isScriptSetup = false,
  String? filename = './unknown',
  ErrorReportConfig? errConfig,
}) {
  final statements = <ExpressionStatement>[];
  final imported = <Declaration>[];
  final exported = <Declaration>[];
  final userVariables = <UserVariable>[];
  final alias = <String, List<PropSignature>>{};
  // Pre-check: forbid any export in <script setup>
  if (isScriptSetup) {
    final positions = <ErrorPos>[];
    for (final item in m.body) {
      if (item is ExportDefaultDecl ||
          item is ExportDefaultExpr ||
          item is ExportNamedDecl ||
          item is ExportAllDecl ||
          item is ExportFnDeclItem ||
          item is ExportClassDeclItem) {
        final node = (item as dynamic).node as Node;
        positions.add(ErrorPos(node.locStart.line, node.locStart.column));
      }
    }
    if (positions.isNotEmpty) {
      final err = DeclarationParseError(
        filename: filename!,
        message:
            "[@vue/compiler-sfc] <script setup> cannot contain ES module exports. If you are using a previous version of <script setup>, please consult the updated RFC at https://github.com/vuejs/rfcs/pull/227.",
        positions: positions,
        contextLines: errConfig?.contextLines ?? 3,
        kind: 'export',
      );
      final rendered = ErrorRenderer.render(
        err,
        src,
        config: errConfig ?? const ErrorReportConfig(),
      );
      logger.warn(rendered);
      throw StateError(rendered);
    }
  }
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
              : parseSimpleExpression(
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
                : parseSimpleExpression(
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

      // capture user-defined variable metadata
      String typeOf(Expression? e) {
        if (e == null) return 'Undefined';
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
      final uv = UserVariable(
        name: varDecl.name.name,
        type: typeOf(varDecl.init),
        defaultValue: item.initText,
      );
      if (uv.name.isNotEmpty) userVariables.add(uv);
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
        args.add(parseSimpleExpression(t, item.node.start, item.node.end));
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
        typeArgumentText: item.typeArgText,
        typeArgumentProps:
            (item.typeLiteralProps == null || item.typeLiteralProps!.isEmpty)
            ? const []
            : item.typeLiteralProps!.first
                  .map(
                    (p) => PropSignature(
                      name: p.key,
                      type: p.typeAnn,
                      required: !p.optional,
                    ),
                  )
                  .toList(),
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

    // Import declarations
    if (item is ImportDecl) {
      final specs = <Object>[];
      for (final s in item.specifiers) {
        if (s is SwcImportDefaultSpecifier) {
          specs.add(ImportDefaultSpecifier(local: Identifier(name: s.local)));
        } else if (s is SwcImportNamespaceSpecifier) {
          specs.add(ImportNamespaceSpecifier(local: Identifier(name: s.local)));
        } else if (s is SwcImportNamedSpecifier) {
          final local = Identifier(name: s.local);
          Object imported;
          if (s.importedStr != null) {
            imported = StringLiteral(stringValue: s.importedStr!);
          } else {
            imported = Identifier(name: (s.importedIdent ?? s.local));
          }
          specs.add(
            ImportSpecifier(
              local: local,
              imported: imported,
              importKind: s.importKind,
            ),
          );
        }
      }
      final decl = ImportDeclaration(
        specifiers: specs,
        source: StringLiteral(stringValue: item.src),
      );
      if (isAllowedModuleDecl(decl)) imported.add(decl);
    }
    // Export declarations
    if (item is ExportDefaultDecl) {
      final line = slice(src, item.node.start, item.node.end).trimRight();
      try {
        final decl = parseExportDefaultDecl(
          line,
          item.node.start,
          item.node.end,
        );
        if (isAllowedModuleDecl(decl)) exported.add(decl);
      } catch (e) {
        final err = DeclarationParseError(
          filename: filename!,
          message: 'Failed to parse export default declaration',
          positions: [
            ErrorPos(item.node.locStart.line, item.node.locStart.column),
          ],
          contextLines: 3,
          kind: 'export',
        );
        logger.warn(ErrorRenderer.render(err, src));
      }
    }
    if (item is ExportDefaultExpr) {
      final line = slice(src, item.node.start, item.node.end).trimRight();
      try {
        final decl = parseExportDefaultDecl(
          line,
          item.node.start,
          item.node.end,
        );
        if (isAllowedModuleDecl(decl)) exported.add(decl);
      } catch (e) {
        final err = DeclarationParseError(
          filename: filename!,
          message: 'Failed to parse export default expression',
          positions: [
            ErrorPos(item.node.locStart.line, item.node.locStart.column),
          ],
          contextLines: 3,
          kind: 'export',
        );
        logger.warn(ErrorRenderer.render(err, src));
      }
    }
    if (item is ExportNamedDecl) {
      final specs = <Object>[];
      for (final s in item.specifiers) {
        if (s is SwcExportNamedSpecifier) {
          Identifier local;
          if (s.localIdent != null && s.localIdent!.isNotEmpty) {
            local = Identifier(name: s.localIdent!);
          } else if (s.exportedIdent != null && s.exportedIdent!.isNotEmpty) {
            local = Identifier(name: s.exportedIdent!);
          } else if (s.exportedStr != null && s.exportedStr!.isNotEmpty) {
            local = Identifier(name: s.exportedStr!);
          } else {
            local = Identifier(name: '');
          }
          Object exported;
          if (s.exportedStr != null) {
            exported = StringLiteral(stringValue: s.exportedStr!);
          } else if (s.exportedIdent != null) {
            exported = Identifier(name: s.exportedIdent!);
          } else {
            exported = local;
          }
          specs.add(
            ExportSpecifier(
              local: local,
              exported: exported,
              exportKind: s.exportKind,
            ),
          );
        } else if (s is SwcExportNamespaceAlias) {
          specs.add(
            ExportNamespaceSpecifier(
              exported: Identifier(name: s.exportedIdent),
            ),
          );
        }
      }
      final decl = ExportNamedDeclaration(
        declaration: null,
        specifiers: specs,
        source: item.src == null ? null : StringLiteral(stringValue: item.src!),
      );

      // logger.warn('export named decl $decl');
      if (isAllowedModuleDecl(decl)) exported.add(decl);
    }
    // export function/class declarations
    if (item is ExportFnDeclItem) {
      final spec = ExportSpecifier(
        local: Identifier(name: item.name),
        exported: Identifier(name: item.name),
      );
      final decl = ExportNamedDeclaration(
        declaration: null,
        specifiers: [spec],
        source: null,
      );
      if (isAllowedModuleDecl(decl)) exported.add(decl);
    }
    if (item is ExportClassDeclItem) {
      final spec = ExportSpecifier(
        local: Identifier(name: item.name),
        exported: Identifier(name: item.name),
      );
      final decl = ExportNamedDeclaration(
        declaration: null,
        specifiers: [spec],
        source: null,
      );
      if (isAllowedModuleDecl(decl)) exported.add(decl);
    }
    if (item is ExportAllDecl) {
      if (item.exportedIdent != null && item.exportedIdent!.isNotEmpty) {
        final decl = ExportNamedDeclaration(
          declaration: null,
          specifiers: [
            ExportNamespaceSpecifier(
              exported: Identifier(name: item.exportedIdent!),
            ),
          ],
          source: StringLiteral(stringValue: item.src),
        );
        if (isAllowedModuleDecl(decl)) exported.add(decl);
      } else {
        final decl = ExportAllDeclaration(
          source: StringLiteral(stringValue: item.src),
        );
        if (isAllowedModuleDecl(decl)) exported.add(decl);
      }
    }
  }
  // Post-check: normal <script> forbids duplicate export default
  if (!isScriptSetup) {
    final defaultPositions = <ErrorPos>[];
    for (final item in m.body) {
      if (item is ExportDefaultDecl || item is ExportDefaultExpr) {
        final node = (item as dynamic).node as Node;
        defaultPositions.add(ErrorPos(node.locStart.line, node.locStart.column));
      }
    }
    if (defaultPositions.length > 1) {
      final err = DeclarationParseError(
        filename: filename ?? './unknown',
        message: '普通<script>中不允许重复声明export default',
        positions: defaultPositions,
        contextLines: errConfig?.contextLines ?? 3,
        kind: 'export',
      );
      final rendered = ErrorRenderer.render(
        err,
        src,
        config: errConfig ?? const ErrorReportConfig(),
      );
      logger.warn(rendered);
      throw StateError(rendered);
    }
  }
  return CompilationUnit(
    startByte: 0,
    endByte: src.length,
    text: src,
    statements: statements,
    imported: imported,
    exported: exported,
    userVariables: userVariables,
  );
}

bool isSimpleIdentifier(String s) {
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

String? outerBracesBody(String s) {
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

bool isWhitespace(int c) {
  return c == 32 || c == 9 || c == 10 || c == 13;
}

bool isIdentChar(int c) {
  return (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      (c >= 48 && c <= 57) ||
      c == 95 ||
      c == 36;
}

String slice(String src, int startByte, int endByte) {
  final bytes = utf8.encode(src);
  final s = startByte.clamp(0, bytes.length);
  final e = endByte.clamp(0, bytes.length);
  if (e <= s) return '';
  return utf8.decode(bytes.sublist(s, e));
}

// Deprecated: module line formatting
// Kept as no-op helpers removed

bool isAllowedModuleDecl(Declaration d) {
  return d is ImportDeclaration ||
      d is ExportAllDeclaration ||
      d is ExportNamedDeclaration ||
      d is ExportDefaultDeclaration;
}
