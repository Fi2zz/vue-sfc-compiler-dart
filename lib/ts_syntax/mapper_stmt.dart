// English comments per ~/REPO rule.
// Statement/declaration-family mappings: oxc ESTree JSON -> tree-sitter CST
// shapes. Part of oxc_mapper.dart.

part of 'oxc_mapper.dart';

extension OxcStmtMapper on OxcMapper {
  /// Dispatch one ESTree statement node to its tree-sitter shape.
  AstNode mapStatement(Map<String, dynamic> n) {
    final type = n['type'] as String;
    final start = n['start'] as int;
    final end = n['end'] as int;
    switch (type) {
      case 'ExpressionStatement':
        return buildNode('expression_statement', start,
            extendStatementEnd(end), [mapExpression(_m(n['expression']))]);
      case 'VariableDeclaration':
        return mapVariableDeclaration(n);
      case 'FunctionDeclaration':
        if (n['id'] == null) return _namelessFunctionStatement(n);
        final kind = n['generator'] == true
            ? 'generator_function_declaration'
            : 'function_declaration';
        return mapFunction(n, kind);
      case 'ClassDeclaration':
        return mapClass(n, 'class_declaration');
      case 'BlockStatement':
        return buildNode('statement_block', start, end, [
          for (final s in n['body'] as List) mapStatement(_m(s)),
        ]);
      case 'IfStatement':
        return mapIf(n);
      case 'ForStatement':
        return mapFor(n);
      case 'ForInStatement':
      case 'ForOfStatement':
        return mapForIn(n);
      case 'WhileStatement':
        return buildNode('while_statement', start, end, [
          mapParenCondition(_m(n['test'])),
          mapStatement(_m(n['body'])),
        ]);
      case 'DoWhileStatement':
        return buildNode('do_statement', start, end, [
          mapStatement(_m(n['body'])),
          mapParenCondition(_m(n['test'])),
        ]);
      case 'SwitchStatement':
        return mapSwitch(n);
      case 'TryStatement':
        return mapTry(n);
      case 'ThrowStatement':
        return buildNode('throw_statement', start, extendStatementEnd(end), [
          mapExpression(_m(n['argument'])),
        ]);
      case 'ReturnStatement':
        return buildNode('return_statement', start, extendStatementEnd(end), [
          n['argument'] == null ? null : mapExpression(_m(n['argument'])),
        ]);
      case 'BreakStatement':
      case 'ContinueStatement':
        return mapBreakContinue(n, type);
      case 'LabeledStatement':
        return buildNode('labeled_statement', start, end, [
          buildNode('statement_identifier', _m(n['label'])['start'] as int,
              _m(n['label'])['end'] as int, const []),
          mapStatement(_m(n['body'])),
        ]);
      case 'DebuggerStatement':
        return buildNode(
            'debugger_statement', start, extendStatementEnd(end), const []);
      case 'EmptyStatement':
        return buildNode('empty_statement', start, end, const []);
      case 'ImportDeclaration':
        return mapImport(n);
      case 'ExportNamedDeclaration':
      case 'ExportDefaultDeclaration':
      case 'ExportAllDeclaration':
        return mapExport(n);
      default:
        return mapTypeNode(n);
    }
  }

  /// Synthesize tree-sitter's parenthesized_expression around a condition.
  AstNode mapParenCondition(Map<String, dynamic> test) {
    final (open, close) =
        parenSpanAround(test['start'] as int, test['end'] as int);
    return buildNode('parenthesized_expression', open, close, [
      mapExpression(test),
    ]);
  }

  /// Lexical declaration end: tree-sitter includes the trailing `;` in both
  /// statement and for-header positions.
  AstNode mapVariableDeclaration(Map<String, dynamic> n) {
    final kind = n['kind'] == 'var'
        ? 'variable_declaration'
        : 'lexical_declaration';
    final end = extendStatementEnd(n['end'] as int);
    return buildNode(kind, n['start'] as int, end, [
      for (final d in n['declarations'] as List) mapDeclarator(_m(d)),
    ]);
  }

  /// variable_declarator: pattern (+ optional type_annotation) + init.
  AstNode mapDeclarator(Map<String, dynamic> d) {
    final id = _m(d['id']);
    final AstNode pattern;
    final AstNode? ann;
    if (id['type'] == 'Identifier') {
      (pattern, ann) = splitAnnotation(id);
    } else {
      pattern = mapPattern(id);
      ann = id['typeAnnotation'] == null
          ? null
          : mapTypeNode(_m(id['typeAnnotation']));
    }
    return buildNode(
        'variable_declarator', d['start'] as int, d['end'] as int, [
      pattern,
      ann,
      d['init'] == null ? null : mapExpression(_m(d['init'])),
    ]);
  }

