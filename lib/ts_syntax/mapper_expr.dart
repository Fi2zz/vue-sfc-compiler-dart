// English comments per ~/REPO rule.
// Expression-family mappings: oxc ESTree JSON -> tree-sitter CST shapes.
// Part of oxc_mapper.dart.

part of 'oxc_mapper.dart';

extension OxcExprMapper on OxcMapper {
  /// Dispatch one ESTree expression node to its tree-sitter shape.
  AstNode mapExpression(Map<String, dynamic> n) {
    final type = n['type'] as String;
    final start = n['start'] as int;
    final end = n['end'] as int;
    switch (type) {
      case 'Identifier':
        final kind = n['name'] == 'undefined' ? 'undefined' : 'identifier';
        return buildNode(kind, start, end, const []);
      case 'PrivateIdentifier':
        return buildNode('private_property_identifier', start, end, const []);
      case 'ThisExpression':
        return buildNode('this', start, end, const []);
      case 'SuperExpression':
        return buildNode('super', start, end, const []);
      case 'Literal':
        return mapLiteral(n);
      case 'TemplateLiteral':
        return mapTemplateString(n);
      case 'TaggedTemplateExpression':
        return buildNode('call_expression', start, end, [
          mapExpression(_m(n['tag'])),
          mapTemplateString(_m(n['quasi'])),
        ]);
      case 'CallExpression':
        return mapCallLike(n, 'call_expression');
      case 'NewExpression':
        return mapCallLike(n, 'new_expression');
      case 'MemberExpression':
        return mapMember(n);
      case 'ChainExpression':
        return mapExpression(_m(n['expression']));
      case 'BinaryExpression':
      case 'LogicalExpression':
        return buildNode('binary_expression', start, end, [
          mapExpression(_m(n['left'])),
          mapExpression(_m(n['right'])),
        ]);
      case 'AssignmentExpression':
        final kind = n['operator'] == '='
            ? 'assignment_expression'
            : 'augmented_assignment_expression';
        return buildNode(kind, start, end, [
          mapExpression(_m(n['left'])),
          mapExpression(_m(n['right'])),
        ]);
      case 'UnaryExpression':
        return buildNode('unary_expression', start, end, [
          mapExpression(_m(n['argument'])),
        ]);
      case 'AwaitExpression':
        return buildNode('await_expression', start, end, [
          mapExpression(_m(n['argument'])),
        ]);
      case 'UpdateExpression':
        return buildNode('update_expression', start, end, [
          mapExpression(_m(n['argument'])),
        ]);
      case 'YieldExpression':
        return buildNode('yield_expression', start, end, [
          n['argument'] == null ? null : mapExpression(_m(n['argument'])),
        ]);
      case 'ConditionalExpression':
        return buildNode('ternary_expression', start, end, [
          mapExpression(_m(n['test'])),
          mapExpression(_m(n['consequent'])),
          mapExpression(_m(n['alternate'])),
        ]);
      case 'SequenceExpression':
        return buildNode('sequence_expression', start, end, [
          for (final e in n['expressions'] as List) mapExpression(_m(e)),
        ]);
      case 'ParenthesizedExpression':
        return buildNode('parenthesized_expression', start, end, [
          mapExpression(_m(n['expression'])),
        ]);
      case 'ArrowFunctionExpression':
        return mapArrow(n);
      case 'FunctionExpression':
        final kind = n['generator'] == true
            ? 'generator_function'
            : 'function_expression';
        return mapFunction(n, kind);
      case 'ObjectExpression':
        return buildNode('object', start, end, [
          for (final p in n['properties'] as List) mapObjectProperty(_m(p)),
        ]);
      case 'ArrayExpression':
        return buildNode('array', start, end, [
          for (final e in n['elements'] as List)
            e == null ? null : mapExpression(_m(e)),
        ]);
      case 'ObjectPattern':
        return buildNode('object_pattern', start, end, [
          for (final p in n['properties'] as List) mapPatternProperty(_m(p)),
        ]);
      case 'ArrayPattern':
        return buildNode('array_pattern', start, end, [
          for (final e in n['elements'] as List)
            e == null ? null : mapPattern(_m(e)),
        ]);
      case 'SpreadElement':
        return buildNode('spread_element', start, end, [
          mapExpression(_m(n['argument'])),
        ]);
      case 'ImportExpression':
        return _importExpression(n);
      case 'MetaProperty':
        return buildNode('meta_property', start, end, const []);
      case 'ClassExpression':
        return mapClass(n, 'class');
      default:
        return mapTypeNode(n);
    }
  }

