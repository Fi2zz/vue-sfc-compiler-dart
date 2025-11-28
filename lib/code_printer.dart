// ignore_for_file: unnecessary_null_comparison

import 'dart:convert';

import 'package:vue_sfc_parser/ast.dart';

/// CodePrinter converts AST nodes to normalized source code strings.
/// It uses a simple visitor-style dispatcher and maintains indentation.
class CodePrinter {
  CodePrinter._();
  static String printCompilationUnit(CompilationUnit unit) {
    final s = _PrinterState();
    for (final d in unit.imported) {
      _printNode(d, s);
      _newline(s);
    }
    final cs = unit.comments;
    if (cs != null && cs.isNotEmpty) {
      for (final c in cs) {
        final before = s.buf.length;
        _indentWrite(CodePrinter.printComment(c), s);
        final after = s.buf.length;
        final len = after - before;
        final origStart = c.loc?.start.index ?? c.start ?? 0;
        final origEnd = c.loc?.end.index ?? c.end ?? origStart + len;
        if (len > 0) {
          s.mappings.add(
            _MapEntry(
              genStart: before,
              genEnd: after,
              origStart: origStart,
              origEnd: origEnd,
            ),
          );
        }
        _newline(s);
      }
    }
    for (final sst in unit.statements) {
      final before = s.buf.length;
      _printNode(sst, s);
      final after = s.buf.length;
      final len = after - before;
      if (len > 0 && sst.loc != null) {
        s.mappings.add(
          _MapEntry(
            genStart: before,
            genEnd: after,
            origStart: sst.loc!.start.index,
            origEnd: sst.loc!.end.index,
          ),
        );
      }
      _newline(s);
    }
    for (final d in unit.exported) {
      _printNode(d, s);
      _newline(s);
    }
    return s.buf.toString();
  }

  static GeneratedSource printCompilationUnitWithSourceMap(
    CompilationUnit unit,
  ) {
    final s = _PrinterState();
    final code = _emitCompilationUnit(unit, s);
    final mappings = s.mappings
        .map(
          (m) => Mapping(
            generatedStart: m.genStart,
            generatedEnd: m.genEnd,
            originalStart: m.origStart,
            originalEnd: m.origEnd,
          ),
        )
        .toList(growable: false);
    return GeneratedSource(code: code, mappings: mappings);
  }

  static String _emitCompilationUnit(CompilationUnit unit, _PrinterState s) {
    for (final d in unit.imported) {
      _printNode(d, s);
      _newline(s);
    }
    final cs = unit.comments;
    if (cs != null && cs.isNotEmpty) {
      for (final c in cs) {
        final before = s.buf.length;
        _indentWrite(CodePrinter.printComment(c), s);
        final after = s.buf.length;
        final len = after - before;
        final origStart = c.loc?.start.index ?? c.start ?? 0;
        final origEnd = c.loc?.end.index ?? c.end ?? origStart + len;
        if (len > 0) {
          s.mappings.add(
            _MapEntry(
              genStart: before,
              genEnd: after,
              origStart: origStart,
              origEnd: origEnd,
            ),
          );
        }
        _newline(s);
      }
    }
    for (final sst in unit.statements) {
      final before = s.buf.length;
      _printNode(sst, s);
      final after = s.buf.length;
      final len = after - before;
      if (len > 0 && sst.loc != null) {
        s.mappings.add(
          _MapEntry(
            genStart: before,
            genEnd: after,
            origStart: sst.loc!.start.index,
            origEnd: sst.loc!.end.index,
          ),
        );
      }
      _newline(s);
    }
    for (final d in unit.exported) {
      _printNode(d, s);
      _newline(s);
    }
    return s.buf.toString();
  }

  static String printNode(BaseNode node) {
    final s = _PrinterState();
    _printNode(node, s);
    return s.buf.toString();
  }

  static String print(BaseNode node) {
    return printNode(node);
  }

  static String printProgram(Program program) {
    final s = _PrinterState();
    for (final st in program.body) {
      _printNode(st, s);
      if (!_endsWithNewline(s)) s.buf.write('\n');
    }
    return s.buf.toString();
  }

  static bool _endsWithNewline(_PrinterState s) {
    final t = s.buf.toString();
    return t.isNotEmpty && t.codeUnitAt(t.length - 1) == 10;
  }

