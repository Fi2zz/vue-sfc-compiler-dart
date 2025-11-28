import 'package:vue_sfc_parser/ast.dart';

final class TsAstFactory {
  static BaseNode fromJson(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'Program':
        return programFromJson(m);
      case 'BlockStatement':
        return blockStatementFromJson(m);
      case 'EmptyStatement':
        return emptyStatementFromJson(m);
      case 'DebuggerStatement':
        return debuggerStatementFromJson(m);
      case 'ExpressionStatement':
        return expressionStatementFromJson(m);
      case 'IfStatement':
        return ifStatementFromJson(m);
      case 'WhileStatement':
        return whileStatementFromJson(m);
      case 'ForStatement':
        return forStatementFromJson(m);
      case 'TryStatement':
        return tryStatementFromJson(m);
      case 'SwitchStatement':
        return switchStatementFromJson(m);
      case 'SwitchCase':
        return switchCaseFromJson(m);
      case 'BreakStatement':
        return breakStatementFromJson(m);
      case 'ContinueStatement':
        return continueStatementFromJson(m);
      case 'ForInStatement':
        return forInStatementFromJson(m);
      case 'ForOfStatement':
        return forOfStatementFromJson(m);
      case 'Identifier':
        return identifierFromJson(m);
      case 'StringLiteral':
        return stringLiteralFromJson(m);
      case 'NumericLiteral':
        return numericLiteralFromJson(m);
      case 'NullLiteral':
        return nullLiteralFromJson(m);
      case 'BooleanLiteral':
        return booleanLiteralFromJson(m);
      case 'RegExpLiteral':
        return regExpLiteralFromJson(m);
      case 'TemplateElement':
        return templateElementFromJson(m);
      case 'TemplateLiteral':
        return templateLiteralFromJson(m);
      case 'TaggedTemplateExpression':
        return taggedTemplateExpressionFromJson(m);
      case 'OptionalMemberExpression':
        return optionalMemberExpressionFromJson(m);
      case 'OptionalCallExpression':
        return optionalCallExpressionFromJson(m);
      case 'ImportExpression':
        return importExpressionFromJson(m);
      case 'AwaitExpression':
        return awaitExpressionFromJson(m);
      case 'MetaProperty':
        return metaPropertyFromJson(m);
      case 'BigIntLiteral':
        return bigIntLiteralFromJson(m);
      case 'NumberLiteral':
        return numberLiteralFromJson(m);
      case 'DecimalLiteral':
        return decimalLiteralFromJson(m);
      case 'CallExpression':
        return callExpressionFromJson(m);
      case 'MemberExpression':
        return memberExpressionFromJson(m);
      case 'UpdateExpression':
        return updateExpressionFromJson(m);
      case 'UnaryExpression':
        return unaryExpressionFromJson(m);
      case 'BinaryExpression':
        return binaryExpressionFromJson(m);
      case 'LogicalExpression':
        return logicalExpressionFromJson(m);
      case 'AssignmentExpression':
        return assignmentExpressionFromJson(m);
      case 'ConditionalExpression':
        return conditionalExpressionFromJson(m);
      case 'ThisExpression':
        return thisExpressionFromJson(m);
      case 'NewExpression':
        return newExpressionFromJson(m);
      case 'ObjectExpression':
        return objectExpressionFromJson(m);
      case 'ArrayExpression':
        return arrayExpressionFromJson(m);
      case 'ObjectProperty':
        return objectPropertyFromJson(m);
      case 'ObjectMethod':
        return objectMethodFromJson(m);
      case 'FunctionExpression':
        return functionExpressionFromJson(m);
      case 'FunctionDeclaration':
        return functionDeclarationFromJson(m);
      case 'ArrowFunctionExpression':
        return arrowFunctionExpressionFromJson(m);
      case 'ClassMethod':
        return classMethodFromJson(m);
      case 'ClassPrivateMethod':
        return classPrivateMethodFromJson(m);
      case 'StaticBlock':
        return staticBlockFromJson(m);
      case 'TSModuleBlock':
        return tsModuleBlockFromJson(m);
      case 'ClassBody':
        return classBodyFromJson(m);
      case 'ClassExpression':
        return classExpressionFromJson(m);
      case 'ClassDeclaration':
        return classDeclarationFromJson(m);
      case 'TSPropertySignature':
        return tsPropertySignatureFromJson(m);
      case 'TSInterfaceBody':
        return tsInterfaceBodyFromJson(m);
      case 'TSInterfaceDeclaration':
        return tsInterfaceDeclarationFromJson(m);
      case 'TSEnumDeclaration':
        return tsEnumDeclarationFromJson(m);
      case 'TSModuleDeclaration':
        return tsModuleDeclarationFromJson(m);
      case 'TSTypeAliasDeclaration':
        return tsTypeAliasDeclarationFromJson(m);
      case 'TSDeclareFunction':
        return tsDeclareFunctionFromJson(m);
      case 'SpreadElement':
        return spreadElementFromJson(m);
      case 'RestElement':
        return restElementFromJson(m);
      case 'AssignmentPattern':
        return assignmentPatternFromJson(m);
      case 'ArrayPattern':
        return arrayPatternFromJson(m);
      case 'ObjectPattern':
        return objectPatternFromJson(m);
      case 'VoidPattern':
        return voidPatternFromJson(m);
      case 'Decorator':
        return decoratorFromJson(m);
      case 'ImportDeclaration':
        return importDeclarationFromJson(m);
      case 'ExportNamedDeclaration':
        return exportNamedDeclarationFromJson(m);
      case 'ExportDefaultDeclaration':
        return exportDefaultDeclarationFromJson(m);
      case 'ExportAllDeclaration':
        return exportStartDeclartionFromJson(m);
      case 'ImportAttribute':
        return importAttributeFromJson(m);
      case 'ExportSpecifier':
        return exportSpecifierFromJson(m);
      case 'ExportDefaultSpecifier':
        return exportDefaultSpecifierFromJson(m);
      case 'ExportNamespaceSpecifier':
        return exportNamespaceSpecifierFromJson(m);
      case 'ImportDefaultSpecifier':
        return importDefaultSpecifierFromJson(m);
      case 'ImportNamespaceSpecifier':
        return importNamespaceSpecifierFromJson(m);
      case 'ImportSpecifier':
        return importSpecifierFromJson(m);
      case 'TSTypeAnnotation':
        return tsTypeAnnotationFromJson(m);
      case 'TSTypeParameterInstantiation':
        return tsTypeParameterInstantiationFromJson(m);
      case 'TSTypeParameterDeclaration':
        return tsTypeParameterDeclarationFromJson(m);
      case 'TSTypeParameter':
        return tsTypeParameterFromJson(m);
      case 'TSAnyKeyword':
        return tsAnyKeywordFromJson(m);
      default:
        return UnknownNode(m);
    }
  }

  static Statement fromJsonStatement(Map<String, dynamic> m) =>
      fromJson(m) as Statement;
  static Expression fromJsonExpression(Map<String, dynamic> m) =>
      fromJson(m) as Expression;
  static Declaration fromJsonDeclaration(Map<String, dynamic> m) =>
      fromJson(m) as Declaration;
  static TSType fromJsonTSType(Map<String, dynamic> m) => fromJson(m) as TSType;

  static Object fromJsonAny(Map<String, dynamic> m) {
    final t = m['type'] as String;
    if (t == 'SpreadElement') return spreadElementFromJson(m);
    if (t == 'ArgumentPlaceholder') return argumentPlaceholderFromJson(m);
    return fromJsonExpression(m);
  }

  static Object fromJsonExpressionOrSuper(Map<String, dynamic> m) {
    final t = m['type'] as String;
    if (t == 'Super') return superFromJson(m);
    return fromJsonExpression(m);
  }

  static Object fromJsonExpressionOrSuperOrV8Intrinsic(Map<String, dynamic> m) {
    final t = m['type'] as String;
    if (t == 'Super') return superFromJson(m);
    if (t == 'V8IntrinsicIdentifier') return v8IntrinsicIdentifierFromJson(m);
    return fromJsonExpression(m);
  }

  static Object fromJsonExpressionOrIdentifierOrPrivateName(
    Map<String, dynamic> m,
  ) {
    final t = m['type'] as String;
    if (t == 'Identifier') return identifierFromJson(m);
    if (t == 'PrivateName') return privateNameFromJson(m);
    return fromJsonExpression(m);
  }

  static Object fromJsonIdentifierOrString(Map<String, dynamic> m) {
    final t = m['type'] as String;
    if (t == 'Identifier') return identifierFromJson(m);
    return stringLiteralFromJson(m);
  }

  static Object fromJsonObjectMember(Map<String, dynamic> m) {
    final t = m['type'] as String;
    if (t == 'ObjectMethod') return objectMethodFromJson(m);
    if (t == 'ObjectProperty') return objectPropertyFromJson(m);
    if (t == 'Property') {
      final kind = (m['kind'] as String?) ?? 'init';
      final computed = (m['computed'] as bool?) ?? false;
      final shorthand = (m['shorthand'] as bool?) ?? false;
      final method = (m['method'] as bool?) ?? false;
      final keyJson = m['key'] as Map<String, dynamic>;
      final key = TsAstFactory.fromJsonKey(keyJson);
      if (method || kind == 'method' || kind == 'get' || kind == 'set') {
        final valueJson = m['value'] as Map<String, dynamic>?;
        final gen = valueJson == null
            ? false
            : (valueJson['generator'] as bool?) ?? false;
        final asy = valueJson == null
            ? false
            : (valueJson['async'] as bool?) ?? false;
        return ObjectMethod(
          kind: kind,
          key: key,
          params: const [],
          body: const BlockStatement(body: [], directives: []),
          computed: computed,
          generator: gen,
          async: asy,
          decorators: null,
          returnType: null,
          typeParameters: null,
        );
      }
      final valueJson = m['value'] as Map<String, dynamic>;
      final value = TsAstFactory.fromJsonExpressionOrPatternLike(valueJson);
      return ObjectProperty(
        key: key,
        value: value,
        computed: computed,
        shorthand: shorthand,
        decorators: null,
      );
    }
    return spreadElementFromJson(m);
  }

  static Object fromJsonObjectPatternProp(Map<String, dynamic> m) {
    final t = m['type'] as String;
    if (t == 'RestElement') return restElementFromJson(m);
    return objectPropertyFromJson(m);
  }

  static Object fromJsonFunctionParameter(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'Identifier':
        return identifierFromJson(m);
      case 'RestElement':
        return restElementFromJson(m);
      case 'AssignmentPattern':
        return assignmentPatternFromJson(m);
      case 'ArrayPattern':
        return arrayPatternFromJson(m);
      case 'ObjectPattern':
        return objectPatternFromJson(m);
      case 'VoidPattern':
        return voidPatternFromJson(m);
      default:
        return UnknownNode(m);
    }
  }

  static Object fromJsonKey(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'Identifier':
        return identifierFromJson(m);
      case 'StringLiteral':
        return stringLiteralFromJson(m);
      case 'NumericLiteral':
        return numericLiteralFromJson(m);
      case 'BigIntLiteral':
        return bigIntLiteralFromJson(m);
      case 'DecimalLiteral':
        return decimalLiteralFromJson(m);
      case 'PrivateName':
        return privateNameFromJson(m);
      default:
        return fromJsonExpression(m);
    }
  }

  static Object fromJsonExpressionOrIdentifierOrLiteralOrBigInt(
    Map<String, dynamic> m,
  ) {
    final t = m['type'] as String;
    switch (t) {
      case 'Identifier':
        return identifierFromJson(m);
      case 'StringLiteral':
        return stringLiteralFromJson(m);
      case 'NumericLiteral':
        return numberLiteralFromJson(m);
      case 'BigIntLiteral':
        return bigIntLiteralFromJson(m);
      default:
        return fromJsonExpression(m);
    }
  }

  static Object fromJsonExpressionOrPatternLike(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'Identifier':
        return identifierFromJson(m);
      case 'MemberExpression':
        return memberExpressionFromJson(m);
      case 'UpdateExpression':
        return updateExpressionFromJson(m);
      case 'UnaryExpression':
        return unaryExpressionFromJson(m);
      case 'BinaryExpression':
        return binaryExpressionFromJson(m);
      case 'LogicalExpression':
        return logicalExpressionFromJson(m);
      case 'AssignmentExpression':
        return assignmentExpressionFromJson(m);
      case 'ConditionalExpression':
        return conditionalExpressionFromJson(m);
      case 'ThisExpression':
        return thisExpressionFromJson(m);
      case 'RestElement':
        return restElementFromJson(m);
      case 'AssignmentPattern':
        return assignmentExpressionFromJson(m);
      case 'ArrayPattern':
        return arrayPatternFromJson(m);
      case 'ObjectPattern':
        return objectPatternFromJson(m);
      case 'VoidPattern':
        return voidPatternFromJson(m);
      case 'TSAsExpression':
        return tsAsExpressionFromJson(m);
      case 'TSSatisfiesExpression':
        return tsSatisfiesExpressionFromJson(m);
      case 'TSTypeAssertion':
        return tsTypeAssertionFromJson(m);
      case 'TSNonNullExpression':
        return tsNonNullExpressionFromJson(m);
      default:
        return fromJsonExpression(m);
    }
  }

  static Object fromJsonRestArgument(Map<String, dynamic> m) {
    return fromJsonExpressionOrPatternLike(m);
  }

  static Object fromJsonAssignmentLeft(Map<String, dynamic> m) {
    return fromJsonExpressionOrPatternLike(m);
  }

  static Object? fromJsonForInitNullable(dynamic v) {
    if (v == null) return null;
    final m = v as Map<String, dynamic>;
    final t = m['type'] as String;
    if (t == 'VariableDeclaration') return UnknownNode(m);
    return fromJsonExpression(m);
  }

  static Object fromJsonForInLeft(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'VariableDeclaration':
        return UnknownNode(m);
      case 'Identifier':
        return identifierFromJson(m);
      case 'AssignmentPattern':
        return assignmentPatternFromJson(m);
      case 'MemberExpression':
        return memberExpressionFromJson(m);
      default:
        return UnknownNode(m);
    }
  }

  static Object fromJsonExportDefaultDecl(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'TSDeclareFunction':
        return tsDeclareFunctionFromJson(m);
      case 'FunctionDeclaration':
        return functionDeclarationFromJson(m);
      case 'ClassDeclaration':
        return classDeclarationFromJson(m);
      default:
        return fromJsonExpression(m);
    }
  }

  static Object fromJsonImportSpecifier(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'ImportDefaultSpecifier':
        return importDefaultSpecifierFromJson(m);
      case 'ImportNamespaceSpecifier':
        return importNamespaceSpecifierFromJson(m);
      case 'ImportSpecifier':
        return importSpecifierFromJson(m);
      default:
        return UnknownNode(m);
    }
  }

  static Object fromJsonExportSpecifier(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'ExportSpecifier':
        return exportSpecifierFromJson(m);
      case 'ExportDefaultSpecifier':
        return exportDefaultSpecifierFromJson(m);
      case 'ExportNamespaceSpecifier':
        return exportNamespaceSpecifierFromJson(m);
      default:
        return UnknownNode(m);
    }
  }
}