  /// A nameless function in statement position parses as an
  /// expression_statement wrapping a function_expression (tree-sitter rule).
  AstNode _namelessFunctionStatement(Map<String, dynamic> n) {
    final kind = n['generator'] == true
        ? 'generator_function'
        : 'function_expression';
    return buildNode('expression_statement', n['start'] as int,
        extendStatementEnd(n['end'] as int), [
      mapFunction(n, kind),
    ]);
  }

  /// if_statement: condition + consequence + optional else_clause.
  AstNode mapIf(Map<String, dynamic> n) {
    final alternate = n['alternate'];
    return buildNode('if_statement', n['start'] as int, n['end'] as int, [
      mapParenCondition(_m(n['test'])),
      mapStatement(_m(n['consequent'])),
      alternate == null ? null : _elseClause(_m(n['consequent']), _m(alternate)),
    ]);
  }

  AstNode _elseClause(
    Map<String, dynamic> consequent,
    Map<String, dynamic> alternate,
  ) {
    final elseKw = skipWs(consequent['end'] as int);
    return buildNode('else_clause', elseKw, alternate['end'] as int, [
      mapStatement(alternate),
    ]);
  }

  /// for_statement: init/test/update slots; missing init/test become
  /// empty_statement nodes spanning their `;`.
  AstNode mapFor(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = n['end'] as int;
    final kids = <AstNode?>[];
    final open = _forParenOpen(start);
    _forInitSlot(n, open, kids);
    _forTestSlot(n, kids);
    final update = n['update'];
    if (update != null) kids.add(mapExpression(_m(update)));
    kids.add(mapStatement(_m(n['body'])));
    return buildNode('for_statement', start, end, kids);
  }

  int _forParenOpen(int start) {
    var i = start;
    while (i < bytes.length && bytes[i] != 0x28) {
      i++;
    }
    return i;
  }

  void _forInitSlot(Map<String, dynamic> n, int open, List<AstNode?> kids) {
    final init = n['init'];
    if (init == null) {
      kids.add(_semiEmptyStatement(open + 1));
      return;
    }
    final j = _m(init);
    if (j['type'] == 'VariableDeclaration') {
      kids.add(mapVariableDeclaration(j));
      return;
    }
    kids.add(mapExpression(j));
  }

  void _forTestSlot(Map<String, dynamic> n, List<AstNode?> kids) {
    final test = n['test'];
    if (test == null) {
      final init = n['init'];
      final from = init == null ? null : _m(init)['end'] as int;
      kids.add(_semiEmptyStatement(from ?? 0));
      return;
    }
    kids.add(mapExpression(_m(test)));
  }

  AstNode _semiEmptyStatement(int from) {
    final semi = skipWs(from);
    return buildNode('empty_statement', semi, semi + 1, const []);
  }

  /// for_in / for_of share tree-sitter's for_in_statement with a flattened
  /// left pattern (no lexical_declaration wrapper).
  AstNode mapForIn(Map<String, dynamic> n) {
    final left = _m(n['left']);
    final AstNode leftNode;
    if (left['type'] == 'VariableDeclaration') {
      final decl = _m((left['declarations'] as List).first);
      leftNode = mapPattern(_m(decl['id']));
    } else {
      leftNode = mapExpression(left);
    }
    return buildNode('for_in_statement', n['start'] as int, n['end'] as int, [
      leftNode,
      mapExpression(_m(n['right'])),
      mapStatement(_m(n['body'])),
    ]);
  }

  /// switch_statement: parenthesized discriminant + switch_body holding
  /// switch_case / switch_default children.
  AstNode mapSwitch(Map<String, dynamic> n) {
    final disc = _m(n['discriminant']);
    final cases = n['cases'] as List;
    final openBrace = skipWs(skipWs(disc['end'] as int) + 1);
    return buildNode('switch_statement', n['start'] as int, n['end'] as int, [
      mapParenCondition(disc),
      buildNode('switch_body', openBrace, n['end'] as int, [
        for (final c in cases) mapSwitchCase(_m(c)),
      ]),
    ]);
  }

  /// switch_case (with test) / switch_default; span starts at the keyword.
  AstNode mapSwitchCase(Map<String, dynamic> c) {
    final start = c['start'] as int;
    final end = c['end'] as int;
    final test = c['test'];
    final stmts = [for (final s in c['consequent'] as List) mapStatement(_m(s))];
    if (test == null) {
      return buildNode('switch_default', start, end, stmts);
    }
    return buildNode('switch_case', start, end, [
      mapExpression(_m(test)),
      ...stmts,
    ]);
  }

  /// try_statement: block + optional catch_clause / finally_clause.
  AstNode mapTry(Map<String, dynamic> n) {
    final handler = n['handler'];
    final finalizer = n['finalizer'];
    return buildNode('try_statement', n['start'] as int, n['end'] as int, [
      mapStatement(_m(n['block'])),
      handler == null ? null : _catchClause(_m(handler)),
      finalizer == null ? null : _finallyClause(_m(finalizer)),
    ]);
  }