  static String _exprText(Expression? e, _PrinterState s) {
    if (e == null) return '';
    final saved = StringBuffer();
    final oldBufContent = s.buf.toString();
    saved.write(oldBufContent);
    s.buf.clear();
    _printNode(e, s);
    final out = s.buf.toString();
    s.buf.clear();
    s.buf.write(saved.toString());
    return out;
  }

  static void _indentWrite(String str, _PrinterState s) {
    for (int i = 0; i < s.indent; i++) {
      s.buf.write(s.indentUnit);
    }
    s.buf.write(str);
  }

  static void _newline(_PrinterState s) {
    s.buf.write('\n');
  }

  static String _patternText(BindingPattern p, _PrinterState s) {
    final saved = StringBuffer();
    saved.write(s.buf.toString());
    s.buf.clear();
    _printNode(p, s);
    final out = s.buf.toString();
    s.buf.clear();
    s.buf.write(saved.toString());
    return out;
  }

  static void _printNode(dynamic node, _PrinterState s) {
    if (node == null) return;
    if (node is ExpressionStatement) {
      final t = node.text;
      if (t.isNotEmpty) {
        _indentWrite(t, s);
      } else {
        _indentWrite(_exprText(node.expression, s), s);
      }
      return;
    }
    if (node is Identifier) {
      s.buf.write(
        node.name.isNotEmpty
            ? node.name
            : (node.text.isNotEmpty ? node.text : ''),
      );
      return;
    }
    if (node is StringLiteral) {
      s.buf.write(_quote(node.stringValue));
      return;
    }
    if (node is NumberLiteral) {
      s.buf.write(node.value.toString());
      return;
    }
    if (node is NumericLiteral) {
      s.buf.write(node.value.toString());
      return;
    }
    if (node is BooleanLiteral) {
      s.buf.write(node.value ? 'true' : 'false');
      return;
    }
    if (node is NullLiteral) {
      s.buf.write('null');
      return;
    }
    if (node is ArgumentList) {
      final parts = node.arguments.map((e) => _exprText(e, s)).join(', ');
      s.buf.write(parts);
      return;
    }
    if (node is FunctionCallExpression) {
      if (node.text.isNotEmpty) {
        final t = node.text.trimRight();
        if (t.endsWith(';')) {
          _indentWrite(t, s);
        } else {
          _indentWrite('$t;', s);
        }
      } else {
        final callee = node.methodName.name;
        final typeArgs =
            node.typeArgumentText ??
            _typeParamsText(node.extra?['typeParameters']);
        s.buf.write('$callee$typeArgs(');
        _printNode(node.argumentList, s);
        s.buf.write(');');
      }
      return;
    }
    if (node is MapLiteralEntry) {
      final kind = (node.extra is Map<String, Object?>)
          ? (node.extra as Map<String, Object?>)['kind'] as String?
          : null;
      final op = (node.extra is Map<String, Object?>)
          ? (node.extra as Map<String, Object?>)['op'] as String?
          : null;
      if (kind == 'Method' || kind == 'Getter' || kind == 'Setter') {
        s.buf.write(node.keyText);
        s.buf.write('(');
        if (node.value is FunctionExpression) {
          final fn = node.value as FunctionExpression;
          for (int i = 0; i < fn.params.length; i++) {
            _printNode(fn.params[i], s);
            if (i + 1 < fn.params.length) s.buf.write(', ');
          }
        } else if (node.value is ArrowFunctionExpression) {
          final fn = node.value as ArrowFunctionExpression;
          for (int i = 0; i < fn.params.length; i++) {
            _printNode(fn.params[i], s);
            if (i + 1 < fn.params.length) s.buf.write(', ');
          }
        }
        s.buf.write(') ');
        s.buf.write('{ }');
      } else {
        s.buf.write(node.keyText);
        s.buf.write(op == '=' ? ' = ' : ': ');
        _printNode(node.value, s);
      }
      return;
    }
    if (node is SetOrMapLiteral) {
      s.buf.write('{ ');
      for (int i = 0; i < node.elements.length; i++) {
        _printNode(node.elements[i], s);
        if (i + 1 < node.elements.length) s.buf.write(', ');
      }
      s.buf.write(' }');
      return;
    }
    if (node is VariableDeclaration) {
      final kind = node.declKind;
      final lhs = node.pattern != null
          ? _patternText(node.pattern!, s)
          : node.name.name;
      _indentWrite('$kind $lhs', s);
      if (node.init != null) {
        s.buf.write(' = ');
        _printNode(node.init, s);
      }
      s.buf.write(';');
      return;
    }
    if (node is AssignmentExpression) {
      final l = _exprText(node.left, s);
      final r = _exprText(node.right, s);
      s.buf.write('$l ${node.operator} $r');
      return;
    }
    if (node is BinaryExpression) {
      final l = _exprText(node.left, s);
      final r = _exprText(node.right, s);
      s.buf.write('$l ${node.operator} $r');
      return;
    }
    if (node is LogicalExpression) {
      final l = _exprText(node.left, s);
      final r = _exprText(node.right, s);
      s.buf.write('$l ${node.operator} $r');
      return;
    }
    if (node is ConditionalExpression) {
      final test = _exprText(node.test, s);
      final cons = _exprText(node.consequent, s);
      final alt = _exprText(node.alternate, s);
      s.buf.write('$test ? $cons : $alt');
      return;
    }
    if (node is MemberExpression) {
      final obj = _exprText(node.object as Expression, s);
      if (node.computed) {
        final prop = _exprText(node.property as Expression, s);
        s.buf.write('$obj[$prop]');
      } else {
        if (node.property is Identifier) {
          s.buf.write('$obj.${(node.property as Identifier).name}');
        } else {
          final prop = _exprText(node.property as Expression, s);
          s.buf.write('$obj.$prop');
        }
      }
      return;
    }
    if (node is RestElement) {
      final arg = node.argument is Identifier
          ? (node.argument as Identifier).name
          : _exprText(node.argument as Expression, s);
      s.buf.write('...$arg');
      return;
    }
    if (node is AssignmentPattern) {
      final l = _exprText(node.left as Expression, s);
      final r = _exprText(node.right, s);
      s.buf.write('$l = $r');
      return;
    }
    if (node is ArrayPattern) {
      s.buf.write('[ ');
      for (int i = 0; i < node.elements.length; i++) {
        final el = node.elements[i];
        if (el != null) {
          _printNode(el, s);
        }
        if (i + 1 < node.elements.length) s.buf.write(', ');
      }
      s.buf.write(' ]');
      return;
    }
    if (node is ObjectPattern) {
      s.buf.write('{ ');
      for (int i = 0; i < node.properties.length; i++) {
        final p = node.properties[i];
        if (p is RestElement) {
          s.buf.write('...');
          _printNode(p.argument, s);
        } else if (p is ObjectProperty) {
          final computed = p.computed;
          String? keyName;
          if (!computed) {
            if (p.key is Identifier) {
              keyName = (p.key as Identifier).name;
            } else if (p.key is StringLiteral) {
              keyName = (p.key as StringLiteral).stringValue;
            }
          }
          void writeKey() {
            if (computed) {
              s.buf.write('[');
              _printNode(p.key, s);
              s.buf.write(']');
            } else if (keyName != null) {
              s.buf.write(keyName);
            } else {
              _printNode(p.key, s);
            }
          }

          if (p.value is Identifier) {
            final vname = (p.value as Identifier).name;
            if (p.shorthand && keyName == vname) {
              s.buf.write(keyName ?? vname);
            } else {
              writeKey();
              s.buf.write(': ');
              s.buf.write(vname);
            }
          } else if (p.value is AssignmentPattern) {
            final ap = p.value as AssignmentPattern;
            if (ap.left is Identifier &&
                keyName == (ap.left as Identifier).name &&
                p.shorthand) {
              s.buf.write('$keyName = ${_exprText(ap.right, s)}');
            } else {
              writeKey();
              s.buf.write(': ');
              _printNode(ap.left, s);
              s.buf.write(' = ');
              _printNode(ap.right, s);
            }
          } else {
            writeKey();
            s.buf.write(': ');
            _printNode(p.value, s);
          }
        }
        if (i + 1 < node.properties.length) s.buf.write(', ');
      }
      s.buf.write(' }');
      return;
    }
    if (node is ObjectExpression) {
      s.buf.write('{ ');
      for (int i = 0; i < node.properties.length; i++) {
        _printNode(node.properties[i], s);
        if (i + 1 < node.properties.length) s.buf.write(', ');
      }
      s.buf.write(' }');
      return;
    }
    if (node is ObjectProperty) {
      final computed = node.computed;
      if (computed) {
        s.buf.write('[');
        _printNode(node.key, s);
        s.buf.write(']');
      } else {
        if (node.key is Identifier) {
          final k = (node.key as Identifier).name;
          if (node.shorthand &&
              node.value is Identifier &&
              (node.value as Identifier).name == k) {
            s.buf.write(k);
            return;
          }
          s.buf.write(k);
        } else {
          _printNode(node.key, s);
        }
      }
      s.buf.write(': ');
      _printNode(node.value, s);
      return;
    }
    if (node is ObjectMethod) {
      final kind = node.kind;
      if (kind == 'get' || kind == 'set') {
        s.buf.write('$kind ');
      }
      final computed = node.computed;
      if (computed) {
        s.buf.write('[');
        _printNode(node.key, s);
        s.buf.write(']');
      } else {
        _printNode(node.key, s);
      }
      s.buf.write('(');
      for (int i = 0; i < node.params.length; i++) {
        _printNode(node.params[i], s);
        if (i + 1 < node.params.length) s.buf.write(', ');
      }
      s.buf.write(') ');
      final bodyText = _methodBodyText(node);
      if (bodyText != null) {
        s.buf.write('{ ');
        s.buf.write(bodyText);
        s.buf.write(' }');
      } else {
        s.buf.write('{ }');
      }
      return;
    }
    if (node is ArrowFunctionExpression) {
      if (node.text.isNotEmpty) {
        _indentWrite(node.text, s);
        return;
      }
      s.buf.write('(');
      for (int i = 0; i < node.params.length; i++) {
        _printNode(node.params[i], s);
        if (i + 1 < node.params.length) s.buf.write(', ');
      }
      s.buf.write(') => ');
      if (node.body is BlockStatement) {
        s.buf.write('{ }');
      } else {
        _printNode(node.body, s);
      }
      return;
    }
    if (node is FunctionExpression) {
      if (node.text.isNotEmpty) {
        _indentWrite(node.text, s);
        return;
      }
      s.buf.write('function(');
      for (int i = 0; i < node.params.length; i++) {
        _printNode(node.params[i], s);
        if (i + 1 < node.params.length) s.buf.write(', ');
      }
      s.buf.write(') { }');
      return;
    }
    if (node is BigIntLiteral) {
      s.buf.write(node.value.toString());
      return;
    }
    if (node is DecimalLiteral) {
      s.buf.write(node.value);
      return;
    }
    if (node is BreakStatement) {
      s.buf.write('break');
      if (node.label != null) s.buf.write(' ${node.label!.name}');
      s.buf.write(';');
      return;
    }
    if (node is ContinueStatement) {
      s.buf.write('continue');
      if (node.label != null) s.buf.write(' ${node.label!.name}');
      s.buf.write(';');
      return;
    }
    if (node is TryStatement) {
      s.buf.write('try ');
      _printNode(node.block, s);
      if (node.handler != null) {
        s.buf.write(' catch (');
        if (node.handler!.param != null) {
          _printNode(node.handler!.param!, s);
        }
        s.buf.write(') ');
        _printNode(node.handler!.body, s);
      }
      if (node.finalizer != null) {
        s.buf.write(' finally ');
        _printNode(node.finalizer!, s);
      }
      return;
    }
    if (node is IfStatement) {
      final test = _exprText(node.test, s);
      s.buf.write('if ($test) ');
      _printNode(node.consequent, s);
      if (node.alternate != null) {
        s.buf.write(' else ');
        _printNode(node.alternate!, s);
      }
      return;
    }
    if (node is WhileStatement) {
      final test = _exprText(node.test, s);
      s.buf.write('while ($test) ');
      _printNode(node.body, s);
      return;
    }
    if (node is ForStatement) {
      final initStr = node.init == null
          ? ''
          : _exprText(node.init as Expression, s);
      final testStr = node.test == null ? '' : _exprText(node.test!, s);
      final updateStr = node.update == null ? '' : _exprText(node.update!, s);
      s.buf.write('for ($initStr; $testStr; $updateStr) ');
      _printNode(node.body, s);
      return;
    }
    if (node is DoWhileStatement) {
      s.buf.write('do ');
      _printNode(node.body, s);
      s.buf.write(' while (');
      _printNode(node.test, s);
      s.buf.write(');');
      return;
    }
    if (node is SwitchStatement) {
      final disc = _exprText(node.discriminant, s);
      s.buf.write('switch ($disc) { ');
      for (final c in node.cases) {
        if (c.test != null) {
          s.buf.write('case ');
          _printNode(c.test!, s);
          s.buf.write(': ');
        } else {
          s.buf.write('default: ');
        }
        for (int i = 0; i < c.consequent.length; i++) {
          _printNode(c.consequent[i], s);
          if (i + 1 < c.consequent.length) s.buf.write(' ');
        }
      }
      s.buf.write(' }');
      return;
    }
    if (node is ThrowStatement) {
      s.buf.write('throw ');
      _printNode(node.argument, s);
      s.buf.write(';');
      return;
    }
    if (node is ObjectBindingPattern) {
      final props = node.properties
          .map((p) {
            final key = p.key;
            if (p.alias != null && p.defaultValue != null) {
              return '$key: ${p.alias!.name} = ${_exprText(p.defaultValue, s)}';
            }
            if (p.alias != null) {
              return '$key: ${p.alias!.name}';
            }
            if (p.defaultValue != null) {
              return '$key = ${_exprText(p.defaultValue, s)}';
            }
            return key;
          })
          .join(', ');
      s.buf.write('{ $props }');
      return;
    }
    if (node is ArrayBindingPattern) {
      final parts = node.elements
          .map((e) {
            final n = e.target?.name ?? '';
            if (e.isRest) return '...$n';
            if (e.defaultValue != null) {
              return '$n = ${_exprText(e.defaultValue, s)}';
            }
            return n;
          })
          .join(', ');
      s.buf.write('[ $parts ]');
      return;
    }
    // Declarations (imports/exports)
    if (node is FunctionDeclaration) {
      if (node.text.isNotEmpty) {
        _indentWrite(node.text, s);
        return;
      }
    }
    if (node is ImportDeclaration) {
      if (node.text.isNotEmpty) {
        _indentWrite(node.text, s);
        return;
      }
      String? defaultLocal;
      String? namespaceLocal;
      final named = <String>[];
      for (final s in node.specifiers) {
        if (s is ImportDefaultSpecifier) {
          defaultLocal = s.local.name;
        } else if (s is ImportNamespaceSpecifier) {
          namespaceLocal = s.local.name;
        } else if (s is ImportSpecifier) {
          String imported;
          if (s.imported is Identifier) {
            imported = (s.imported as Identifier).name;
          } else if (s.imported is StringLiteral) {
            imported = (s.imported as StringLiteral).stringValue;
          } else {
            imported = s.local.name;
          }
          if (imported == s.local.name) {
            named.add(imported);
          } else {
            named.add('$imported as ${s.local.name}');
          }
        }
      }
      final src = node.source.stringValue;
      if (namespaceLocal != null) {
        _indentWrite("import * as $namespaceLocal from ${_quote(src)};", s);
        return;
      }
      if (defaultLocal != null && named.isEmpty) {
        _indentWrite("import $defaultLocal from ${_quote(src)};", s);
        return;
      }
      if (defaultLocal != null && named.isNotEmpty) {
        _indentWrite(
          "import $defaultLocal, { ${named.join(', ')} } from ${_quote(src)};",
          s,
        );
        return;
      }
      _indentWrite("import { ${named.join(', ')} } from ${_quote(src)};", s);
      return;
    }
    if (node is ExportDefaultDeclaration) {
      if (node.text.isNotEmpty) {
        _indentWrite(node.text, s);
        return;
      }
      _indentWrite('export default', s);
      if (node.declaration != null) {
        s.buf.write(' ');
        _printNode(node.declaration, s);
      }
      return;
    }
    if (node is ExportNamedDeclaration) {
      if (node.text.isNotEmpty) {
        _indentWrite(node.text, s);
        return;
      }
      final src = node.source?.stringValue;
      final hasNs =
          node.specifiers.length == 1 &&
          node.specifiers.first is ExportNamespaceSpecifier;
      if (hasNs && src != null) {
        final ns =
            (node.specifiers.first as ExportNamespaceSpecifier).exported.name;
        _indentWrite("export * as $ns from ${_quote(src)};", s);
        return;
      }
      final parts = node.specifiers
          .map((e) {
            if (e is ExportNamespaceSpecifier) return '* as ${e.exported.name}';
            if (e is ExportDefaultSpecifier) return e.exported.name;
            if (e is ExportSpecifier) {
              final exp = e.exported is Identifier
                  ? (e.exported as Identifier).name
                  : (e.exported as StringLiteral).stringValue;
              if (exp == e.local.name) return e.local.name;
              return '${e.local.name} as $exp';
            }
            return '';
          })
          .where((s) => s.isNotEmpty)
          .join(', ');
      if (src != null) {
        _indentWrite("export { $parts } from ${_quote(src)};", s);
      } else {
        _indentWrite("export { $parts };", s);
      }
      return;
    }
    if (node is ExportAllDeclartion) {
      if (node.text.isNotEmpty) {
        _indentWrite(node.text, s);
        return;
      }
      final src = node.source.stringValue;
      if (node.exported != null && node.exported!.name.isNotEmpty) {
        _indentWrite(
          'export * as ${node.exported!.name} from ${_quote(src)};',
          s,
        );
      } else {
        _indentWrite('export * from ${_quote(src)};', s);
      }
      return;
    }

    // Generic fallback: use node.text if available; else do nothing
    if (node is BaseNode && node.text.isNotEmpty) {
      _indentWrite(node.text, s);
      return;
    }
  }