  /// Map an assignment-target pattern (also used for declarator ids).
  AstNode mapPattern(Map<String, dynamic> n) {
    if (n['type'] == 'AssignmentPattern') {
      return buildNode('assignment_pattern', n['start'] as int, n['end'] as int, [
        mapPattern(_m(n['left'])),
        mapExpression(_m(n['right'])),
      ]);
    }
    if (n['type'] == 'RestElement') {
      return buildNode('rest_pattern', n['start'] as int, n['end'] as int, [
        mapPattern(_m(n['argument'])),
      ]);
    }
    return mapExpression(n);
  }

  /// Literal kinds: regex / bigint / bool / null / number / string.
  AstNode mapLiteral(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = n['end'] as int;
    final raw = n['raw'] as String? ?? '';
    if (raw.startsWith('/')) return mapRegex(n);
    if (n['bigint'] != null) return buildNode('number', start, end, const []);
    final value = n['value'];
    if (value is bool) {
      return buildNode(value ? 'true' : 'false', start, end, const []);
    }
    if (value == null) return buildNode('null', start, end, const []);
    if (value is num) return buildNode('number', start, end, const []);
    return buildNode('string', start, end, [
      // tree-sitter omits the string_fragment for empty strings.
      start + 1 >= end - 1
          ? null
          : buildNode('string_fragment', start + 1, end - 1, const []),
    ]);
  }

  /// regex: children regex_pattern + optional regex_flags.
  AstNode mapRegex(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = n['end'] as int;
    final regex = _m(n['regex']);
    final pattern = regex['pattern'] as String;
    final flags = regex['flags'] as String;
    return buildNode('regex', start, end, [
      buildNode('regex_pattern', start + 1, start + 1 + pattern.length, const []),
      flags.isEmpty
          ? null
          : buildNode('regex_flags', end - flags.length, end, const []),
    ]);
  }

  /// template_string: interleaved string_fragment / template_substitution.
  /// Empty fragments are omitted (tree-sitter drops zero-length fragments).
  AstNode mapTemplateString(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = n['end'] as int;
    final quasis = n['quasis'] as List;
    final exprs = n['expressions'] as List;
    final kids = <AstNode?>[];
    for (var i = 0; i < quasis.length; i++) {
      kids.add(_templateFragment(_m(quasis[i])));
      if (i < exprs.length) kids.add(_templateSubstitution(_m(exprs[i])));
    }
    return buildNode('template_string', start, end, kids);
  }

  AstNode? _templateFragment(Map<String, dynamic> quasi) {
    // oxc TemplateElement spans include the delimiters: leading backtick or
    // `}` (1 byte), trailing `${` (2 bytes) or closing backtick (tail, 1
    // byte). The tree-sitter string_fragment covers only the content.
    final start = (quasi['start'] as int) + 1;
    final end = (quasi['end'] as int) - (quasi['tail'] == true ? 1 : 2);
    if (start >= end) return null;
    return buildNode('string_fragment', start, end, const []);
  }

  AstNode _templateSubstitution(Map<String, dynamic> expr) {
    final start = expr['start'] as int;
    final end = expr['end'] as int;
    return buildNode('template_substitution', start - 2, end + 1, [
      mapExpression(expr),
    ]);
  }

  /// call_expression / new_expression: callee + type_arguments + arguments
  /// (span covers the parens). `new Foo` without parens has no arguments.
  AstNode mapCallLike(Map<String, dynamic> n, String kind) {
    final callee = _m(n['callee']);
    final typeArgs = n['typeArguments'];
    final searchFrom = typeArgs == null
        ? callee['end'] as int
        : _m(typeArgs)['end'] as int;
    final open = _findCallParen(searchFrom);
    final args = n['arguments'] as List;
    final argumentsNode = open == null
        ? null
        : buildNode('arguments', open, n['end'] as int, [
            for (final a in args) mapExpression(_m(a)),
          ]);
    return buildNode(kind, n['start'] as int, n['end'] as int, [
      mapExpression(callee),
      typeArgs == null ? null : mapTypeNode(_m(typeArgs)),
      argumentsNode,
    ]);
  }

  /// Locate the call's open paren after the callee, skipping whitespace and
  /// an optional `?.` chain marker (which tree-sitter omits for calls).
  int? _findCallParen(int from) {
    var i = skipWs(from);
    if (i + 1 < bytes.length && bytes[i] == 0x3F && bytes[i + 1] == 0x2E) {
      i = skipWs(i + 2);
    }
    if (i < bytes.length && bytes[i] == 0x28) return i;
    return null;
  }