  AstNode _catchClause(Map<String, dynamic> h) {
    final param = h['param'];
    return buildNode('catch_clause', h['start'] as int, h['end'] as int, [
      param == null ? null : mapPattern(_m(param)),
      mapStatement(_m(h['body'])),
    ]);
  }

  AstNode _finallyClause(Map<String, dynamic> f) {
    final kw = skipWsBack(f['start'] as int) - 7; // 'finally'
    return buildNode('finally_clause', kw, f['end'] as int, [
      mapStatement(f),
    ]);
  }

  /// break_statement / continue_statement with optional label.
  AstNode mapBreakContinue(Map<String, dynamic> n, String type) {
    final kind = type == 'BreakStatement' ? 'break_statement' : 'continue_statement';
    final label = n['label'];
    return buildNode(kind, n['start'] as int,
        extendStatementEnd(n['end'] as int), [
      label == null
          ? null
          : buildNode('statement_identifier', _m(label)['start'] as int,
              _m(label)['end'] as int, const []),
    ]);
  }

  /// import_statement: optional import_clause + source string.
  AstNode mapImport(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = extendStatementEnd(n['end'] as int);
    final specs = n['specifiers'] as List;
    return buildNode('import_statement', start, end, [
      specs.isEmpty ? null : _importClause(specs),
      mapExpression(_m(n['source'])),
    ]);
  }

  /// import_clause: default identifier / namespace_import / named_imports,
  /// grouped by specifier kind (tree-sitter nests named imports in braces).
  AstNode _importClause(List specs) {
    final kids = <AstNode>[];
    final named = <Map<String, dynamic>>[];
    for (final s in specs) {
      final j = _m(s);
      if (j['type'] == 'ImportSpecifier') {
        named.add(j);
      } else {
        kids.add(_importSpecifier(j));
      }
    }
    if (named.isNotEmpty) kids.add(_namedImports(named));
    final start = kids.first.startByte;
    final end = kids.last.endByte;
    return buildNode('import_clause', start, end, kids);
  }

  AstNode _namedImports(List<Map<String, dynamic>> named) {
    final open = skipWsBack(named.first['start'] as int) - 1;
    final close = skipWs(named.last['end'] as int);
    return buildNode('named_imports', open, close + 1, [
      for (final s in named) _importSpecifier(s),
    ]);
  }

  AstNode _importSpecifier(Map<String, dynamic> s) {
    final start = s['start'] as int;
    final end = s['end'] as int;
    switch (s['type']) {
      case 'ImportDefaultSpecifier':
        return buildNode('identifier', start, end, const []);
      case 'ImportNamespaceSpecifier':
        return buildNode('namespace_import', start, end, [
          buildNode('identifier', _m(s['local'])['start'] as int,
              _m(s['local'])['end'] as int, const []),
        ]);
      default:
        return _importNamedSpecifier(s);
    }
  }

  /// import_specifier: [imported] plus [local] when aliased.
  AstNode _importNamedSpecifier(Map<String, dynamic> s) {
    final imported = _m(s['imported']);
    final local = _m(s['local']);
    final alias = imported['name'] != local['name'];
    return buildNode('import_specifier', s['start'] as int, s['end'] as int, [
      buildNode('identifier', imported['start'] as int,
          imported['end'] as int, const []),
      alias
          ? buildNode('identifier', local['start'] as int,
              local['end'] as int, const [])
          : null,
    ]);
  }

  /// export_statement wrapping a declaration, an export_clause, or a
  /// namespace/bare re-export.
  AstNode mapExport(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = extendStatementEnd(n['end'] as int);
    final type = n['type'] as String;
    if (type == 'ExportAllDeclaration') {
      return buildNode('export_statement', start, end, [
        n['exported'] == null ? null : _namespaceExport(n),
        mapExpression(_m(n['source'])),
      ]);
    }
    final declaration = n['declaration'];
    if (declaration != null) {
      return buildNode('export_statement', start, end, [
        _exportDeclaration(_m(declaration)),
      ]);
    }
    return buildNode('export_statement', start, end, [
      _exportClause(n['specifiers'] as List),
    ]);
  }

  AstNode _namespaceExport(Map<String, dynamic> n) {
    final exported = _m(n['exported']);
    final star = skipWs((n['start'] as int) + 6); // 'export'
    return buildNode('namespace_export', star, exported['end'] as int, [
      buildNode('identifier', exported['start'] as int,
          exported['end'] as int, const []),
    ]);
  }

