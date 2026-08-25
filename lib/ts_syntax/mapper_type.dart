// English comments per ~/REPO rule.
// TS-family mappings: oxc ESTree type nodes -> tree-sitter-typescript CST
// shapes. Part of oxc_mapper.dart.

part of 'oxc_mapper.dart';

/// oxc keyword types that map to tree-sitter's predefined_type.
const _predefinedTypes = {
  'TSAnyKeyword',
  'TSBigIntKeyword',
  'TSBooleanKeyword',
  'TSNeverKeyword',
  'TSNumberKeyword',
  'TSObjectKeyword',
  'TSStringKeyword',
  'TSSymbolKeyword',
  'TSUndefinedKeyword',
  'TSUnknownKeyword',
  'TSVoidKeyword',
  'TSIntrinsicKeyword',
};

extension OxcTypeMapper on OxcMapper {
  /// Dispatch TS-only nodes (types, annotations, declarations).
  AstNode mapTypeNode(Map<String, dynamic> n) {
    final type = n['type'] as String;
    final start = n['start'] as int;
    final end = n['end'] as int;
    if (_predefinedTypes.contains(type)) {
      return buildNode('predefined_type', start, end, const []);
    }
    switch (type) {
      case 'TSTypeAnnotation':
        return buildNode('type_annotation', start, end, [
          mapTypeNode(_m(n['typeAnnotation'])),
        ]);
      case 'TSNullKeyword':
        return buildNode('literal_type', start, end, [
          buildNode('null', start, end, const []),
        ]);
      case 'TSTypeLiteral':
        return buildNode('object_type', start, end, [
          for (final m in n['members'] as List) mapInterfaceMember(_m(m)),
        ]);
      case 'TSTypeReference':
        return mapTypeReference(n);
      case 'TSUnionType':
      case 'TSIntersectionType':
        final kind = type == 'TSUnionType' ? 'union_type' : 'intersection_type';
        return _foldedType(kind, n['types'] as List);
      case 'TSLiteralType':
        return buildNode('literal_type', start, end, [
          mapExpression(_m(n['literal'])),
        ]);
      case 'TSArrayType':
        return buildNode('array_type', start, end, [
          mapTypeNode(_m(n['elementType'])),
        ]);
      case 'TSTupleType':
        return buildNode('tuple_type', start, end, [
          for (final t in n['elementTypes'] as List) mapTypeNode(_m(t)),
        ]);
      case 'TSOptionalType':
        return buildNode('optional_type', start, end, [
          mapTypeNode(_m(n['typeAnnotation'])),
        ]);
      case 'TSRestType':
        return buildNode('rest_type', start, end, [
          mapTypeNode(_m(n['typeAnnotation'])),
        ]);
      case 'TSFunctionType':
        return buildNode('function_type', start, end, [
          buildFormalParameters(n['params'] as List, start),
          mapTypeNode(_m(_m(n['returnType'])['typeAnnotation'])),
        ]);
      case 'TSTypeQuery':
        return buildNode('type_query', start, end, [
          mapExpression(_m(n['exprName'])),
        ]);
      case 'TSTypeOperator':
        return mapTypeOperator(n);
      case 'TSIndexedAccessType':
        return buildNode('lookup_type', start, end, [
          mapTypeNode(_m(n['objectType'])),
          mapTypeNode(_m(n['indexType'])),
        ]);
      case 'TSConditionalType':
        return buildNode('conditional_type', start, end, [
          mapTypeNode(_m(n['checkType'])),
          mapTypeNode(_m(n['extendsType'])),
          mapTypeNode(_m(n['trueType'])),
          mapTypeNode(_m(n['falseType'])),
        ]);
      case 'TSInferType':
        final name = _m(_m(n['typeParameter'])['name']);
        return buildNode('infer_type', start, end, [
          buildNode('type_identifier', name['start'] as int,
              name['end'] as int, const []),
        ]);
      case 'TSParenthesizedType':
        return buildNode('parenthesized_type', start, end, [
          mapTypeNode(_m(n['typeAnnotation'])),
        ]);
      case 'TSTemplateLiteralType':
        return mapTemplateLiteralType(n);
      case 'TSTypeParameterInstantiation':
        return buildNode('type_arguments', start, end, [
          for (final t in n['params'] as List) mapTypeNode(_m(t)),
        ]);
      case 'TSTypeParameterDeclaration':
        return buildNode('type_parameters', start, end, [
          for (final t in n['params'] as List) mapTypeNode(_m(t)),
        ]);
      case 'TSTypeParameter':
        return mapTypeParameter(n);
      case 'TSTypeAssertion':
        final inner = _m(n['typeAnnotation']);
        return buildNode('type_assertion', start, end, [
          buildNode('type_arguments', (inner['start'] as int) - 1,
              (inner['end'] as int) + 1, [mapTypeNode(inner)]),
          mapExpression(_m(n['expression'])),
        ]);
      case 'TSAsExpression':
        return mapAsExpression(n);
      case 'TSSatisfiesExpression':
        return buildNode('satisfies_expression', start, end, [
          mapExpression(_m(n['expression'])),
          mapTypeNode(_m(n['typeAnnotation'])),
        ]);
      case 'TSNonNullExpression':
        return buildNode('non_null_expression', start, end, [
          mapExpression(_m(n['expression'])),
        ]);
      case 'TSInterfaceDeclaration':
        return mapInterface(n);
      case 'TSTypeAliasDeclaration':
        return buildNode('type_alias_declaration', start, end, [
          buildNode('type_identifier', _m(n['id'])['start'] as int,
              _m(n['id'])['end'] as int, const []),
          n['typeParameters'] == null ? null : mapTypeNode(_m(n['typeParameters'])),
          mapTypeNode(_m(n['typeAnnotation'])),
        ]);
      case 'TSEnumDeclaration':
        return mapEnum(n);
      case 'TSExpressionWithTypeArguments':
        return mapTypeReference(n);
      default:
        throw UnimplementedError('oxc mapper: unmapped node $type');
    }
  }

