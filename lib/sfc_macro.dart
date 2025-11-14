import 'ts_ast.dart';
import 'ts_parser.dart';

// Alias map for TypeScript type_alias_declaration -> its literal body (if any)

final Map<AstNode, AstNode> _aliasNodes = {};
final Map<String, AstNode> _aliasTypeLiteral = {};

/* ---------- helpers: TS type arguments (top-level) ---------- */
List<PropSignature> _extractTypeProps(AstNode typeArgs, String src) {
  final out = <PropSignature>[];
  final raw = src.substring(typeArgs.startByte, typeArgs.endByte).trim();
  final singleIdent = RegExp(r'^<\s*[A-Za-z_$]\w*\s*>$').hasMatch(raw);
  void walk(AstNode n) {
    // property_signature nodes define fields in type literals
    if (n.type == 'property_signature') {
      String name = '';
      String? type;
      bool required = true;
      for (final c in n.children) {
        if (c.type == 'property_identifier' || c.type == 'identifier') {
          name = src.substring(c.startByte, c.endByte);
        } else if (c.type == 'type_annotation') {
          final text = src.substring(c.startByte, c.endByte).trim();
          // strip leading ':' in annotation
          type = text.startsWith(':') ? text.substring(1).trim() : text;
        } else if (c.type == '?') {
          required = false;
        }
      }
      // Fallback: detect optional marker via source text pattern '?:'
      if (required) {
        final sigText = src.substring(n.startByte, n.endByte);
        if (RegExp(r'\?\s*:').hasMatch(sigText)) {
          required = false;
        }
      }
      if (name.isNotEmpty) {
        out.add(PropSignature(name: name, type: type, required: required));
      }
      return; // done with this property signature
    }
    // index_signature, e.g. { [key: string]: any }
    if (n.type == 'index_signature') {
      String name = '[index]';
      String? type;
      for (final c in n.children) {
        if (c.type == 'identifier') {
          final id = src.substring(c.startByte, c.endByte);
          name = '[$id]';
        } else if (c.type == 'type_annotation') {
          final text = src.substring(c.startByte, c.endByte).trim();
          type = text.startsWith(':') ? text.substring(1).trim() : text;
        }
      }
      out.add(PropSignature(name: name, type: type, required: true));
      return;
    }
    // generic type literal containers
    for (final ch in n.children) {
      walk(ch);
    }
  }

  // Resolve references like <Props> by looking up collected aliases
  final refs = <String>[];
  void collectRefs(AstNode n) {
    if (n.type == 'type_identifier' || n.type == 'identifier') {
      refs.add(src.substring(n.startByte, n.endByte));
    }
    for (final ch in n.children) {
      collectRefs(ch);
    }
  }

  collectRefs(typeArgs);
  if (singleIdent) {
    for (final r in refs) {
      final alias = _aliasTypeLiteral[r];
      if (alias != null) {
        walk(alias);
      }
    }
  }

  // Also walk the raw type arguments to support inline literals <{ foo: string }>
  walk(typeArgs);
  return out;
}

/* ==================== Converter ==================== */

CompilationUnit converter(AstNode root, String src) {
  _aliasNodes.clear();
  _aliasTypeLiteral.clear();
  final statements = <ExpressionStatement>[];
  void walk(AstNode n) {
    // collect call expressions anywhere
    if (n.type == 'call_expression') {
      final call = toCall(n, src);
      if (call != null) {
        statements.add(
          ExpressionStatement(
            startByte: n.startByte,
            endByte: n.endByte,
            text: src.substring(n.startByte, n.endByte),
            expression: call,
          ),
        );
      }
    }
    // collect type aliases for resolving type arguments
    if (n.type == 'type_alias_declaration') {
      String name = '';
      AstNode? body;
      for (final c in n.children) {
        if (c.type == 'type_identifier' || c.type == 'identifier') {
          name = src.substring(c.startByte, c.endByte);
        } else if (c.type == 'type_literal' || c.type == 'object_type') {
          body = c;
        }
      }
      _aliasNodes[n] = body ?? n;
      if (name.isNotEmpty) _aliasTypeLiteral[name] = body ?? n;
    }
    // collect interfaces for resolving type arguments like <Props>
    if (n.type == 'interface_declaration') {
      String name = '';
      AstNode? body;
      for (final c in n.children) {
        if (c.type == 'type_identifier' || c.type == 'identifier') {
          name = src.substring(c.startByte, c.endByte);
        } else if (c.type == 'interface_body' ||
            c.type == 'object_type' ||
            c.type == 'type_literal') {
          body = c;
        }
      }
      if (name.isNotEmpty) {
        _aliasTypeLiteral[name] = body ?? n;
      }
    }
    for (final c in n.children) {
      walk(c);
    }
  }

  walk(root);
  return CompilationUnit(
    startByte: root.startByte,
    endByte: root.endByte,
    text: src.substring(root.startByte, root.endByte),
    statements: statements,
  );
}

