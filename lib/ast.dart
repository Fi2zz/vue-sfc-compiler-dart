/// Dart representation of the TypeScript AST used by the compiler.
/// Provides node classes, unions, and helpers for JSON conversion.
/// All classes and functions include concise Dart doc comments for clarity.
library;

import 'package:vue_sfc_parser/ts_ast_factory.dart';
part 'from_json.dart';
part 'from_json_helpers.dart';

/// Position within a source file.
final class Position {
  final int line;
  final int column;
  final int index;
  const Position({
    required this.line,
    required this.column,
    required this.index,
  });
}

/// Source location with start/end positions and metadata.
final class Location {
  final Position start;
  final Position end;
  final String filename;
  final String? identifierName;
  const Location({
    required this.start,
    required this.end,
    required this.filename,
    this.identifierName,
  });
}

/// Comment block or line attached to nodes.
sealed class Comment {
  final String value;
  final int? start;
  final int? end;
  final Location? loc;
  final bool? ignore;
  // placement indicates semantic position classification within the program:
  // 'leading' | 'inner' | 'trailing'
  final String? placement;
  const Comment({
    required this.value,
    this.start,
    this.end,
    this.loc,
    this.ignore,
    this.placement,
  });
}

/// Multiline comment.
final class CommentBlock extends Comment {
  const CommentBlock({
    required super.value,
    super.loc,
    super.ignore,
    super.placement,
  });
}

/// Single line comment.
final class CommentLine extends Comment {
  const CommentLine({
    required super.value,
    super.loc,
    super.ignore,
    super.placement,
  });
}

/// Base node for all AST nodes.
sealed class BaseNode {
  final List<Comment>? comments;
  final Location? loc;
  final Map<String, Object?>? extra;
  final String text;
  const BaseNode({
    this.comments = const [],
    this.loc,
    this.extra,
    this.text = '',
  });
}

/// Expression union base.
sealed class Expression extends BaseNode {
  const Expression({super.loc, super.extra, super.text, super.comments});
}

/// Statement union base.
sealed class Statement extends BaseNode {
  const Statement({super.loc, super.extra, super.text, super.comments});
}

/// Declaration union base.
sealed class Declaration extends Statement {
  const Declaration({super.loc, super.extra, super.text, super.comments});
}

/// Pattern base.
sealed class PatternLike extends BaseNode {
  const PatternLike({super.loc, super.extra, super.text, super.comments});
}

/// Identifier node.
final class Identifier extends Expression {
  final String name;
  final List<Decorator>? decorators;
  final bool? optional;
  final TSTypeAnnotation? typeAnnotation;
  Identifier({
    required this.name,
    super.text,
    this.decorators,
    this.optional,
    this.typeAnnotation,
    super.loc,
    super.extra,
    super.comments,
  }); // : name = name ?? extractIdentifierName(text ?? ''),
  //  super(text: text ?? '');
} // ignore: unintended_html_in_doc_comment