  /// union_type / intersection_type nest left-deep in tree-sitter:
  /// A | B | C -> union_type[union_type[A,B], C].
  AstNode _foldedType(String kind, List types) {
    var acc = mapTypeNode(_m(types.first));
    for (var i = 1; i < types.length; i++) {
      final next = mapTypeNode(_m(types[i]));
      acc = buildNode(kind, acc.startByte, next.endByte, [acc, next]);
    }
    return acc;
  }

  /// type_identifier, or generic_type when type arguments are present.
  AstNode mapTypeReference(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = n['end'] as int;
    final name = _m(n['typeName'] ?? n['expression']);
    final typeArgs = n['typeArguments'];
    final nameNode = buildNode('type_identifier', name['start'] as int,
        name['end'] as int, const []);
    if (typeArgs == null) return nameNode;
    return buildNode('generic_type', start, end, [
      nameNode,
      mapTypeNode(_m(typeArgs)),
    ]);
  }

  /// keyof -> index_type_query; readonly -> readonly_type.
  AstNode mapTypeOperator(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = n['end'] as int;
    final kind = n['operator'] == 'keyof' ? 'index_type_query' : 'readonly_type';
    return buildNode(kind, start, end, [
      mapTypeNode(_m(n['typeAnnotation'])),
    ]);
  }

  /// type_parameter: name + optional constraint (span covers 'extends')
  /// and default_type (span covers '=').
  AstNode mapTypeParameter(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = n['end'] as int;
    final name = _m(n['name']);
    return buildNode('type_parameter', start, end, [
      buildNode('type_identifier', name['start'] as int, name['end'] as int,
          const []),
      _constraint(n['constraint']),
      _defaultType(n['default']),
    ]);
  }

  AstNode? _constraint(Map<String, dynamic>? c) {
    if (c == null) return null;
    final kw = skipWsBack(c['start'] as int) - 7; // 'extends'
    return buildNode('constraint', kw, c['end'] as int, [mapTypeNode(c)]);
  }

  AstNode? _defaultType(Map<String, dynamic>? d) {
    if (d == null) return null;
    final eq = skipWsBack(d['start'] as int) - 1; // '='
    return buildNode('default_type', eq, d['end'] as int, [mapTypeNode(d)]);
  }

  /// as_expression: the `as const` form drops the const reference.
  AstNode mapAsExpression(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = n['end'] as int;
    final typeNode = _m(n['typeAnnotation']);
    final constAssertion = typeNode['type'] == 'TSTypeReference' &&
        _m(typeNode['typeName'])['name'] == 'const';
    return buildNode('as_expression', start, end, [
      mapExpression(_m(n['expression'])),
      constAssertion ? null : mapTypeNode(typeNode),
    ]);
  }

  /// template_literal_type: string_fragments and template_type holes.
  AstNode mapTemplateLiteralType(Map<String, dynamic> n) {
    final start = n['start'] as int;
    final end = n['end'] as int;
    final quasis = n['quasis'] as List;
    final types = n['types'] as List;
    final kids = <AstNode?>[];
    for (var i = 0; i < quasis.length; i++) {
      kids.add(_templateFragment(_m(quasis[i])));
      if (i < types.length) kids.add(_templateTypeHole(_m(types[i])));
    }
    return buildNode('template_literal_type', start, end, kids);
  }

  AstNode _templateTypeHole(Map<String, dynamic> t) {
    return buildNode('template_type', (t['start'] as int) - 2,
        (t['end'] as int) + 1, [mapTypeNode(t)]);
  }