  AstNode _exportDeclaration(Map<String, dynamic> d) {
    if (d['type'] == 'ClassDeclaration') return mapClass(d, 'class');
    if (d['type'] == 'FunctionDeclaration') {
      final kind = d['generator'] == true ? 'generator_function' : 'function';
      return mapFunction(d, kind);
    }
    if (!statementTypes.contains(d['type'])) return mapExpression(d);
    return mapStatement(d);
  }

  AstNode _exportClause(List specs) {
    final kids = <AstNode>[];
    for (final s in specs) {
      final j = _m(s);
      kids.add(_exportSpecifier(j));
    }
    final open = skipWsBack(_m(specs.first)['start'] as int) - 1;
    final close = skipWs(_m(specs.last)['end'] as int);
    return buildNode('export_clause', open, close + 1, kids);
  }

  AstNode _exportSpecifier(Map<String, dynamic> s) {
    final local = _m(s['local']);
    final exported = _m(s['exported']);
    final alias = local['name'] != exported['name'];
    return buildNode('export_specifier', s['start'] as int, s['end'] as int, [
      buildNode('identifier', local['start'] as int, local['end'] as int,
          const []),
      alias
          ? buildNode('identifier', exported['start'] as int,
              exported['end'] as int, const [])
          : null,
    ]);
  }

  /// class_declaration / class: name + heritage + body. The javascript
  /// grammar names the class with `identifier` and has no extends_clause
  /// wrapper; typescript uses type_identifier and wraps heritage clauses.
  AstNode mapClass(Map<String, dynamic> n, String kind) {
    final id = n['id'];
    final heritage = _classHeritage(n);
    final idNode = id == null
        ? null
        : buildNode(tsMode ? 'type_identifier' : 'identifier',
            _m(id)['start'] as int, _m(id)['end'] as int, const []);
    return buildNode(kind, n['start'] as int, n['end'] as int, [
      idNode,
      heritage,
      mapClassBody(n),
    ]);
  }

  AstNode? _classHeritage(Map<String, dynamic> n) {
    final superClass = n['superClass'];
    final implements = n['implements'] as List? ?? const [];
    if (superClass == null && implements.isEmpty) return null;
    if (!tsMode) {
      final sup = _m(superClass);
      final kw = skipWsBack(sup['start'] as int) - 7; // 'extends'
      return buildNode('class_heritage', kw, sup['end'] as int, [
        mapExpression(superClass),
      ]);
    }
    final kids = <AstNode>[];
    if (superClass != null) kids.add(_extendsClause(_m(superClass)));
    if (implements.isNotEmpty) kids.add(_implementsClause(implements));
    final start = kids.first.startByte;
    final end = kids.last.endByte;
    return buildNode('class_heritage', start, end, kids);
  }

  AstNode _extendsClause(Map<String, dynamic> superClass) {
    final kw = skipWsBack(superClass['start'] as int) - 7; // 'extends'
    return buildNode('extends_clause', kw, superClass['end'] as int, [
      mapExpression(superClass),
    ]);
  }

  AstNode _implementsClause(List implements) {
    final first = _m(implements.first);
    final kw = skipWsBack(first['start'] as int) - 10; // 'implements'
    return buildNode('implements_clause', kw, _m(implements.last)['end'] as int, [
      for (final i in implements) mapTypeNode(_m(i)),
    ]);
  }

  /// class_body: fields / methods / static blocks.
  AstNode mapClassBody(Map<String, dynamic> n) {
    final body = _m(n['body']);
    return buildNode('class_body', body['start'] as int, body['end'] as int, [
      for (final m in body['body'] as List) mapClassMember(_m(m)),
    ]);
  }

  AstNode mapClassMember(Map<String, dynamic> m) {
    switch (m['type']) {
      case 'PropertyDefinition':
        final kind = tsMode ? 'public_field_definition' : 'field_definition';
        return buildNode(kind, m['start'] as int,
            extendStatementEnd(m['end'] as int), [
          mapPropertyKey(_m(m['key']), m['computed'] == true),
          m['value'] == null ? null : mapExpression(_m(m['value'])),
        ]);
      case 'StaticBlock':
        return _staticBlock(m);
      default:
        return mapMethodLike(m, 'method_definition');
    }
  }

  /// class_static_block: statement_block child spanning the braces.
  AstNode _staticBlock(Map<String, dynamic> m) {
    final stmts = m['body'] as List;
    final open = _braceScan(m['start'] as int);
    final close = extendStatementEnd(m['end'] as int) - 1;
    return buildNode('class_static_block', m['start'] as int, close + 1, [
      buildNode('statement_block', open, close + 1, [
        for (final s in stmts) mapStatement(_m(s)),
      ]),
    ]);
  }

  int _braceScan(int from) {
    var i = from;
    while (i < bytes.length && bytes[i] != 0x7B) {
      i++;
    }
    return i;
  }
}
