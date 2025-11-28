part of 'ast.dart';

/// Program root. Holds executable statements (`body`) and program-level
/// comments (`comments`) in parallel.
Program programFromJson(Map<String, dynamic> m) {
  normalizeProgramJson(m);
  return Program(
    body: readList<Statement>(m['body'], TsAstFactory.fromJsonStatement),
    directives: readList<Directive>(m['directives'], directiveFromJson),
    sourceType: m['sourceType'] as String,
    interpreter: m['interpreter'] == null
        ? null
        : interpreterDirectiveFromJson(
            m['interpreter'] as Map<String, dynamic>,
          ),
    comments: readComments(m['comments']) ?? [],
    loc: m['loc'] == null
        ? null
        : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Expression statement.
ExpressionStatement expressionStatementFromJson(Map<String, dynamic> m) =>
    ExpressionStatement(
      expression: TsAstFactory.fromJsonExpression(
        m['expression'] as Map<String, dynamic>,
      ),
      declaration: m['declaration'] == null
          ? null
          : TsAstFactory.fromJson(m['declaration'] as Map<String, dynamic>),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),
      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// Identifier.
Identifier identifierFromJson(Map<String, dynamic> m) => Identifier(
  name: m['name'] as String,
  decorators: readList<Decorator>(m['decorators'], decoratorFromJson),
  optional: m['optional'] as bool?,
  typeAnnotation: m['typeAnnotation'] == null
      ? null
      : tsTypeAnnotationFromJson(m['typeAnnotation'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),
  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// String literal.
StringLiteral stringLiteralFromJson(Map<String, dynamic> m) => StringLiteral(
  value: m['value'] as String,

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),
  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// Numeric literal.
NumericLiteral numericLiteralFromJson(Map<String, dynamic> m) => NumericLiteral(
  value: (m['value'] as num),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),
  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// Null literal.
NullLiteral nullLiteralFromJson(Map<String, dynamic> m) => NullLiteral(
  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// Boolean literal.
BooleanLiteral booleanLiteralFromJson(Map<String, dynamic> m) => BooleanLiteral(
  value: m['value'] as bool,

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// MemberExpression.
MemberExpression memberExpressionFromJson(Map<String, dynamic> m) =>
    MemberExpression(
      object: TsAstFactory.fromJsonExpressionOrSuper(
        m['object'] as Map<String, dynamic>,
      ),
      property: TsAstFactory.fromJsonExpressionOrIdentifierOrPrivateName(
        m['property'] as Map<String, dynamic>,
      ),
      computed: m['computed'] as bool,
      optional: m['optional'] as bool?,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// NewExpression.
NewExpression newExpressionFromJson(Map<String, dynamic> m) => NewExpression(
  callee: TsAstFactory.fromJsonExpressionOrSuperOrV8Intrinsic(
    m['callee'] as Map<String, dynamic>,
  ),
  arguments: readMixedList(m['arguments']),
  optional: m['optional'] as bool?,
  typeParameters: m['typeParameters'] == null
      ? null
      : tsTypeParameterInstantiationFromJson(
          m['typeParameters'] as Map<String, dynamic>,
        ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// ObjectExpression.
ObjectExpression objectExpressionFromJson(Map<String, dynamic> m) =>
    ObjectExpression(
      properties: readObjProps(m['properties']),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// ArrayExpression.
ArrayExpression arrayExpressionFromJson(Map<String, dynamic> m) =>
    ArrayExpression(
      elements: readOptionalExpressionList(m['elements']),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// UpdateExpression.
UpdateExpression updateExpressionFromJson(Map<String, dynamic> m) =>
    UpdateExpression(
      operator: m['operator'] as String,
      argument: TsAstFactory.fromJsonExpression(
        m['argument'] as Map<String, dynamic>,
      ),
      prefix: m['prefix'] as bool,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// UnaryExpression.
UnaryExpression unaryExpressionFromJson(Map<String, dynamic> m) =>
    UnaryExpression(
      operator: m['operator'] as String,
      argument: TsAstFactory.fromJsonExpression(
        m['argument'] as Map<String, dynamic>,
      ),
      prefix: m['prefix'] as bool,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// BinaryExpression.
BinaryExpression binaryExpressionFromJson(Map<String, dynamic> m) =>
    BinaryExpression(
      operator: m['operator'] as String,
      left: TsAstFactory.fromJsonExpression(m['left'] as Map<String, dynamic>),
      right: TsAstFactory.fromJsonExpression(
        m['right'] as Map<String, dynamic>,
      ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// LogicalExpression.
LogicalExpression logicalExpressionFromJson(Map<String, dynamic> m) =>
    LogicalExpression(
      operator: m['operator'] as String,
      left: TsAstFactory.fromJsonExpression(m['left'] as Map<String, dynamic>),
      right: TsAstFactory.fromJsonExpression(
        m['right'] as Map<String, dynamic>,
      ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// AssignmentExpression.
AssignmentExpression assignmentExpressionFromJson(Map<String, dynamic> m) =>
    AssignmentExpression(
      operator: m['operator'] as String,
      left: TsAstFactory.fromJsonExpression(m['left'] as Map<String, dynamic>),
      right: TsAstFactory.fromJsonExpression(
        m['right'] as Map<String, dynamic>,
      ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// ConditionalExpression.
ConditionalExpression conditionalExpressionFromJson(Map<String, dynamic> m) =>
    ConditionalExpression(
      test: TsAstFactory.fromJsonExpression(m['test'] as Map<String, dynamic>),
      consequent: TsAstFactory.fromJsonExpression(
        m['consequent'] as Map<String, dynamic>,
      ),
      alternate: TsAstFactory.fromJsonExpression(
        m['alternate'] as Map<String, dynamic>,
      ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// ThisExpression.
ThisExpression thisExpressionFromJson(Map<String, dynamic> m) => ThisExpression(
  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// AwaitExpression.
AwaitExpression awaitExpressionFromJson(Map<String, dynamic> m) =>
    AwaitExpression(
      argument: TsAstFactory.fromJsonExpression(
        m['argument'] as Map<String, dynamic>,
      ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// MetaProperty.
MetaProperty metaPropertyFromJson(Map<String, dynamic> m) => MetaProperty(
  meta: identifierFromJson(m['meta'] as Map<String, dynamic>),
  property: identifierFromJson(m['property'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// FunctionExpression.
FunctionExpression functionExpressionFromJson(Map<String, dynamic> m) =>
    FunctionExpression(
      id: m['id'] == null
          ? null
          : identifierFromJson(m['id'] as Map<String, dynamic>),
      params: readFunctionParameters(m['params']),
      body: blockStatementFromJson(m['body'] as Map<String, dynamic>),
      generator: m['generator'] as bool,
      async: m['async'] as bool,
      returnType: m['returnType'] == null
          ? null
          : tsTypeAnnotationFromJson(m['returnType'] as Map<String, dynamic>),
      typeParameters: m['typeParameters'] == null
          ? null
          : tsTypeParameterDeclarationFromJson(
              m['typeParameters'] as Map<String, dynamic>,
            ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// ObjectMethod.
ObjectMethod objectMethodFromJson(Map<String, dynamic> m) => ObjectMethod(
  kind: m['kind'] as String,
  key: TsAstFactory.fromJsonExpressionOrIdentifierOrLiteralOrBigInt(
    m['key'] as Map<String, dynamic>,
  ),
  params: readFunctionParameters(m['params']),
  body: blockStatementFromJson(m['body'] as Map<String, dynamic>),
  computed: m['computed'] as bool,
  generator: m['generator'] as bool,
  async: m['async'] as bool,
  decorators: readList<Decorator>(m['decorators'], decoratorFromJson),
  returnType: m['returnType'] == null
      ? null
      : tsTypeAnnotationFromJson(m['returnType'] as Map<String, dynamic>),
  typeParameters: m['typeParameters'] == null
      ? null
      : tsTypeParameterDeclarationFromJson(
          m['typeParameters'] as Map<String, dynamic>,
        ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// ArrowFunctionExpression.
ArrowFunctionExpression arrowFunctionExpressionFromJson(
  Map<String, dynamic> m,
) => ArrowFunctionExpression(
  params: readFunctionParameters(m['params']),
  body:
      ((m['body'] as Map<String, dynamic>)['type'] as String) ==
          'BlockStatement'
      ? blockStatementFromJson(m['body'] as Map<String, dynamic>)
      : TsAstFactory.fromJsonExpression(m['body'] as Map<String, dynamic>),
  async: m['async'] as bool,
  expression: m['expression'] as bool,
  generator: m['generator'] as bool?,
  returnType: m['returnType'] == null
      ? null
      : tsTypeAnnotationFromJson(m['returnType'] as Map<String, dynamic>),
  typeParameters: m['typeParameters'] == null
      ? null
      : tsTypeParameterDeclarationFromJson(
          m['typeParameters'] as Map<String, dynamic>,
        ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// ClassBody.
ClassBody classBodyFromJson(Map<String, dynamic> m) => ClassBody(
  body:
      ((m['body'] as List<dynamic>? ?? const [])
              .map((e) => TsAstFactory.fromJson(e as Map<String, dynamic>))
              .toList())
          .cast<BaseNode>(),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// ClassExpression.
ClassExpression classExpressionFromJson(Map<String, dynamic> m) =>
    ClassExpression(
      id: m['id'] == null
          ? null
          : identifierFromJson(m['id'] as Map<String, dynamic>),
      superClass: m['superClass'] == null
          ? null
          : TsAstFactory.fromJsonExpression(
              m['superClass'] as Map<String, dynamic>,
            ),
      body: classBodyFromJson(m['body'] as Map<String, dynamic>),
      decorators: readList<Decorator>(m['decorators'], decoratorFromJson),
      implementsItems: readList<Object>(
        m['implements'],
        (mm) => TsAstFactory.fromJsonAny(mm),
      ),
      superTypeParameters: m['superTypeParameters'] == null
          ? null
          : tsTypeParameterInstantiationFromJson(
              m['superTypeParameters'] as Map<String, dynamic>,
            ),
      typeParameters: m['typeParameters'] == null
          ? null
          : tsTypeParameterDeclarationFromJson(
              m['typeParameters'] as Map<String, dynamic>,
            ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// ClassDeclaration.
ClassDeclaration classDeclarationFromJson(Map<String, dynamic> m) =>
    ClassDeclaration(
      id: m['id'] == null
          ? null
          : identifierFromJson(m['id'] as Map<String, dynamic>),
      superClass: m['superClass'] == null
          ? null
          : TsAstFactory.fromJsonExpression(
              m['superClass'] as Map<String, dynamic>,
            ),
      body: classBodyFromJson(m['body'] as Map<String, dynamic>),
      decorators: readList<Decorator>(m['decorators'], decoratorFromJson),
      abstractMember: m['abstract'] as bool?,
      declareMember: m['declare'] as bool?,
      implementsItems: readList<Object>(
        m['implements'],
        (mm) => TsAstFactory.fromJsonAny(mm),
      ),
      superTypeParameters: m['superTypeParameters'] == null
          ? null
          : tsTypeParameterInstantiationFromJson(
              m['superTypeParameters'] as Map<String, dynamic>,
            ),
      typeParameters: m['typeParameters'] == null
          ? null
          : tsTypeParameterDeclarationFromJson(
              m['typeParameters'] as Map<String, dynamic>,
            ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// StaticBlock.
StaticBlock staticBlockFromJson(Map<String, dynamic> m) => StaticBlock(
  body:
      ((m['body'] as List<dynamic>? ?? const [])
              .map((e) => TsAstFactory.fromJson(e as Map<String, dynamic>))
              .toList())
          .cast<BaseNode>(),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// TSModuleBlock.
TSModuleBlock tsModuleBlockFromJson(Map<String, dynamic> m) => TSModuleBlock(
  body:
      ((m['body'] as List<dynamic>? ?? const [])
              .map((e) => TsAstFactory.fromJson(e as Map<String, dynamic>))
              .toList())
          .cast<BaseNode>(),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// ObjectProperty.
ObjectProperty objectPropertyFromJson(Map<String, dynamic> m) => ObjectProperty(
  key: TsAstFactory.fromJsonKey(m['key'] as Map<String, dynamic>),
  value: TsAstFactory.fromJsonExpressionOrPatternLike(
    m['value'] as Map<String, dynamic>,
  ),
  computed: m['computed'] as bool,
  shorthand: m['shorthand'] as bool,
  decorators: readList<Decorator>(m['decorators'], decoratorFromJson),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// SpreadElement.
SpreadElement spreadElementFromJson(Map<String, dynamic> m) => SpreadElement(
  argument: TsAstFactory.fromJsonExpression(
    m['argument'] as Map<String, dynamic>,
  ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// RestElement.
RestElement restElementFromJson(Map<String, dynamic> m) => RestElement(
  argument: TsAstFactory.fromJsonRestArgument(
    m['argument'] as Map<String, dynamic>,
  ),
  decorators: readList<Decorator>(m['decorators'], decoratorFromJson),
  optional: m['optional'] as bool?,
  typeAnnotation: m['typeAnnotation'] == null
      ? null
      : tsTypeAnnotationFromJson(m['typeAnnotation'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// TS: type annotation wrapper.
TSTypeAnnotation tsTypeAnnotationFromJson(Map<String, dynamic> m) =>
    TSTypeAnnotation(
      typeAnnotation: TsAstFactory.fromJsonTSType(
        m['typeAnnotation'] as Map<String, dynamic>,
      ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// TS: type parameter instantiation.
TSTypeParameterInstantiation tsTypeParameterInstantiationFromJson(
  Map<String, dynamic> m,
) => TSTypeParameterInstantiation(
  params: readList<TSType>(
    m['params'],
    (mm) => TsAstFactory.fromJsonTSType(mm),
  ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// TS: type parameter declaration.
TSTypeParameterDeclaration tsTypeParameterDeclarationFromJson(
  Map<String, dynamic> m,
) => TSTypeParameterDeclaration(
  params: readList<TSTypeParameter>(m['params'], tsTypeParameterFromJson),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// TS: type parameter.
TSTypeParameter tsTypeParameterFromJson(Map<String, dynamic> m) =>
    TSTypeParameter(
      constraint: m['constraint'] == null
          ? null
          : TsAstFactory.fromJsonTSType(
              m['constraint'] as Map<String, dynamic>,
            ),
      defaultType: m['default'] == null
          ? null
          : TsAstFactory.fromJsonTSType(m['default'] as Map<String, dynamic>),
      name: m['name'] as String,
      isConst: m['const'] as bool?,
      isIn: m['in'] as bool?,
      isOut: m['out'] as bool?,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// TS: any keyword.
TSAnyKeyword tsAnyKeywordFromJson(Map<String, dynamic> m) => TSAnyKeyword(
  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// TSPropertySignature.
TSPropertySignature tsPropertySignatureFromJson(Map<String, dynamic> m) =>
    TSPropertySignature(
      key: TsAstFactory.fromJsonKey(m['key'] as Map<String, dynamic>),
      optional: m['optional'] as bool? ?? false,
      typeAnnotation: m['typeAnnotation'] == null
          ? null
          : tsTypeAnnotationFromJson(
              m['typeAnnotation'] as Map<String, dynamic>,
            ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// TSInterfaceBody.
TSInterfaceBody tsInterfaceBodyFromJson(Map<String, dynamic> m) =>
    TSInterfaceBody(
      body: readList<TSPropertySignature>(
        m['body'],
        tsPropertySignatureFromJson,
      ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// TSTypeAliasDeclaration.
TSTypeAliasDeclaration tsTypeAliasDeclarationFromJson(Map<String, dynamic> m) =>
    TSTypeAliasDeclaration(
      id: identifierFromJson(m['id'] as Map<String, dynamic>),
      members: readList<TSPropertySignature>(
        m['members'],
        tsPropertySignatureFromJson,
      ),
      typeParameters: m['typeParameters'] == null
          ? null
          : tsTypeParameterDeclarationFromJson(
              m['typeParameters'] as Map<String, dynamic>,
            ),
      declare: m['declare'] as bool?,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// TSInterfaceDeclaration.
TSInterfaceDeclaration tsInterfaceDeclarationFromJson(Map<String, dynamic> m) =>
    TSInterfaceDeclaration(
      id: identifierFromJson(m['id'] as Map<String, dynamic>),
      body: tsInterfaceBodyFromJson(m['body'] as Map<String, dynamic>),
      typeParameters: m['typeParameters'] == null
          ? null
          : tsTypeParameterDeclarationFromJson(
              m['typeParameters'] as Map<String, dynamic>,
            ),
      extendsItems: readList<Object>(
        m['extends'],
        (mm) => TsAstFactory.fromJsonAny(mm),
      ),
      declare: m['declare'] as bool?,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// TSDeclareFunction.
TSDeclareFunction tsDeclareFunctionFromJson(Map<String, dynamic> m) =>
    TSDeclareFunction(
      id: m['id'] == null
          ? null
          : identifierFromJson(m['id'] as Map<String, dynamic>),
      params: readFunctionParameters(m['params']),
      returnType: m['returnType'] == null
          ? null
          : tsTypeAnnotationFromJson(m['returnType'] as Map<String, dynamic>),
      typeParameters: m['typeParameters'] == null
          ? null
          : tsTypeParameterDeclarationFromJson(
              m['typeParameters'] as Map<String, dynamic>,
            ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// TSEnumMember.
TSEnumMember tsEnumMemberFromJson(Map<String, dynamic> m) => TSEnumMember(
  id: identifierFromJson(m['id'] as Map<String, dynamic>),
  initializer: m['initializer'] == null
      ? null
      : TsAstFactory.fromJsonExpression(
          m['initializer'] as Map<String, dynamic>,
        ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

/// TSEnumDeclaration.
TSEnumDeclaration tsEnumDeclarationFromJson(Map<String, dynamic> m) =>
    TSEnumDeclaration(
      id: identifierFromJson(m['id'] as Map<String, dynamic>),
      members: readList<TSEnumMember>(m['members'], tsEnumMemberFromJson),
      declare: m['declare'] as bool?,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

/// TSModuleDeclaration.
TSModuleDeclaration tsModuleDeclarationFromJson(Map<String, dynamic> m) =>
    TSModuleDeclaration(
      id: identifierFromJson(m['id'] as Map<String, dynamic>),
      body: tsModuleBlockFromJson(m['body'] as Map<String, dynamic>),
      declare: m['declare'] as bool?,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );
TemplateElement templateElementFromJson(Map<String, dynamic> m) =>
    TemplateElement(
      value: (m['value'] as Map<String, dynamic>).cast<String, Object?>(),
      tail: m['tail'] as bool,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

TemplateLiteral templateLiteralFromJson(Map<String, dynamic> m) =>
    TemplateLiteral(
      quasis: readList<TemplateElement>(m['quasis'], templateElementFromJson),
      expressions: (m['expressions'] as List<dynamic>? ?? const []).map((e) {
        final me = e as Map<String, dynamic>;
        final t = me['type'] as String;
        if (t.startsWith('TS')) return TsAstFactory.fromJsonTSType(me);
        return TsAstFactory.fromJsonExpression(me);
      }).toList(),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

OptionalMemberExpression optionalMemberExpressionFromJson(
  Map<String, dynamic> m,
) => OptionalMemberExpression(
  object: TsAstFactory.fromJsonExpression(m['object'] as Map<String, dynamic>),
  property: TsAstFactory.fromJsonExpressionOrIdentifierOrPrivateName(
    m['property'] as Map<String, dynamic>,
  ),
  computed: m['computed'] as bool,
  optional: m['optional'] as bool,

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

OptionalCallExpression optionalCallExpressionFromJson(Map<String, dynamic> m) =>
    OptionalCallExpression(
      callee: TsAstFactory.fromJsonExpression(
        m['callee'] as Map<String, dynamic>,
      ),
      arguments: readMixedList(m['arguments']),
      optional: m['optional'] as bool,
      typeParameters: m['typeParameters'] == null
          ? null
          : tsTypeParameterInstantiationFromJson(
              m['typeParameters'] as Map<String, dynamic>,
            ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

ImportExpression importExpressionFromJson(
  Map<String, dynamic> m,
) => ImportExpression(
  source: TsAstFactory.fromJsonExpression(m['source'] as Map<String, dynamic>),
  options: m['options'] == null
      ? null
      : TsAstFactory.fromJsonExpression(m['options'] as Map<String, dynamic>),
  phase: m['phase'] as String?,

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

DirectiveLiteral directiveLiteralFromJson(Map<String, dynamic> m) =>
    DirectiveLiteral(
      value: m['value'] as String,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

Directive directiveFromJson(Map<String, dynamic> m) => Directive(
  value: directiveLiteralFromJson(m['value'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

InterpreterDirective interpreterDirectiveFromJson(Map<String, dynamic> m) =>
    InterpreterDirective(
      value: m['value'] as String,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

BlockStatement blockStatementFromJson(Map<String, dynamic> m) => BlockStatement(
  body: readList<Statement>(m['body'], TsAstFactory.fromJsonStatement),
  directives: readList<Directive>(m['directives'], directiveFromJson),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

ReturnStatement returnStatementFromJson(Map<String, dynamic> m) =>
    ReturnStatement(
      argument: m['argument'] == null
          ? null
          : TsAstFactory.fromJsonExpression(
              m['argument'] as Map<String, dynamic>,
            ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

ThrowStatement throwStatementFromJson(Map<String, dynamic> m) => ThrowStatement(
  argument: TsAstFactory.fromJsonExpression(
    m['argument'] as Map<String, dynamic>,
  ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

EmptyStatement emptyStatementFromJson(Map<String, dynamic> m) => EmptyStatement(
  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

DebuggerStatement debuggerStatementFromJson(Map<String, dynamic> m) =>
    DebuggerStatement(
      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

BreakStatement breakStatementFromJson(Map<String, dynamic> m) => BreakStatement(
  label: m['label'] == null
      ? null
      : identifierFromJson(m['label'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

ContinueStatement continueStatementFromJson(Map<String, dynamic> m) =>
    ContinueStatement(
      label: m['label'] == null
          ? null
          : identifierFromJson(m['label'] as Map<String, dynamic>),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );
PrivateName privateNameFromJson(Map<String, dynamic> m) => PrivateName(
  id: identifierFromJson(m['id'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

V8IntrinsicIdentifier v8IntrinsicIdentifierFromJson(Map<String, dynamic> m) =>
    V8IntrinsicIdentifier(
      name: m['name'] as String,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

TSAsExpression tsAsExpressionFromJson(Map<String, dynamic> m) => TSAsExpression(
  expression: TsAstFactory.fromJsonExpression(
    m['expression'] as Map<String, dynamic>,
  ),
  typeAnnotation: TsAstFactory.fromJsonTSType(
    m['typeAnnotation'] as Map<String, dynamic>,
  ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

TSSatisfiesExpression tsSatisfiesExpressionFromJson(Map<String, dynamic> m) =>
    TSSatisfiesExpression(
      expression: TsAstFactory.fromJsonExpression(
        m['expression'] as Map<String, dynamic>,
      ),
      typeAnnotation: TsAstFactory.fromJsonTSType(
        m['typeAnnotation'] as Map<String, dynamic>,
      ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

TSTypeAssertion tsTypeAssertionFromJson(Map<String, dynamic> m) =>
    TSTypeAssertion(
      typeAnnotation: TsAstFactory.fromJsonTSType(
        m['typeAnnotation'] as Map<String, dynamic>,
      ),
      expression: TsAstFactory.fromJsonExpression(
        m['expression'] as Map<String, dynamic>,
      ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

TSNonNullExpression tsNonNullExpressionFromJson(Map<String, dynamic> m) =>
    TSNonNullExpression(
      expression: TsAstFactory.fromJsonExpression(
        m['expression'] as Map<String, dynamic>,
      ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

NumberLiteral numberLiteralFromJson(Map<String, dynamic> m) => NumberLiteral(
  value: (m['value'] as num),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);
ArgumentPlaceholder argumentPlaceholderFromJson(Map<String, dynamic> m) =>
    ArgumentPlaceholder(
      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );
ExportSpecifier exportSpecifierFromJson(Map<String, dynamic> m) =>
    ExportSpecifier(
      local: identifierFromJson(m['local'] as Map<String, dynamic>),
      exported: TsAstFactory.fromJsonIdentifierOrString(
        m['exported'] as Map<String, dynamic>,
      ),
      exportKind: m['exportKind'] as String?,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

ExportDefaultSpecifier exportDefaultSpecifierFromJson(Map<String, dynamic> m) =>
    ExportDefaultSpecifier(
      exported: identifierFromJson(m['exported'] as Map<String, dynamic>),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

ExportNamespaceSpecifier exportNamespaceSpecifierFromJson(
  Map<String, dynamic> m,
) => ExportNamespaceSpecifier(
  exported: identifierFromJson(m['exported'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

ImportDefaultSpecifier importDefaultSpecifierFromJson(Map<String, dynamic> m) =>
    ImportDefaultSpecifier(
      local: identifierFromJson(m['local'] as Map<String, dynamic>),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

ImportNamespaceSpecifier importNamespaceSpecifierFromJson(
  Map<String, dynamic> m,
) => ImportNamespaceSpecifier(
  local: identifierFromJson(m['local'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

ImportSpecifier importSpecifierFromJson(Map<String, dynamic> m) =>
    ImportSpecifier(
      local: identifierFromJson(m['local'] as Map<String, dynamic>),
      imported: TsAstFactory.fromJsonIdentifierOrString(
        m['imported'] as Map<String, dynamic>,
      ),
      importKind: m['importKind'] as String?,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );
WhileStatement whileStatementFromJson(Map<String, dynamic> m) => WhileStatement(
  test: TsAstFactory.fromJsonExpression(m['test'] as Map<String, dynamic>),
  body: TsAstFactory.fromJsonStatement(m['body'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

ForStatement forStatementFromJson(Map<String, dynamic> m) => ForStatement(
  init: TsAstFactory.fromJsonForInitNullable(m['init']),
  test: m['test'] == null
      ? null
      : TsAstFactory.fromJsonExpression(m['test'] as Map<String, dynamic>),
  update: m['update'] == null
      ? null
      : TsAstFactory.fromJsonExpression(m['update'] as Map<String, dynamic>),
  body: TsAstFactory.fromJsonStatement(m['body'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

CatchClause catchClauseFromJson(Map<String, dynamic> m) => CatchClause(
  param: m['param'] == null
      ? null
      : identifierFromJson(m['param'] as Map<String, dynamic>),
  body: blockStatementFromJson(m['body'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

TryStatement tryStatementFromJson(Map<String, dynamic> m) => TryStatement(
  block: blockStatementFromJson(m['block'] as Map<String, dynamic>),
  handler: m['handler'] == null
      ? null
      : catchClauseFromJson(m['handler'] as Map<String, dynamic>),
  finalizer: m['finalizer'] == null
      ? null
      : blockStatementFromJson(m['finalizer'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

SwitchCase switchCaseFromJson(Map<String, dynamic> m) => SwitchCase(
  test: m['test'] == null
      ? null
      : TsAstFactory.fromJsonExpression(m['test'] as Map<String, dynamic>),
  consequent: readList<Statement>(
    m['consequent'],
    TsAstFactory.fromJsonStatement,
  ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

SwitchStatement switchStatementFromJson(Map<String, dynamic> m) =>
    SwitchStatement(
      discriminant: TsAstFactory.fromJsonExpression(
        m['discriminant'] as Map<String, dynamic>,
      ),
      cases: readList<SwitchCase>(m['cases'], switchCaseFromJson),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

ForInStatement forInStatementFromJson(Map<String, dynamic> m) => ForInStatement(
  left: TsAstFactory.fromJsonForInLeft(m['left'] as Map<String, dynamic>),
  right: TsAstFactory.fromJsonExpression(m['right'] as Map<String, dynamic>),
  body: TsAstFactory.fromJsonStatement(m['body'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

ForOfStatement forOfStatementFromJson(Map<String, dynamic> m) => ForOfStatement(
  left: TsAstFactory.fromJsonForInLeft(m['left'] as Map<String, dynamic>),
  right: TsAstFactory.fromJsonExpression(m['right'] as Map<String, dynamic>),
  body: TsAstFactory.fromJsonStatement(m['body'] as Map<String, dynamic>),
  awaitFlag: m['await'] as bool,

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

IfStatement ifStatementFromJson(Map<String, dynamic> m) => IfStatement(
  test: TsAstFactory.fromJsonExpression(m['test'] as Map<String, dynamic>),
  consequent: TsAstFactory.fromJsonStatement(
    m['consequent'] as Map<String, dynamic>,
  ),
  alternate: m['alternate'] == null
      ? null
      : TsAstFactory.fromJsonStatement(m['alternate'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

CallExpression callExpressionFromJson(Map<String, dynamic> m) => CallExpression(
  callee: TsAstFactory.fromJsonExpression(m['callee'] as Map<String, dynamic>),
  arguments: readMixedList(m['arguments']),
  optional: m['optional'] as bool?,
  typeParameters: m['typeParameters'] == null
      ? null
      : tsTypeParameterInstantiationFromJson(
          m['typeParameters'] as Map<String, dynamic>,
        ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

ImportAttribute importAttributeFromJson(Map<String, dynamic> m) =>
    ImportAttribute(
      key: TsAstFactory.fromJsonIdentifierOrString(
        m['key'] as Map<String, dynamic>,
      ),
      value: stringLiteralFromJson(m['value'] as Map<String, dynamic>),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

ImportDeclaration importDeclarationFromJson(Map<String, dynamic> m) =>
    ImportDeclaration(
      specifiers: readImportSpecifiers(m['specifiers']),
      source: stringLiteralFromJson(m['source'] as Map<String, dynamic>),
      attributes: readList<ImportAttribute>(
        m['attributes'],
        importAttributeFromJson,
      ),
      importKind: m['importKind'] as String?,
      module: m['module'] as bool?,
      phase: m['phase'] as String?,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

ExportNamedDeclaration exportNamedDeclarationFromJson(Map<String, dynamic> m) =>
    ExportNamedDeclaration(
      declaration: m['declaration'] == null
          ? null
          : TsAstFactory.fromJsonDeclaration(
              m['declaration'] as Map<String, dynamic>,
            ),
      specifiers: readExportSpecifiers(m['specifiers']),
      source: m['source'] == null
          ? null
          : stringLiteralFromJson(m['source'] as Map<String, dynamic>),
      attributes: readList<ImportAttribute>(
        m['attributes'],
        importAttributeFromJson,
      ),
      exportKind: m['exportKind'] as String?,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

ExportDefaultDeclaration exportDefaultDeclarationFromJson(
  Map<String, dynamic> m,
) => ExportDefaultDeclaration(
  declaration: TsAstFactory.fromJsonExportDefaultDecl(
    m['declaration'] as Map<String, dynamic>,
  ),
  exportKind: m['exportKind'] as String?,

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

ExportStartDeclartion exportStartDeclartionFromJson(Map<String, dynamic> m) =>
    ExportStartDeclartion(
      source: stringLiteralFromJson(m['source'] as Map<String, dynamic>),
      attributes: readList<ImportAttribute>(
        m['attributes'],
        importAttributeFromJson,
      ),
      exportKind: m['exportKind'] as String?,

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );
RegExpLiteral regExpLiteralFromJson(Map<String, dynamic> m) => RegExpLiteral(
  pattern: m['pattern'] as String,
  flags: m['flags'] as String,

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

Decorator decoratorFromJson(Map<String, dynamic> m) => Decorator(
  expression: TsAstFactory.fromJsonExpression(
    m['expression'] as Map<String, dynamic>,
  ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

AssignmentPattern assignmentPatternFromJson(
  Map<String, dynamic> m,
) => AssignmentPattern(
  left: TsAstFactory.fromJsonAssignmentLeft(m['left'] as Map<String, dynamic>),
  right: TsAstFactory.fromJsonExpression(m['right'] as Map<String, dynamic>),
  decorators: readList<Decorator>(m['decorators'], decoratorFromJson),
  optional: m['optional'] as bool?,
  typeAnnotation: m['typeAnnotation'] == null
      ? null
      : tsTypeAnnotationFromJson(m['typeAnnotation'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

ArrayPattern arrayPatternFromJson(Map<String, dynamic> m) => ArrayPattern(
  elements: readOptionalPatternList(m['elements']),
  decorators: readList<Decorator>(m['decorators'], decoratorFromJson),
  optional: m['optional'] as bool?,
  typeAnnotation: m['typeAnnotation'] == null
      ? null
      : tsTypeAnnotationFromJson(m['typeAnnotation'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

ObjectPattern objectPatternFromJson(Map<String, dynamic> m) => ObjectPattern(
  properties: readObjPatternProps(m['properties']),
  decorators: readList<Decorator>(m['decorators'], decoratorFromJson),
  optional: m['optional'] as bool?,
  typeAnnotation: m['typeAnnotation'] == null
      ? null
      : tsTypeAnnotationFromJson(m['typeAnnotation'] as Map<String, dynamic>),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

VoidPattern voidPatternFromJson(Map<String, dynamic> m) => VoidPattern(
  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

ClassMethod classMethodFromJson(Map<String, dynamic> m) => ClassMethod(
  kind: m['kind'] as String,
  key: TsAstFactory.fromJsonExpressionOrIdentifierOrLiteralOrBigInt(
    m['key'] as Map<String, dynamic>,
  ),
  params: readFunctionParameters(m['params']),
  body: blockStatementFromJson(m['body'] as Map<String, dynamic>),
  computed: m['computed'] as bool,
  staticMember: m['static'] as bool,
  generator: m['generator'] as bool,
  asyncMember: m['async'] as bool,
  abstractMember: m['abstract'] as bool?,
  access: m['access'] as String?,
  accessibility: m['accessibility'] as String?,
  decorators: readList<Decorator>(m['decorators'], decoratorFromJson),
  optional: m['optional'] as bool?,
  overrideMember: m['override'] as bool?,
  returnType: m['returnType'] == null
      ? null
      : tsTypeAnnotationFromJson(m['returnType'] as Map<String, dynamic>),
  typeParameters: m['typeParameters'] == null
      ? null
      : tsTypeParameterDeclarationFromJson(
          m['typeParameters'] as Map<String, dynamic>,
        ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

ClassPrivateMethod classPrivateMethodFromJson(Map<String, dynamic> m) =>
    ClassPrivateMethod(
      kind: m['kind'] as String,
      key: privateNameFromJson(m['key'] as Map<String, dynamic>),
      params: readFunctionParameters(m['params']),
      body: blockStatementFromJson(m['body'] as Map<String, dynamic>),
      staticMember: m['static'] as bool,
      abstractMember: m['abstract'] as bool?,
      access: m['access'] as String?,
      accessibility: m['accessibility'] as String?,
      asyncMember: m['async'] as bool?,
      computed: m['computed'] as bool?,
      decorators: readList<Decorator>(m['decorators'], decoratorFromJson),
      generator: m['generator'] as bool?,
      optional: m['optional'] as bool?,
      overrideMember: m['override'] as bool?,
      returnType: m['returnType'] == null
          ? null
          : tsTypeAnnotationFromJson(m['returnType'] as Map<String, dynamic>),
      typeParameters: m['typeParameters'] == null
          ? null
          : tsTypeParameterDeclarationFromJson(
              m['typeParameters'] as Map<String, dynamic>,
            ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );

FunctionDeclaration functionDeclarationFromJson(Map<String, dynamic> m) =>
    FunctionDeclaration(
      id: m['id'] == null
          ? null
          : identifierFromJson(m['id'] as Map<String, dynamic>),
      params: readFunctionParameters(m['params']),
      body: blockStatementFromJson(m['body'] as Map<String, dynamic>),
      generator: m['generator'] as bool,
      async: m['async'] as bool,
      declare: m['declare'] as bool?,
      returnType: m['returnType'] == null
          ? null
          : tsTypeAnnotationFromJson(m['returnType'] as Map<String, dynamic>),
      typeParameters: m['typeParameters'] == null
          ? null
          : tsTypeParameterDeclarationFromJson(
              m['typeParameters'] as Map<String, dynamic>,
            ),

      loc: m['loc'] == null
          ? null
          : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

      extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
    );
Position positionFromJson(Map<String, dynamic> m) => Position(
  line: (m['line'] as num).toInt(),
  column: (m['column'] as num).toInt(),
  index: (m['index'] as num).toInt(),
);

Location sourceLocationFromJson(Map<String, dynamic> m) => Location(
  start: positionFromJson(m['start'] as Map<String, dynamic>),
  end: positionFromJson(m['end'] as Map<String, dynamic>),
  filename: m['filename'] as String,
  identifierName: m['identifierName'] as String?,
);

CommentBlock commentBlockFromJson(Map<String, dynamic> m) => CommentBlock(
  value: m['value'] as String,

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),
  ignore: m['ignore'] as bool?,
);

CommentLine commentLineFromJson(Map<String, dynamic> m) => CommentLine(
  value: m['value'] as String,

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),
  ignore: m['ignore'] as bool?,
);

BigIntLiteral bigIntLiteralFromJson(Map<String, dynamic> m) => BigIntLiteral(
  value: m['value'] as String,

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

DecimalLiteral decimalLiteralFromJson(Map<String, dynamic> m) => DecimalLiteral(
  value: m['value'] as String,

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

TaggedTemplateExpression taggedTemplateExpressionFromJson(
  Map<String, dynamic> m,
) => TaggedTemplateExpression(
  tag: TsAstFactory.fromJsonExpression(m['tag'] as Map<String, dynamic>),
  quasi: templateLiteralFromJson(m['quasi'] as Map<String, dynamic>),
  typeParameters: m['typeParameters'] == null
      ? null
      : tsTypeParameterInstantiationFromJson(
          m['typeParameters'] as Map<String, dynamic>,
        ),

  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);

Super superFromJson(Map<String, dynamic> m) => Super(
  loc: m['loc'] == null
      ? null
      : sourceLocationFromJson(m['loc'] as Map<String, dynamic>),

  extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
);