  /// import(...): call_expression with an `import` leaf as the callee.
  AstNode _importExpression(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = n['end'] as int;
    final kids = <AstNode?>[
      mapExpression(_m(n['source'])),
      n['options'] == null ? null : mapExpression(_m(n['options'])),
    ];
    return buildNode('call_expression', start, end, [
      buildNode('import', start, start + 6, const []),
      buildNode('arguments', start + 6, end, kids),
    ]);
  }

  /// member_expression (dot) / subscript_expression (computed), inserting an
  /// optional_chain node for `?.` like tree-sitter does.
  AstNode mapMember(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = n['end'] as int;
    final object = mapExpression(_m(n['object']));
    final prop = _m(n['property']);
    final chain = n['optional'] == true
        ? buildNode('optional_chain', (prop['start'] as int) - 2,
            prop['start'] as int, const [])
        : null;
    if (n['computed'] == true) {
      return buildNode('subscript_expression', start, end, [
        object,
        chain,
        mapExpression(prop),
      ]);
    }
    return buildNode('member_expression', start, end, [
      object,
      chain,
      buildNode('property_identifier', prop['start'] as int,
          prop['end'] as int, const []),
    ]);
  }

  /// arrow_function: type params + formal_parameters + return type + body;
  /// a single unparenthesized identifier param is a bare identifier child.
  AstNode mapArrow(Map<String, dynamic> n) {
    final params = n['params'] as List;
    final bare = _bareParam(params);
    final paramsNode = bare != null
        ? mapExpression(bare)
        : buildFormalParameters(params, n['start'] as int);
    final body = _m(n['body']);
    final bodyNode = body['type'] == 'BlockStatement'
        ? mapStatement(body)
        : mapExpression(body);
    return buildNode('arrow_function', n['start'] as int, n['end'] as int, [
      n['typeParameters'] == null ? null : mapTypeNode(_m(n['typeParameters'])),
      paramsNode,
      n['returnType'] == null ? null : mapTypeNode(_m(n['returnType'])),
      bodyNode,
    ]);
  }

  Map<String, dynamic>? _bareParam(List params) {
    if (params.length != 1) return null;
    final p = _m(params.first);
    if (p['type'] != 'Identifier') return null;
    // Bare iff the token after the param is `=>` (a parenthesized param is
    // followed by `)` first).
    final after = skipWs(p['end'] as int);
    final bare = after + 1 < bytes.length &&
        bytes[after] == 0x3D &&
        bytes[after + 1] == 0x3E;
    return bare ? p : null;
  }

  /// function_expression / function_declaration / generators: name +
  /// type params + formal_parameters + return type + statement_block.
  AstNode mapFunction(Map<String, dynamic> n, String kind) {
    final id = n['id'];
    return buildNode(kind, n['start'] as int, n['end'] as int, [
      id == null ? null : mapExpression(_m(id)),
      n['typeParameters'] == null ? null : mapTypeNode(_m(n['typeParameters'])),
      buildFormalParameters(n['params'] as List, n['start'] as int),
      n['returnType'] == null ? null : mapTypeNode(_m(n['returnType'])),
      mapStatement(_m(n['body'])),
    ]);
  }

  /// formal_parameters span covers the parens; children are required_parameter
  /// wrappers (rest wrapped again in rest_pattern).
  AstNode buildFormalParameters(List params, int funcStart) {
    final kids = [for (final p in params) mapParameter(_m(p))];
    final (open, close) = _paramsParenSpan(params, funcStart);
    return buildNode('formal_parameters', open, close, kids);
  }

  (int, int) _paramsParenSpan(List params, int funcStart) {
    if (params.isEmpty) {
      final open = _scanForward(funcStart, 0x28);
      final close = _scanForward(open + 1, 0x29);
      return (open, close + 1);
    }
    final open = skipWsBack(_m(params.first)['start'] as int) - 1;
    final close = skipWs(_m(params.last)['end'] as int);
    return (open, close + 1);
  }

  int _scanForward(int from, int byte) {
    var i = from;
    while (i < bytes.length && bytes[i] != byte) {
      i++;
    }
    return i;
  }

  /// One formal parameter: the typescript grammar wraps every parameter in
  /// required_parameter / optional_parameter (rest wrapped again in
  /// rest_pattern); the javascript grammar uses bare patterns.
  AstNode mapParameter(Map<String, dynamic> p) {
    final start = p['start'] as int;
    final end = p['end'] as int;
    if (!tsMode) return mapPattern(p);
    if (p['type'] == 'RestElement') {
      return buildNode('required_parameter', start, end, [
        buildNode('rest_pattern', start, end, [
          mapPattern(_m(p['argument'])),
        ]),
      ]);
    }
    if (p['type'] == 'AssignmentPattern') {
      return _defaultParameter(p);
    }
    return _annotatedParameter(p);
  }