/// Extract terminal identifier name from raw text like `ns.name&lt;T&gt;`.
String extractIdentifierName(String t) {
  final s = t.trim();
  if (s.isEmpty) return s;
  int end = s.length;
  final iParen = s.indexOf('(');
  final iGeneric = s.indexOf('<');
  if (iParen >= 0) end = iParen;
  if (iGeneric >= 0 && iGeneric < end) end = iGeneric;
  var prefix = s.substring(0, end).trim();
  if (prefix.isEmpty) return s;
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

/// String literal.
abstract class Literal {}

final class StringLiteral extends Expression implements Literal {
  final String value;
  const StringLiteral({
    String? value,
    String? stringValue,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : value = value ?? (stringValue ?? ''),
       super(text: text ?? '');
  String get stringValue => value;
}

/// Numeric literal.
final class NumericLiteral extends Expression implements Literal {
  final num value;
  const NumericLiteral({
    required this.value,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Null literal.
final class NullLiteral extends Expression implements Literal {
  const NullLiteral({String? text, super.loc, super.extra, super.comments});
}

/// Boolean literal.
final class BooleanLiteral extends Expression implements Literal {
  final bool value;
  const BooleanLiteral({
    required this.value,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// BigInt literal.
final class BigIntLiteral extends Expression implements Literal {
  final Object value;
  const BigIntLiteral({
    required this.value,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Decimal literal.
final class DecimalLiteral extends Expression implements Literal {
  final String value;
  const DecimalLiteral({
    required this.value,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// RegExp literal.
final class RegExpLiteral extends Expression implements Literal {
  final String pattern;
  final String flags;
  const RegExpLiteral({
    required this.pattern,
    required this.flags,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

final class TemplateElement extends BaseNode {
  final Map<String, Object?> value;
  final bool tail;
  const TemplateElement({
    required this.value,
    required this.tail,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

final class TemplateLiteral extends Expression {
  final List<TemplateElement> quasis;
  final List<Object> expressions;
  const TemplateLiteral({
    required this.quasis,
    required this.expressions,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

final class TaggedTemplateExpression extends Expression {
  final Expression tag;
  final TemplateLiteral quasi;
  final TSTypeParameterInstantiation? typeParameters;
  const TaggedTemplateExpression({
    required this.tag,
    required this.quasi,
    this.typeParameters,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

final class OptionalMemberExpression extends Expression {
  final Object object;
  final Object property;
  final bool computed;
  final bool optional;
  const OptionalMemberExpression({
    required this.object,
    required this.property,
    required this.computed,
    required this.optional,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

final class OptionalCallExpression extends Expression {
  final Expression callee;
  final List<Object?> arguments;
  final bool optional;
  final TSTypeParameterInstantiation? typeParameters;
  const OptionalCallExpression({
    required this.callee,
    required this.arguments,
    required this.optional,
    this.typeParameters,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

final class ImportExpression extends Expression {
  final Expression source;
  final Expression? options;
  final String? phase;
  const ImportExpression({
    required this.source,
    this.options,
    this.phase,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

final class PropSignature {
  final String name;
  final String? type;
  final bool required;
  const PropSignature({required this.name, this.type, required this.required});
}

/// Program root. Holds executable statements (`body`) and program-level
/// comments (`comments`) in parallel.
final class Program extends BaseNode {
  final List<Statement> body;
  final List<Directive> directives;
  final String sourceType; // 'script' | 'module'
  final InterpreterDirective? interpreter;
  const Program({
    required this.body,
    required this.directives,
    required this.sourceType,
    this.interpreter,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Directive literal ("use strict" etc.).
final class DirectiveLiteral extends BaseNode {
  final String value;
  const DirectiveLiteral({
    required this.value,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Directive wrapper.
final class Directive extends BaseNode {
  final DirectiveLiteral value;
  const Directive({
    required this.value,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Interpreter directive (hashbang).
final class InterpreterDirective extends BaseNode {
  final String value;
  const InterpreterDirective({
    required this.value,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Block statement.
final class BlockStatement extends Statement {
  final List<Statement> body;
  final List<Directive> directives;
  const BlockStatement({
    required this.body,
    required this.directives,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Expression statement.
final class ExpressionStatement extends Statement {
  final Expression expression;
  final Object? declaration;
  const ExpressionStatement({
    required this.expression,
    this.declaration,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

/// Return statement.
final class ReturnStatement extends Statement {
  final Expression? argument;
  const ReturnStatement({
    this.argument,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Throw statement.
final class ThrowStatement extends Statement {
  final Expression argument;
  const ThrowStatement({
    required this.argument,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Empty statement matching ast.ts `EmptyStatement`.
final class EmptyStatement extends Statement {
  const EmptyStatement({super.loc, super.extra, super.comments});
}

/// Debugger statement matching ast.ts `DebuggerStatement`.
final class DebuggerStatement extends Statement {
  const DebuggerStatement({super.loc, super.extra});
}

/// Break statement matching ast.ts `BreakStatement`.
final class BreakStatement extends Statement {
  final Identifier? label;
  const BreakStatement({this.label, super.loc, super.extra});
}

/// Continue statement matching ast.ts `ContinueStatement`.
final class ContinueStatement extends Statement {
  final Identifier? label;
  const ContinueStatement({this.label, super.loc, super.extra});
}

/// While statement matching ast.ts `WhileStatement`.
final class WhileStatement extends Statement {
  final Expression test;
  final Statement body;
  const WhileStatement({
    required this.test,
    required this.body,
    super.loc,
    super.extra,
  });
}

final class DoWhileStatement extends Statement {
  final Statement body;
  final Expression test;
  const DoWhileStatement({
    required this.body,
    required this.test,
    super.loc,
    super.extra,
  });
}

/// For statement matching ast.ts `ForStatement`.
final class ForStatement extends Statement {
  final Object? init; // Expression | VariableDeclaration | null
  final Expression? test;
  final Expression? update;
  final Statement body;
  const ForStatement({
    this.init,
    this.test,
    this.update,
    required this.body,
    super.loc,
    super.extra,
  });
}

/// Try statement matching ast.ts `TryStatement`.
final class TryStatement extends Statement {
  final BlockStatement block;
  final CatchClause? handler;
  final BlockStatement? finalizer;
  const TryStatement({
    required this.block,
    this.handler,
    this.finalizer,
    super.loc,
    super.extra,
  });
}

/// Catch clause matching ast.ts `CatchClause`.
final class CatchClause extends BaseNode {
  final Identifier? param;
  final BlockStatement body;
  const CatchClause({this.param, required this.body, super.loc, super.extra});
}

/// Switch statement matching ast.ts `SwitchStatement`.
final class SwitchStatement extends Statement {
  final Expression discriminant;
  final List<SwitchCase> cases;
  const SwitchStatement({
    required this.discriminant,
    required this.cases,
    super.loc,
    super.extra,
  });
}

/// Switch case matching ast.ts `SwitchCase`.
final class SwitchCase extends BaseNode {
  final Expression? test;
  final List<Statement> consequent;
  const SwitchCase({
    this.test,
    required this.consequent,
    super.loc,
    super.extra,
  });
}

/// For-in statement matching ast.ts `ForInStatement`.
final class ForInStatement extends Statement {
  final Object
  left; // VariableDeclaration | Identifier | AssignmentPattern | MemberExpression
  final Expression right;
  final Statement body;
  const ForInStatement({
    required this.left,
    required this.right,
    required this.body,
    super.loc,
    super.extra,
  });
}

/// For-of statement matching ast.ts `ForOfStatement`.
final class ForOfStatement extends Statement {
  final Object
  left; // VariableDeclaration | Identifier | AssignmentPattern | MemberExpression
  final Expression right;
  final Statement body;
  final bool awaitFlag;
  const ForOfStatement({
    required this.left,
    required this.right,
    required this.body,
    required this.awaitFlag,
    super.loc,
    super.extra,
  });
}

/// If statement.
final class IfStatement extends Statement {
  final Expression test;
  final Statement consequent;
  final Statement? alternate;
  const IfStatement({
    required this.test,
    required this.consequent,
    this.alternate,
    super.loc,
    super.extra,
  });
}

/// Expression: call.
final class CallExpression extends Expression {
  final Expression callee;
  final List<Object?>
  arguments; // Expression | SpreadElement | ArgumentPlaceholder
  final bool? optional;
  final TSTypeParameterInstantiation? typeParameters;
  const CallExpression({
    required this.callee,
    required this.arguments,
    this.optional,
    this.typeParameters,
    super.loc,
    super.extra,
  });
}

/// Expression: member access.
final class MemberExpression extends Expression {
  final Object object; // Expression | Super
  final Object property; // Expression | Identifier | PrivateName
  final bool computed;
  final bool? optional;
  const MemberExpression({
    required this.object,
    required this.property,
    required this.computed,
    this.optional,
    super.loc,
    super.extra,
  });
}

/// Expression: new.
final class NewExpression extends Expression {
  final Object callee; // Expression | Super | V8IntrinsicIdentifier
  final List<Object?>
  arguments; // Expression | SpreadElement | ArgumentPlaceholder
  final bool? optional;
  final TSTypeParameterInstantiation? typeParameters;
  const NewExpression({
    required this.callee,
    required this.arguments,
    this.optional,
    this.typeParameters,
    super.loc,
    super.extra,
  });
}

/// Object expression.
final class ObjectExpression extends Expression {
  final List<Object>
  properties; // ObjectMethod | ObjectProperty | SpreadElement
  const ObjectExpression({required this.properties, super.loc, super.extra});
}

/// Array expression matching ast.ts `ArrayExpression`.
/// elements: list of `Expression | null` values.
final class ArrayExpression extends Expression {
  final List<Object?> elements;
  const ArrayExpression({required this.elements, super.loc, super.extra});
}

/// Update expression matching ast.ts `UpdateExpression`.
final class UpdateExpression extends Expression {
  final String operator; // ++ | --
  final Expression argument;
  final bool prefix;
  const UpdateExpression({
    required this.operator,
    required this.argument,
    required this.prefix,
    super.loc,
    super.extra,
  });
}

/// Unary expression matching ast.ts `UnaryExpression`.
final class UnaryExpression extends Expression {
  final String operator; // + | - | ! | ~ | typeof | void | delete
  final Expression argument;
  final bool prefix;
  const UnaryExpression({
    required this.operator,
    required this.argument,
    required this.prefix,
    super.loc,
    super.extra,
  });
}

/// Binary expression matching ast.ts `BinaryExpression`.
final class BinaryExpression extends Expression {
  final String operator;
  final Expression left;
  final Expression right;
  const BinaryExpression({
    required this.operator,
    required this.left,
    required this.right,
    super.loc,
    super.extra,
  });
}

/// Logical expression matching ast.ts `LogicalExpression`.
final class LogicalExpression extends Expression {
  final String operator; // || | && | ??
  final Expression left;
  final Expression right;
  const LogicalExpression({
    required this.operator,
    required this.left,
    required this.right,
    super.loc,
    super.extra,
  });
}

/// Assignment expression matching ast.ts `AssignmentExpression`.
final class AssignmentExpression extends Expression {
  final String operator;
  final Expression left;
  final Expression right;
  const AssignmentExpression({
    required this.operator,
    required this.left,
    required this.right,
    super.loc,
    super.extra,
  });
}

/// Conditional expression matching ast.ts `ConditionalExpression`.
final class ConditionalExpression extends Expression {
  final Expression test;
  final Expression consequent;
  final Expression alternate;
  const ConditionalExpression({
    required this.test,
    required this.consequent,
    required this.alternate,
    super.loc,
    super.extra,
  });
}

/// This expression matching ast.ts `ThisExpression`.
final class ThisExpression extends Expression {
  const ThisExpression({super.loc, super.extra});
}

/// Await expression matching ast.ts `AwaitExpression`.
final class AwaitExpression extends Expression {
  final Expression argument;
  const AwaitExpression({required this.argument, super.loc, super.extra});
}

/// Meta property matching ast.ts `MetaProperty`.
final class MetaProperty extends Expression {
  final Identifier meta;
  final Identifier property;
  const MetaProperty({
    required this.meta,
    required this.property,
    super.loc,
    super.extra,
  });
}

/// Function expression node matching ast.ts `FunctionExpression`.
/// Represents `function (params) { body }` with optional identifier and TS typing.
final class FunctionExpression extends Expression {
  final Identifier? id;
  final List<Object> params; // FunctionParameter
  final BlockStatement body;
  final bool generator;
  final bool async;
  final TSTypeAnnotation? returnType;
  final TSTypeParameterDeclaration? typeParameters;
  const FunctionExpression({
    this.id,
    required this.params,
    required this.body,
    required this.generator,
    required this.async,
    this.returnType,
    this.typeParameters,
    super.loc,
    super.extra,
    super.text,
  });
}

/// Object method.
final class ObjectMethod extends BaseNode {
  final String kind; // method|get|set
  final Object
  key; // Expression | Identifier | StringLiteral | NumericLiteral | BigIntLiteral
  final List<Object> params; // FunctionParameter
  final BlockStatement body;
  final bool computed;
  final bool generator;
  final bool async;
  final List<Decorator>? decorators;
  final TSTypeAnnotation? returnType;
  final TSTypeParameterDeclaration? typeParameters;
  const ObjectMethod({
    required this.kind,
    required this.key,
    required this.params,
    required this.body,
    required this.computed,
    required this.generator,
    required this.async,
    this.decorators,
    this.returnType,
    this.typeParameters,
    super.loc,
    super.extra,
  });
}

/// Arrow function expression (`() => expr` or `async () => { ... }`).
final class ArrowFunctionExpression extends Expression {
  final List<Object> params; // FunctionParameter
  final Object body; // BlockStatement | Expression
  final bool async;
  final bool expression;
  final bool? generator;
  final TSTypeAnnotation? returnType;
  final TSTypeParameterDeclaration? typeParameters;
  const ArrowFunctionExpression({
    required this.params,
    required this.body,
    required this.async,
    required this.expression,
    this.generator,
    this.returnType,
    this.typeParameters,
    super.loc,
    super.extra,
    super.text,
  });
}

/// Class method declaration, including constructor and accessors.
final class ClassMethod extends BaseNode {
  final String kind; // get | set | method | constructor
  final Object
  key; // Identifier | StringLiteral | NumericLiteral | BigIntLiteral | Expression
  final List<Object> params; // FunctionParameter | TSParameterProperty
  final BlockStatement body;
  final bool computed;
  final bool staticMember;
  final bool generator;
  final bool asyncMember;
  final bool? abstractMember;
  final String? access;
  final String? accessibility;
  final List<Decorator>? decorators;
  final bool? optional;
  final bool? overrideMember;
  final TSTypeAnnotation? returnType;
  final TSTypeParameterDeclaration? typeParameters;
  const ClassMethod({
    required this.kind,
    required this.key,
    required this.params,
    required this.body,
    required this.computed,
    required this.staticMember,
    required this.generator,
    required this.asyncMember,
    this.abstractMember,
    this.access,
    this.accessibility,
    this.decorators,
    this.optional,
    this.overrideMember,
    this.returnType,
    this.typeParameters,
    super.loc,
    super.extra,
  });
}

/// Private class method (`#name`).
final class ClassPrivateMethod extends BaseNode {
  final String kind; // get | set | method
  final PrivateName key;
  final List<Object> params; // FunctionParameter | TSParameterProperty
  final BlockStatement body;
  final bool staticMember;
  final bool? abstractMember;
  final String? access;
  final String? accessibility;
  final bool? asyncMember;
  final bool? computed;
  final List<Decorator>? decorators;
  final bool? generator;
  final bool? optional;
  final bool? overrideMember;
  final TSTypeAnnotation? returnType;
  final TSTypeParameterDeclaration? typeParameters;
  const ClassPrivateMethod({
    required this.kind,
    required this.key,
    required this.params,
    required this.body,
    required this.staticMember,
    this.abstractMember,
    this.access,
    this.accessibility,
    this.asyncMember,
    this.computed,
    this.decorators,
    this.generator,
    this.optional,
    this.overrideMember,
    this.returnType,
    this.typeParameters,
    super.loc,
    super.extra,
  });
}

/// Class body container for class members.
final class ClassBody extends BaseNode {
  final List<BaseNode> body;
  const ClassBody({required this.body, super.loc, super.extra});
}

/// Class expression (`class {}`), optionally named and typed.
final class ClassExpression extends BaseNode {
  final Identifier? id;
  final Expression? superClass;
  final ClassBody body;
  final List<Decorator>? decorators;
  final List<Object>? implementsItems;
  final TSTypeParameterInstantiation? superTypeParameters;
  final TSTypeParameterDeclaration? typeParameters;
  const ClassExpression({
    this.id,
    this.superClass,
    required this.body,
    this.decorators,
    this.implementsItems,
    this.superTypeParameters,
    this.typeParameters,
    super.loc,
    super.extra,
  });
}

/// Class declaration (`class Name {}`) with optional typing and decorators.
final class ClassDeclaration extends BaseNode {
  final Identifier? id;
  final Expression? superClass;
  final ClassBody body;
  final List<Decorator>? decorators;
  final bool? abstractMember;
  final bool? declareMember;
  final List<Object>? implementsItems;
  final TSTypeParameterInstantiation? superTypeParameters;
  final TSTypeParameterDeclaration? typeParameters;
  const ClassDeclaration({
    this.id,
    this.superClass,
    required this.body,
    this.decorators,
    this.abstractMember,
    this.declareMember,
    this.implementsItems,
    this.superTypeParameters,
    this.typeParameters,
    super.loc,
    super.extra,
  });
}

/// Returns whether `n` is a class node (declaration or expression).
bool isClassNode(BaseNode n) {
  return n is ClassExpression || n is ClassDeclaration;
}

/// Returns whether `n` is a function-like node.
bool isFunctionNode(BaseNode n) {
  return n is FunctionDeclaration ||
      n is FunctionExpression ||
      n is ObjectMethod ||
      n is ArrowFunctionExpression ||
      n is ClassMethod ||
      n is ClassPrivateMethod;
}

/// Static initialization block inside a class.
final class StaticBlock extends BaseNode {
  final List<BaseNode> body; // Array<Statement>
  const StaticBlock({required this.body, super.loc, super.extra});
}

/// TypeScript namespace (`module`) body block.
final class TSModuleBlock extends BaseNode {
  final List<BaseNode> body; // Array<Statement>
  const TSModuleBlock({required this.body, super.loc, super.extra});
}

/// Returns whether `n` can contain function-scoped declarations.
bool isFunctionParentNode(BaseNode n) {
  return isFunctionNode(n) || n is StaticBlock || n is TSModuleBlock;
}

/// Function declaration node matching ast.ts `FunctionDeclaration`.
final class FunctionDeclaration extends Declaration {
  final Identifier? id;
  final List<Object> params; // FunctionParameter
  final BlockStatement body;
  final bool generator;
  final bool async;
  final bool? declare;
  final TSTypeAnnotation? returnType;
  final TSTypeParameterDeclaration? typeParameters;
  const FunctionDeclaration({
    this.id,
    required this.params,
    required this.body,
    required this.generator,
    required this.async,
    this.declare,
    this.returnType,
    this.typeParameters,
    super.loc,
    super.extra,
    super.text,
  });
}

/// Object property.
final class ObjectProperty extends BaseNode {
  final Object
  key; // Expression | Identifier | StringLiteral | NumericLiteral | BigIntLiteral | DecimalLiteral | PrivateName
  final Object value; // Expression | PatternLike
  final bool computed;
  final bool shorthand;
  final List<Decorator>? decorators;
  const ObjectProperty({
    required this.key,
    required this.value,
    required this.computed,
    required this.shorthand,
    this.decorators,
    super.loc,
    super.extra,
  });
}

/// Spread element in object/array.
final class SpreadElement extends BaseNode {
  final Expression argument;
  const SpreadElement({
    required this.argument,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Rest element in patterns.
final class RestElement extends PatternLike {
  final Object
  argument; // Identifier | ArrayPattern | ObjectPattern | MemberExpression | TSAsExpression | TSSatisfiesExpression | TSTypeAssertion | TSNonNullExpression | RestElement | AssignmentPattern
  final List<Decorator>? decorators;
  final bool? optional;
  final TSTypeAnnotation? typeAnnotation;
  const RestElement({
    required this.argument,
    this.decorators,
    this.optional,
    this.typeAnnotation,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Assignment pattern.
final class AssignmentPattern extends PatternLike {
  final Object
  left; // Identifier | ObjectPattern | ArrayPattern | MemberExpression | TSAsExpression | TSSatisfiesExpression | TSTypeAssertion | TSNonNullExpression
  final Expression right;
  final List<Decorator>? decorators;
  final bool? optional;
  final TSTypeAnnotation? typeAnnotation;
  const AssignmentPattern({
    required this.left,
    required this.right,
    this.decorators,
    this.optional,
    this.typeAnnotation,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Array pattern.
final class ArrayPattern extends PatternLike {
  final List<Object?> elements; // null | PatternLike
  final List<Decorator>? decorators;
  final bool? optional;
  final TSTypeAnnotation? typeAnnotation;
  const ArrayPattern({
    required this.elements,
    this.decorators,
    this.optional,
    this.typeAnnotation,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Object pattern.
final class ObjectPattern extends PatternLike {
  final List<Object> properties; // RestElement | ObjectProperty
  final List<Decorator>? decorators;
  final bool? optional;
  final TSTypeAnnotation? typeAnnotation;
  const ObjectPattern({
    required this.properties,
    this.decorators,
    this.optional,
    this.typeAnnotation,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Void pattern.
final class VoidPattern extends PatternLike {
  const VoidPattern({super.loc, super.extra, super.comments});
}

/// Decorator.
final class Decorator extends BaseNode {
  final Expression expression;
  const Decorator({
    required this.expression,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Import declaration.
final class ImportDeclaration extends Declaration {
  final List<Object>
  specifiers; // ImportSpecifier | ImportDefaultSpecifier | ImportNamespaceSpecifier
  final StringLiteral source;
  final List<ImportAttribute>? attributes;
  final String? importKind; // type | typeof | value
  final bool? module;
  final String? phase; // source | defer
  const ImportDeclaration({
    required this.specifiers,
    required this.source,
    this.attributes,
    this.importKind,
    this.module,
    this.phase,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Export named declaration.
final class ExportNamedDeclaration extends Declaration {
  final Declaration? declaration;
  final List<Object>
  specifiers; // ExportSpecifier | ExportDefaultSpecifier | ExportNamespaceSpecifier
  final StringLiteral? source;
  final List<ImportAttribute>? attributes;
  final String? exportKind; // type | value
  const ExportNamedDeclaration({
    this.declaration,
    required this.specifiers,
    this.source,
    this.attributes,
    this.exportKind,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Export default declaration.
final class ExportDefaultDeclaration extends Declaration {
  final Object
  declaration; // TSDeclareFunction | FunctionDeclaration | ClassDeclaration | Expression
  final String? exportKind; // value
  const ExportDefaultDeclaration({
    required this.declaration,
    this.exportKind,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Export all declaration.
/// export *
final class ExportStartDeclartion extends Declaration {
  final StringLiteral source;
  final List<ImportAttribute>? attributes;
  final String? exportKind; // type | value
  const ExportStartDeclartion({
    required this.source,
    this.attributes,
    this.exportKind,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Backward-compatible alias for export-all declaration spelling used elsewhere.
// Provide a concrete ExportAllDeclartion class expected by parser and printer
final class ExportAllDeclartion extends Declaration {
  final StringLiteral source;
  final Identifier? exported;
  final List<ImportAttribute>? attributes;
  final String? exportKind; // type | value
  const ExportAllDeclartion({
    required this.source,
    this.exported,
    this.attributes,
    this.exportKind,
    super.loc,
    super.extra,
    super.text,
    super.comments,
  });
}

/// Import/Export attributes.
final class ImportAttribute extends BaseNode {
  final Object key; // Identifier | StringLiteral
  final StringLiteral value;
  const ImportAttribute({
    required this.key,
    required this.value,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Export specifier.
final class ExportSpecifier extends BaseNode {
  final Identifier local;
  final Object exported; // Identifier | StringLiteral
  final String? exportKind; // type | value
  const ExportSpecifier({
    required this.local,
    required this.exported,
    this.exportKind,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Export default specifier.
final class ExportDefaultSpecifier extends BaseNode {
  final Identifier exported;
  const ExportDefaultSpecifier({
    required this.exported,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Export namespace specifier.
final class ExportNamespaceSpecifier extends BaseNode {
  final Identifier exported;
  const ExportNamespaceSpecifier({
    required this.exported,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Import default specifier.
final class ImportDefaultSpecifier extends BaseNode {
  final Identifier local;
  const ImportDefaultSpecifier({required this.local, super.loc, super.extra});
}

/// Import namespace specifier.
final class ImportNamespaceSpecifier extends BaseNode {
  final Identifier local;
  const ImportNamespaceSpecifier({required this.local, super.loc, super.extra});
}

/// Import specifier.
final class ImportSpecifier extends BaseNode {
  final Identifier local;
  final Object imported; // Identifier | StringLiteral
  final String? importKind; // type | typeof | value
  const ImportSpecifier({
    required this.local,
    required this.imported,
    this.importKind,
    super.loc,
    super.extra,
  });
}

/// TS: type annotation wrapper.
final class TSTypeAnnotation extends BaseNode {
  final TSType typeAnnotation;
  const TSTypeAnnotation({
    required this.typeAnnotation,
    super.loc,
    super.extra,
  });
}

/// TS: type parameter instantiation.
final class TSTypeParameterInstantiation extends BaseNode {
  final List<TSType> params;
  const TSTypeParameterInstantiation({
    required this.params,
    super.loc,
    super.extra,
  });
}

/// TS: type parameter declaration.
final class TSTypeParameterDeclaration extends BaseNode {
  final List<TSTypeParameter> params;
  const TSTypeParameterDeclaration({
    required this.params,
    super.loc,
    super.extra,
  });
}

/// TS: type parameter.
final class TSTypeParameter extends BaseNode {
  final TSType? constraint;
  final TSType? defaultType;
  final String name;
  final bool? isConst;
  final bool? isIn;
  final bool? isOut;
  const TSTypeParameter({
    this.constraint,
    this.defaultType,
    required this.name,
    this.isConst,
    this.isIn,
    this.isOut,
    super.loc,
    super.extra,
  });
}

/// TS: type union root.
sealed class TSType extends BaseNode {
  const TSType({super.loc, super.extra});
}

/// TS: any keyword.
final class TSAnyKeyword extends TSType {
  const TSAnyKeyword({super.loc, super.extra});
}

final class TSTypeReference extends TSType {
  final String name;
  final TSTypeParameterInstantiation? typeParameters;
  const TSTypeReference({
    required this.name,
    this.typeParameters,
    super.loc,
    super.extra,
  });
}

final class TSLiteralType extends TSType {
  final String text;
  const TSLiteralType({required this.text, super.loc, super.extra});
}

final class TSUnionType extends TSType {
  final List<TSType> types;
  const TSUnionType({required this.types, super.loc, super.extra});
}

final class TSArrayType extends TSType {
  final TSType elementType;
  final bool readonly;
  const TSArrayType({
    required this.elementType,
    this.readonly = false,
    super.loc,
    super.extra,
  });
}

final class TSTupleType extends TSType {
  final List<TSType> elementTypes;
  const TSTupleType({required this.elementTypes, super.loc, super.extra});
}

final class TSIndexedAccessType extends TSType {
  final TSType objectType;
  final TSType indexType;
  const TSIndexedAccessType({
    required this.objectType,
    required this.indexType,
    super.loc,
    super.extra,
  });
}

final class TSParenthesizedType extends TSType {
  final TSType type;
  const TSParenthesizedType({required this.type, super.loc, super.extra});
}

final class TSStringKeyword extends TSType {
  const TSStringKeyword({super.loc, super.extra});
}

final class TSNumberKeyword extends TSType {
  const TSNumberKeyword({super.loc, super.extra});
}

final class TSBooleanKeyword extends TSType {
  const TSBooleanKeyword({super.loc, super.extra});
}

final class TSNullKeyword extends TSType {
  const TSNullKeyword({super.loc, super.extra});
}

final class TSUndefinedKeyword extends TSType {
  const TSUndefinedKeyword({super.loc, super.extra});
}

final class TSObjectType extends TSType {
  final List<TSPropertySignature> members;
  const TSObjectType({this.members = const [], super.loc, super.extra});
}

final class TSIndexSignature extends TSType {
  final String keyName;
  final TSType keyType;
  final TSType valueType;
  const TSIndexSignature({
    required this.keyName,
    required this.keyType,
    required this.valueType,
    super.loc,
    super.extra,
  });
}

final class TSMappedType extends TSType {
  final String paramName;
  final TSType sourceType;
  final TSType valueType;
  final bool readonly;
  final bool optional;
  const TSMappedType({
    required this.paramName,
    required this.sourceType,
    required this.valueType,
    this.readonly = false,
    this.optional = false,
    super.loc,
    super.extra,
  });
}

final class TSKeyofType extends TSType {
  final TSType argument;
  const TSKeyofType({required this.argument, super.loc, super.extra});
}

final class TSInferType extends TSType {
  final String name;
  final TSType? constraint;
  const TSInferType({
    required this.name,
    this.constraint,
    super.loc,
    super.extra,
  });
}

final class TSConditionalType extends TSType {
  final TSType checkType;
  final TSType extendsType;
  final TSType trueType;
  final TSType falseType;
  const TSConditionalType({
    required this.checkType,
    required this.extendsType,
    required this.trueType,
    required this.falseType,
    super.loc,
    super.extra,
  });
}

final class TSPropertySignature extends BaseNode {
  final Object
  key; // Identifier | StringLiteral | NumericLiteral | BigIntLiteral | Expression
  final bool optional;
  final TSTypeAnnotation? typeAnnotation;
  const TSPropertySignature({
    required this.key,
    required this.optional,
    this.typeAnnotation,
    super.loc,
    super.extra,
  });
}

final class TSInterfaceBody extends BaseNode {
  final List<TSPropertySignature> body;
  const TSInterfaceBody({required this.body, super.loc, super.extra});
}

final class TSTypeAliasDeclaration extends Declaration {
  final Identifier id;
  final List<TSPropertySignature> members;
  final TSTypeParameterDeclaration? typeParameters;
  final bool? declare;
  const TSTypeAliasDeclaration({
    required this.id,
    required this.members,
    this.typeParameters,
    this.declare,
    super.loc,
    super.extra,
  });
}

final class TSInterfaceDeclaration extends Declaration {
  final Identifier id;
  final TSInterfaceBody body;
  final TSTypeParameterDeclaration? typeParameters;
  final List<Object>? extendsItems; // TSInterfaceHeritage[]
  final bool? declare;
  const TSInterfaceDeclaration({
    required this.id,
    required this.body,
    this.typeParameters,
    this.extendsItems,
    this.declare,
    super.loc,
    super.extra,
  });
}

/// TypeScript declare function matching ast.ts `TSDeclareFunction`.
/// id may be null; params are function parameters; optional return/type parameters.
final class TSDeclareFunction extends Declaration {
  final Identifier? id;
  final List<Object> params; // FunctionParameter
  final TSTypeAnnotation? returnType;
  final TSTypeParameterDeclaration? typeParameters;
  const TSDeclareFunction({
    this.id,
    required this.params,
    this.returnType,
    this.typeParameters,
    super.loc,
    super.extra,
  });
}

/// TypeScript enum member matching ast.ts `TSEnumMember`.
/// id: Identifier of the member; initializer: optional constant expression.
final class TSEnumMember extends BaseNode {
  final Identifier id;
  final Expression? initializer;
  const TSEnumMember({
    required this.id,
    this.initializer,
    super.loc,
    super.extra,
  });
}

/// TypeScript enum declaration matching ast.ts `TSEnumDeclaration`.
/// id: Identifier of the enum; members: list of `TSEnumMember` entries.
final class TSEnumDeclaration extends Declaration {
  final Identifier id;
  final List<TSEnumMember> members;
  final bool? declare;
  const TSEnumDeclaration({
    required this.id,
    required this.members,
    this.declare,
    super.loc,
    super.extra,
  });
}

/// TypeScript module (namespace) declaration matching ast.ts `TSModuleDeclaration`.
/// id: Identifier (namespace name); body: `TSModuleBlock` containing statements.
final class TSModuleDeclaration extends Declaration {
  final Identifier id;
  final TSModuleBlock body;
  final bool? declare;
  const TSModuleDeclaration({
    required this.id,
    required this.body,
    this.declare,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// Placeholder for unimplemented nodes during incremental adoption.
final class UnknownNode extends BaseNode {
  final String type;
  final Map<String, Object?> raw;
  UnknownNode(Map<String, dynamic> m)
    : type = m['type'] as String,
      raw = m.cast<String, Object?>();
}

/// Argument placeholder node.
final class ArgumentPlaceholder extends BaseNode {
  const ArgumentPlaceholder({super.loc, super.extra});
}

/// Super expression.
final class Super extends BaseNode {
  const Super({super.loc, super.extra, super.comments});
}

/// Private name.
final class PrivateName extends BaseNode {
  final Identifier id;
  const PrivateName({required this.id, super.loc, super.extra});
}

/// V8 intrinsic identifier.
final class V8IntrinsicIdentifier extends BaseNode {
  final String name;
  const V8IntrinsicIdentifier({
    required this.name,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// TS cast: as expression.
final class TSAsExpression extends Expression {
  final Expression expression;
  final TSType typeAnnotation;
  const TSAsExpression({
    required this.expression,
    required this.typeAnnotation,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// TS satisfies expression.
final class TSSatisfiesExpression extends Expression {
  final Expression expression;
  final TSType typeAnnotation;
  const TSSatisfiesExpression({
    required this.expression,
    required this.typeAnnotation,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// TS type assertion.
final class TSTypeAssertion extends Expression {
  final TSType typeAnnotation;
  final Expression expression;
  const TSTypeAssertion({
    required this.typeAnnotation,
    required this.expression,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// TS non-null expression.
final class TSNonNullExpression extends Expression {
  final Expression expression;
  const TSNonNullExpression({
    required this.expression,
    super.loc,
    super.extra,
    super.comments,
  });
}

/// NOTE: Additional statements, declarations (FunctionDeclaration, ClassDeclaration,
/// VariableDeclaration, VariableDeclarator, etc.), JSX nodes, and the full TS type
/// family are planned to reach parity with `ast.ts`. The factory and helpers already
/// support union dispatch; unknown nodes are temporarily represented by `UnknownNode`.

/// Helper: list literal expression for codegen utilities.
final class ListLiteral extends Expression {
  final List<Expression> elements;
  const ListLiteral({
    required this.elements,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

/// Helper: set/map literal for codegen utilities with key-value entries.
final class SetOrMapLiteral extends Expression {
  final List<MapLiteralEntry> elements;
  const SetOrMapLiteral({
    required this.elements,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

/// Helper: map literal entry used by SetOrMapLiteral.
final class MapLiteralEntry extends BaseNode {
  final String keyText;
  final Expression value;
  const MapLiteralEntry({
    required this.keyText,
    required this.value,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

/// Helper: argument list wrapper used by FunctionCallExpression.
final class ArgumentList extends BaseNode {
  final List<Expression> arguments;
  const ArgumentList({
    required this.arguments,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

/// Helper: function call expression enriched with type arguments parsing.
/// Function call expression with parsed type argument text and props.
final class FunctionCallExpression extends Expression {
  final Identifier methodName;
  final ArgumentList argumentList;
  final String? typeArgumentText;
  final List<PropSignature> typeArgumentProps;
  const FunctionCallExpression({
    required this.methodName,
    required this.argumentList,
    this.typeArgumentText,
    this.typeArgumentProps = const [],
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

/// Binding pattern base used by macro conversion utilities.
sealed class BindingPattern extends BaseNode {
  final String? typeAnnotationText;
  const BindingPattern({
    this.typeAnnotationText,
    super.loc,
    super.extra,
    super.text,
    super.comments,
  });
}

/// Array binding element inside an array pattern.
final class ArrayBindingElement extends BaseNode {
  final Identifier? target;
  final Expression? defaultValue;
  final bool isRest;
  final int? index;
  final BindingPattern? nested;
  final int? identStartByte;
  final int? identEndByte;
  const ArrayBindingElement({
    this.target,
    this.defaultValue,
    this.isRest = false,
    this.index,
    this.nested,
    this.identStartByte,
    this.identEndByte,
    super.loc,
    super.extra,
    super.comments,
    String? text,
  }) : super(text: text ?? '');
}

/// Array binding pattern for destructuring.
/// Array binding pattern used for destructuring assignment.
final class ArrayBindingPattern extends BindingPattern {
  final List<ArrayBindingElement> elements;
  final List<String?> typeIndexMap;
  const ArrayBindingPattern({
    required this.elements,
    this.typeIndexMap = const [],
    super.typeAnnotationText,
    super.loc,
    super.extra,
    super.text,
    super.comments,
  });
}

/// Object binding property entry.
final class ObjectBindingProperty extends BaseNode {
  final String key;
  final Identifier? alias;
  final Expression? defaultValue;
  final BindingPattern? nested;
  final int? keyStartByte;
  final int? keyEndByte;
  final int? aliasStartByte;
  final int? aliasEndByte;
  final Identifier? requiredKeyIdent;
  const ObjectBindingProperty({
    required this.key,
    this.alias,
    this.defaultValue,
    this.nested,
    this.keyStartByte,
    this.keyEndByte,
    this.aliasStartByte,
    this.aliasEndByte,
    this.requiredKeyIdent,
    super.loc,
    super.extra,
    String? text,
  }) : super(text: text ?? '');
}

/// Object binding pattern for destructuring.
/// Object binding pattern used for destructuring assignment.
final class ObjectBindingPattern extends BindingPattern {
  final List<ObjectBindingProperty> properties;
  final Map<String, String?> typeKeyMap;
  const ObjectBindingPattern({
    required this.properties,
    this.typeKeyMap = const {},
    super.typeAnnotationText,
    super.loc,
    super.extra,
    super.text,
    super.comments,
  });
}

/// Helper: invocation of inline function text used by macro analysis.
final class FunctionExpressionInvocation extends Expression {
  final String functionText;
  final ArgumentList argumentList;
  const FunctionExpressionInvocation({
    required this.functionText,
    required this.argumentList,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

/// Compatibility: number literal to align with existing macro code.
final class NumberLiteral extends Expression {
  final num value;
  const NumberLiteral({
    required this.value,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

/// Variable declaration wrapper for simple statements.
class VariableDeclaration extends Expression {
  final Identifier name;
  final Expression? init;
  final BindingPattern? pattern;
  final String? declKind; // 'const' | 'let' | 'var'
  const VariableDeclaration(
    this.init, {
    required this.name,
    this.pattern,
    this.declKind,
    String? text,
    super.loc,
    super.extra,
    super.comments,
  }) : super(text: text ?? '');
}

/// Compilation unit aggregating statements and import/export declarations.
final class CompilationUnit extends BaseNode {
  final List<ExpressionStatement> statements;
  final List<Declaration> imported;
  final List<Declaration> exported;
  const CompilationUnit({
    required this.statements,
    this.imported = const [],
    this.exported = const [],
    super.text,
    super.loc,
    super.extra,
    super.comments,
  });
}

final class TSIntersectionType extends TSType {
  final List<TSType> types;
  const TSIntersectionType({required this.types, super.loc, super.extra});
}