  static String _typeParamsText(Object? tp) {
    if (tp is TSTypeParameterInstantiation) {
      final parts = tp.params.map((p) => _typeText(p)).join(', ');
      return parts.isEmpty ? '' : '<$parts>';
    }
    return '';
  }

  static String _typeText(TSType t) {
    if (t is TSTypeReference) return t.name;
    if (t is TSStringKeyword) return 'string';
    if (t is TSNumberKeyword) return 'number';
    if (t is TSBooleanKeyword) return 'boolean';
    if (t is TSNullKeyword) return 'null';
    if (t is TSUndefinedKeyword) return 'undefined';
    if (t is TSObjectType) {
      if (t.members.isEmpty) return '{}';
      final buf = StringBuffer();
      buf.write('{ ');
      for (int i = 0; i < t.members.length; i++) {
        final m = t.members[i];
        final keyStr = m.key is Identifier
            ? (m.key as Identifier).name
            : m.key is StringLiteral
            ? (m.key as StringLiteral).stringValue
            : 'key';
        buf.write(keyStr);
        if (m.optional) buf.write('?');
        buf.write(': ');
        final ann = m.typeAnnotation;
        if (ann != null) {
          buf.write(_typeText(ann.typeAnnotation));
        } else {
          buf.write('any');
        }
        buf.write(';');
        if (i + 1 < t.members.length) buf.write(' ');
      }
      buf.write(' }');
      return buf.toString();
    }
    if (t is TSIndexSignature) {
      final keyName = t.keyName;
      final keyType = _typeText(t.keyType);
      final valueType = _typeText(t.valueType);
      return '{ [$keyName: $keyType]: $valueType }';
    }
    if (t is TSMappedType) {
      final ro = t.readonly ? 'readonly ' : '';
      final opt = t.optional ? '?' : '';
      final src = _typeText(t.sourceType);
      final val = _typeText(t.valueType);
      return '{ $ro[${t.paramName} in $src]$opt: $val }';
    }
    if (t is TSLiteralType) return t.text;
    if (t is TSUnionType) {
      final texts = <String>[];
      for (final c in t.types) {
        var ct = _typeText(c);
        if (c is TSIntersectionType) ct = '($ct)';
        texts.add(ct);
      }
      return texts.join(' | ');
    }
    if (t is TSIntersectionType) {
      final texts = <String>[];
      for (final c in t.types) {
        var ct = _typeText(c);
        if (c is TSUnionType) ct = '($ct)';
        texts.add(ct);
      }
      return texts.join(' & ');
    }
    if (t is TSParenthesizedType) {
      return '(' + _typeText(t.type) + ')';
    }
    if (t is TSKeyofType) {
      return 'keyof ' + _typeText(t.argument);
    }
    if (t is TSInferType) {
      final cons = t.constraint == null
          ? ''
          : ' extends ' + _typeText(t.constraint!);
      return 'infer ' + t.name + cons;
    }
    if (t is TSConditionalType) {
      final check = _typeText(t.checkType);
      final ext = _typeText(t.extendsType);
      final tru = _typeText(t.trueType);
      final fal = _typeText(t.falseType);
      return '$check extends $ext ? $tru : $fal';
    }
    if (t is TSArrayType) {
      final elem = _typeText(t.elementType);
      final ro = t.readonly ? 'readonly ' : '';
      return '$ro$elem[]';
    }
    if (t is TSTupleType) {
      final elems = t.elementTypes.map((e) => _typeText(e)).join(', ');
      return '[$elems]';
    }
    if (t is TSIndexedAccessType) {
      final obj = _typeText(t.objectType);
      final idx = _typeText(t.indexType);
      return '$obj[$idx]';
    }
    return 'any';
  }