FunctionCallExpression? toCall(AstNode node, String src) {
  // Find identifier callee and arguments
  AstNode? ident;
  AstNode? typeArgs;
  AstNode? args;
  for (final c in node.children) {
    if (c.type == 'identifier') ident = c;
    if (c.type == 'type_arguments') typeArgs = c;
    if (c.type == 'arguments') args = c;
  }
  if (ident == null || args == null) return null;
  final methodName = Identifier(
    startByte: ident.startByte,
    endByte: ident.endByte,
    text: src.substring(ident.startByte, ident.endByte),
  );
  final argList = toArgumentList(args, src);
  final rawTypeText = typeArgs == null
      ? null
      : src.substring(typeArgs.startByte, typeArgs.endByte);
  final List<PropSignature> typeProps = typeArgs == null
      ? const <PropSignature>[]
      : _extractTypeProps(typeArgs, src);
  return FunctionCallExpression(
    startByte: node.startByte,
    endByte: node.endByte,
    text: src.substring(node.startByte, node.endByte),
    methodName: methodName,
    argumentList: argList,
    typeArgumentText: rawTypeText,
    typeArgumentProps: typeProps,
  );
}

ArgumentList toArgumentList(AstNode args, String src) {
  final list = <Expression>[];
  for (final c in args.children) {
    final e = toExpression(c, src);
    if (e != null) list.add(e);
  }
  return ArgumentList(
    startByte: args.startByte,
    endByte: args.endByte,
    text: src.substring(args.startByte, args.endByte),
    arguments: list,
  );
}

Expression? toExpression(AstNode n, String src) {
  switch (n.type) {
    case 'object':
      return toObject(n, src);
    case 'array':
      return toArray(n, src);
    case 'string':
    case 'template_string':
      final text = src.substring(n.startByte, n.endByte);
      // strip quotes/backticks
      final value = text.length >= 2
          ? text.substring(1, text.length - 1)
          : text;
      return StringLiteral(
        startByte: n.startByte,
        endByte: n.endByte,
        text: text,
        stringValue: value,
      );
    case 'true':
      return BooleanLiteral(
        startByte: n.startByte,
        endByte: n.endByte,
        text: 'true',
        value: true,
      );
    case 'false':
      return BooleanLiteral(
        startByte: n.startByte,
        endByte: n.endByte,
        text: 'false',
        value: false,
      );
    case 'identifier':
      return Identifier(
        startByte: n.startByte,
        endByte: n.endByte,
        text: src.substring(n.startByte, n.endByte),
      );
    case 'call_expression':
      return toCall(n, src);
  }
  // Fallback: capture source text for unsupported nodes (e.g., arrow functions)
  return RawExpression(
    startByte: n.startByte,
    endByte: n.endByte,
    text: src.substring(n.startByte, n.endByte),
  );
}

SetOrMapLiteral toObject(AstNode n, String src) {
  final elements = <MapLiteralEntry>[];
  for (final c in n.children) {
    if (c.type == 'pair') {
      String key = '';
      bool gotKey = false;
      Expression? value;
      for (final p in c.children) {
        if (!gotKey &&
            (p.type == 'property_identifier' || p.type == 'string')) {
          key = src.substring(p.startByte, p.endByte);
          if (p.type == 'string' && key.length >= 2) {
            key = key.substring(1, key.length - 1);
          }
          gotKey = true;
          continue;
        }
        final v = toExpression(p, src);
        if (v != null) value = v;
      }
      if (key.isNotEmpty && value != null) {
        elements.add(
          MapLiteralEntry(
            startByte: c.startByte,
            endByte: c.endByte,
            text: src.substring(c.startByte, c.endByte),
            keyText: key,
            value: value,
          ),
        );
      }
    } else if (c.type == 'shorthand_property_identifier' ||
        c.type == 'identifier') {
      final key = src.substring(c.startByte, c.endByte);
      final value = toExpression(c, src);
      if (value != null && key.isNotEmpty) {
        elements.add(
          MapLiteralEntry(
            startByte: c.startByte,
            endByte: c.endByte,
            text: src.substring(c.startByte, c.endByte),
            keyText: key,
            value: value,
          ),
        );
      }
    }
  }
  return SetOrMapLiteral(
    startByte: n.startByte,
    endByte: n.endByte,
    text: src.substring(n.startByte, n.endByte),
    elements: elements,
  );
}

ListLiteral toArray(AstNode n, String src) {
  final items = <Expression>[];
  for (final c in n.children) {
    final e = toExpression(c, src);
    if (e != null) items.add(e);
  }
  return ListLiteral(
    startByte: n.startByte,
    endByte: n.endByte,
    text: src.substring(n.startByte, n.endByte),
    elements: items,
  );
}

class MacrosParser {
  // 解析 <script setup> 内容，输出 Result（含 Setup 聚合）
  static CompilationUnit parse(String content, {String language = 'ts'}) {
    final parser = TSParser();
    final AstNode root = parser.parse(
      code: content,
      language: language,
      namedOnly: true,
    );
    final ast = converter(root, content);
    return ast;
  }
}