  /// interface_declaration: name + interface_body of signatures.
  AstNode mapInterface(Map<String, dynamic> n) {
    final body = _m(n['body']);
    return buildNode('interface_declaration', n['start'] as int,
        extendStatementEnd(n['end'] as int), [
      buildNode('type_identifier', _m(n['id'])['start'] as int,
          _m(n['id'])['end'] as int, const []),
      n['typeParameters'] == null ? null : mapTypeNode(_m(n['typeParameters'])),
      buildNode('interface_body', body['start'] as int, body['end'] as int, [
        for (final m in body['body'] as List) mapInterfaceMember(_m(m)),
      ]),
    ]);
  }

  /// property/method/construct/call/index signatures.
  AstNode mapInterfaceMember(Map<String, dynamic> m) {
    final start = m['start'] as int;
    switch (m['type']) {
      case 'TSPropertySignature':
        // tree-sitter's property_signature ends at the annotation, before
        // any `;` separator that oxc includes in the span.
        return buildNode('property_signature', start, _signatureEnd(m), [
          mapPropertyKey(_m(m['key']), m['computed'] == true),
          m['typeAnnotation'] == null ? null : mapTypeNode(_m(m['typeAnnotation'])),
        ]);
      case 'TSMethodSignature':
        return buildNode('method_signature', start, _signatureEnd(m), [
          mapPropertyKey(_m(m['key']), m['computed'] == true),
          buildFormalParameters(m['params'] as List, start),
          m['returnType'] == null ? null : mapTypeNode(_m(m['returnType'])),
        ]);
      case 'TSConstructSignatureDeclaration':
        return buildNode('construct_signature', start, _signatureEnd(m), [
          buildFormalParameters(m['params'] as List, start),
          m['returnType'] == null ? null : mapTypeNode(_m(m['returnType'])),
        ]);
      case 'TSCallSignatureDeclaration':
        return buildNode('call_signature', start, _signatureEnd(m), [
          buildFormalParameters(m['params'] as List, start),
          m['returnType'] == null ? null : mapTypeNode(_m(m['returnType'])),
        ]);
      case 'TSIndexSignature':
        return mapIndexSignature(m);
      default:
        throw UnimplementedError('oxc mapper: unmapped node ${m['type']}');
    }
  }

  /// Signature span ends at the annotation (or key), excluding separators.
  int _signatureEnd(Map<String, dynamic> m) {
    final ann = m['typeAnnotation'] ?? m['returnType'];
    if (ann != null) return _m(ann)['end'] as int;
    return _m(m['key'])['end'] as int;
  }

  /// index_signature: parameter name + its type + the value type_annotation.
  AstNode mapIndexSignature(Map<String, dynamic> m) {
    final param = _m((m['parameters'] as List).first);
    final paramAnn = _m(param['typeAnnotation']);
    return buildNode('index_signature', m['start'] as int, m['end'] as int, [
      buildNode('identifier', param['start'] as int,
          paramAnn['start'] as int, const []),
      mapTypeNode(_m(paramAnn['typeAnnotation'])),
      mapTypeNode(_m(m['typeAnnotation'])),
    ]);
  }

  /// enum_declaration: bare members are property_identifier; initialized
  /// members are enum_assignment.
  AstNode mapEnum(Map<String, dynamic> n) {
    final body = _m(n['body']);
    return buildNode('enum_declaration', n['start'] as int,
        extendStatementEnd(n['end'] as int), [
      buildNode('identifier', _m(n['id'])['start'] as int,
          _m(n['id'])['end'] as int, const []),
      buildNode('enum_body', body['start'] as int, body['end'] as int, [
        for (final m in body['members'] as List) _enumMember(_m(m)),
      ]),
    ]);
  }

  AstNode _enumMember(Map<String, dynamic> m) {
    final id = _m(m['id']);
    final key = buildNode('property_identifier', id['start'] as int,
        id['end'] as int, const []);
    final init = m['initializer'];
    if (init == null) return key;
    return buildNode('enum_assignment', m['start'] as int, m['end'] as int, [
      key,
      mapExpression(_m(init)),
    ]);
  }

  /// Identifier annotated with a TS type: returns the cropped identifier
  /// node (without `?`/annotation) plus the annotation node when present.
  (AstNode, AstNode?) splitAnnotation(Map<String, dynamic> id) {
    final start = id['start'] as int;
    final ann = id['typeAnnotation'];
    if (ann == null) {
      return (mapExpression(id), null);
    }
    var nameEnd = _m(ann)['start'] as int;
    if (bytes[nameEnd - 1] == 0x3F) nameEnd--; // '?'
    return (
      buildNode('identifier', start, nameEnd, const []),
      mapTypeNode(_m(ann)),
    );
  }
}