  static String? _methodBodyText(ObjectMethod m) {
    final extra = m.extra;
    if (extra is Map<String, Object?>) {
      final t = extra['text'];
      if (t is String && t.isNotEmpty) {
        final i = t.indexOf('{');
        if (i >= 0) {
          int depth = 0;
          for (int j = i; j < t.length; j++) {
            final ch = t[j];
            if (ch == '{') depth++;
            if (ch == '}') {
              depth--;
              if (depth == 0) {
                return t.substring(i + 1, j).trim();
              }
            }
          }
        }
        return t;
      }
    }
    return null;
  }

  static String _quote(String s) {
    final raw = json.encode(s);
    return raw;
  }

  /// Format a Comment node into its source string representation.
  /// - Line comments are emitted as `// <value>`
  /// - Block comments are emitted as `/* <value> */` for single-line,
  ///   or as:
  // ignore: unintended_html_in_doc_comment
  ///     /*\n<value>\n*/
  ///   when the comment contains newlines.
  /// Special terminator sequences inside block values are escaped.
  static String printComment(Comment comment) {
    if (comment is CommentLine) {
      final v = _escapeLine(comment.value);
      return '// $v';
    }
    if (comment is CommentBlock) {
      final v = _escapeBlock(comment.value);
      if (v.contains('\n')) {
        return '/*\n$v\n*/';
      } else {
        return '/* $v */';
      }
    }
    // Fallback: treat as line comment
    return '// ${_escapeLine(comment.value)}';
  }