  /// Parameter with a default value; a type annotation may sit between the
  /// pattern and the default: required_parameter[id, annotation, default].
  AstNode _defaultParameter(Map<String, dynamic> p) {
    final start = p['start'] as int;
    final end = p['end'] as int;
    final left = _m(p['left']);
    final AstNode pattern;
    final AstNode? ann;
    if (left['type'] == 'Identifier' && left['typeAnnotation'] != null) {
      (pattern, ann) = splitAnnotation(left);
    } else {
      pattern = mapPattern(left);
      ann = null;
    }
    return buildNode('required_parameter', start, end, [
      pattern,
      ann,
      mapExpression(_m(p['right'])),
    ]);
  }

  /// required_parameter / optional_parameter: pattern + type_annotation.
  AstNode _annotatedParameter(Map<String, dynamic> p) {
    final start = p['start'] as int;
    final end = p['end'] as int;
    final kind = p['optional'] == true
        ? 'optional_parameter'
        : 'required_parameter';
    if (p['type'] == 'Identifier') {
      final (pattern, ann) = splitAnnotation(p);
      return buildNode(kind, start, end, [pattern, ann]);
    }
    if (p['typeAnnotation'] == null) {
      return buildNode(kind, start, end, [mapPattern(p)]);
    }
    // oxc pattern spans include the annotation; tree-sitter crops them.
    final ann = mapTypeNode(_m(p['typeAnnotation']));
    final pattern = mapPattern(p);
    final cropped = buildNode(pattern.type, pattern.startByte,
        skipWsBack(ann.startByte), pattern.children);
    return buildNode(kind, start, end, [cropped, ann]);
  }

  /// Object-literal property: pair / shorthand / method / spread.
  AstNode mapObjectProperty(Map<String, dynamic> p) {
    if (p['type'] == 'SpreadElement') return mapExpression(p);
    if (p['method'] == true || p['kind'] != 'init') {
      return mapMethodLike(p, 'method_definition');
    }
    if (p['shorthand'] == true) {
      return buildNode('shorthand_property_identifier', p['start'] as int,
          p['end'] as int, const []);
    }
    return buildNode('pair', p['start'] as int, p['end'] as int, [
      mapPropertyKey(_m(p['key']), p['computed'] == true),
      mapExpression(_m(p['value'])),
    ]);
  }

  /// Pattern-side object property: shorthand / pair_pattern / default.
  AstNode mapPatternProperty(Map<String, dynamic> p) {
    if (p['type'] == 'RestElement') return mapPattern(p);
    final start = p['start'] as int;
    final end = p['end'] as int;
    final value = _m(p['value']);
    if (value['type'] == 'AssignmentPattern') {
      return buildNode('object_assignment_pattern', start, end, [
        _patternDefaultLeft(_m(value['left'])),
        mapExpression(_m(value['right'])),
      ]);
    }
    if (p['shorthand'] == true) {
      return buildNode('shorthand_property_identifier_pattern', start, end,
          const []);
    }
    return buildNode('pair_pattern', start, end, [
      mapPropertyKey(_m(p['key']), p['computed'] == true),
      mapPattern(value),
    ]);
  }

  /// Left side of a pattern default: a bare identifier becomes
  /// shorthand_property_identifier_pattern in tree-sitter.
  AstNode _patternDefaultLeft(Map<String, dynamic> left) {
    if (left['type'] == 'Identifier') {
      return buildNode('shorthand_property_identifier_pattern',
          left['start'] as int, left['end'] as int, const []);
    }
    return mapPattern(left);
  }

  /// Object key: property_identifier / string / number /
  /// computed_property_name (span covers the brackets).
  AstNode mapPropertyKey(Map<String, dynamic> key, bool computed) {
    final start = key['start'] as int;
    final end = key['end'] as int;
    if (computed) {
      return buildNode('computed_property_name', start - 1, end + 1, [
        mapExpression(key),
      ]);
    }
    if (key['type'] == 'Identifier') {
      return buildNode('property_identifier', start, end, const []);
    }
    return mapExpression(key);
  }

  /// method_definition shared by object methods and class members.
  AstNode mapMethodLike(Map<String, dynamic> p, String kind) {
    final value = _m(p['value']);
    final params = value['params'] as List? ?? const [];
    final body = value['body'];
    return buildNode(kind, p['start'] as int, p['end'] as int, [
      mapPropertyKey(_m(p['key']), p['computed'] == true),
      buildFormalParameters(params, p['start'] as int),
      body == null ? null : mapStatement(_m(body)),
    ]);
  }
}