  static String _escapeLine(String s) {
    // Minimal escaping for control characters
    return s.replaceAll('\r', '');
  }

  static String _escapeBlock(String s) {
    // Prevent accidental block termination
    var out = s.replaceAll('*/', '*\\/');
    // Normalize CRLF
    out = out.replaceAll('\r', '');
    return out;
  }
}

class _PrinterState {
  final StringBuffer buf = StringBuffer();
  final int indent = 0;
  final String indentUnit = '  ';
  final List<_MapEntry> mappings = <_MapEntry>[];
}

class _MapEntry {
  final int genStart;
  final int genEnd;
  final int origStart;
  final int origEnd;
  _MapEntry({
    required this.genStart,
    required this.genEnd,
    required this.origStart,
    required this.origEnd,
  });
}

class GeneratedSource {
  final String code;
  final List<Mapping> mappings;
  GeneratedSource({required this.code, required this.mappings});
}

class Mapping {
  final int generatedStart;
  final int generatedEnd;
  final int originalStart;
  final int originalEnd;
  Mapping({
    required this.generatedStart,
    required this.generatedEnd,
    required this.originalStart,
    required this.originalEnd,
  });
}

void printArgNames(ExpressionStatement node) {
  final exp = node.expression as FunctionCallExpression;
  for (final arg in exp.argumentList.arguments) {
    print('arg runtimeType: ${arg.runtimeType}');
    if (arg is SetOrMapLiteral) {
      for (final entry in arg.elements) {
        print('(node  as Identifier).name ${entry.keyText}');
      }
    } else if (arg is Identifier) {
      print('(node  as Identifier).name ${arg.name}');
    }
  }
}
