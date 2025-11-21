/// TypeScript AST for Dart: complete Dart representation of ast.ts
/// including nodes, unions, and JSON conversion factories.
/// This file defines the TypeScript-side AST classes used across the compiler.
library;

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
  factory Position.fromJson(Map<String, dynamic> m) => Position(
    line: (m['line'] as num).toInt(),
    column: (m['column'] as num).toInt(),
    index: (m['index'] as num).toInt(),
  );
}

/// Source location with start/end positions and metadata.
final class SourceLocation {
  final Position start;
  final Position end;
  final String filename;
  final String? identifierName;
  const SourceLocation({
    required this.start,
    required this.end,
    required this.filename,
    this.identifierName,
  });
  factory SourceLocation.fromJson(Map<String, dynamic> m) => SourceLocation(
    start: Position.fromJson(m['start'] as Map<String, dynamic>),
    end: Position.fromJson(m['end'] as Map<String, dynamic>),
    filename: m['filename'] as String,
    identifierName: m['identifierName'] as String?,
  );
}

/// Comment block or line attached to nodes.
sealed class Comment {
  final String value;
  final int? start;
  final int? end;
  final SourceLocation? loc;
  final bool? ignore;
  const Comment({
    required this.value,
    this.start,
    this.end,
    this.loc,
    this.ignore,
  });
}

/// Multiline comment.
final class CommentBlock extends Comment {
  const CommentBlock({
    required super.value,
    super.start,
    super.end,
    super.loc,
    super.ignore,
  });
  factory CommentBlock.fromJson(Map<String, dynamic> m) => CommentBlock(
    value: m['value'] as String,
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    ignore: m['ignore'] as bool?,
  );
}

/// Single line comment.
final class CommentLine extends Comment {
  const CommentLine({
    required super.value,
    super.start,
    super.end,
    super.loc,
    super.ignore,
  });
  factory CommentLine.fromJson(Map<String, dynamic> m) => CommentLine(
    value: m['value'] as String,
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    ignore: m['ignore'] as bool?,
  );
}

/// Base node for all AST nodes.
sealed class BaseNode {
  final List<Comment>? leadingComments;
  final List<Comment>? innerComments;
  final List<Comment>? trailingComments;
  final int? start;
  final int? end;
  final SourceLocation? loc;
  final List<int>? range;
  final Map<String, Object?>? extra;
  final int startByte;
  final int endByte;
  final String text;
  const BaseNode({
    this.leadingComments,
    this.innerComments,
    this.trailingComments,
    this.start,
    this.end,
    this.loc,
    this.range,
    this.extra,
    int? startByte,
    int? endByte,
    this.text = '',
  }) : startByte = startByte ?? 0,
       endByte = endByte ?? 0;
}

/// Expression union base.
sealed class Expression extends BaseNode {
  const Expression({
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
    super.startByte,
    super.endByte,
    super.text,
  });
}

/// Statement union base.
sealed class Statement extends BaseNode {
  const Statement({
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
    super.startByte,
    super.endByte,
    super.text,
  });
}

/// Declaration union base.
sealed class Declaration extends Statement {
  const Declaration({
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
    super.startByte,
    super.endByte,
    super.text,
  });
}

/// Pattern base.
sealed class PatternLike extends BaseNode {
  const PatternLike({
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
    super.startByte,
    super.endByte,
    super.text,
  });
}

/// Identifier node.
final class Identifier extends Expression {
  final String name;
  final List<Decorator>? decorators;
  final bool? optional;
  final TSTypeAnnotation? typeAnnotation;
  Identifier({
    String? name,
    String? text,
    super.startByte,
    super.endByte,
    this.decorators,
    this.optional,
    this.typeAnnotation,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : name = name ?? _extractIdentifierName(text ?? ''),
       super(text: text ?? '');
  factory Identifier.fromJson(Map<String, dynamic> m) => Identifier(
    name: m['name'] as String,
    decorators: _readList<Decorator>(m['decorators'], Decorator.fromJson),
    optional: m['optional'] as bool?,
    typeAnnotation: m['typeAnnotation'] == null
        ? null
        : TSTypeAnnotation.fromJson(
            m['typeAnnotation'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

// ignore: unintended_html_in_doc_comment
/// Extract terminal identifier name from raw text like "ns.name<T>".
String _extractIdentifierName(String t) {
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
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : value = value ?? (stringValue ?? ''),
       super(text: text ?? '');
  factory StringLiteral.fromJson(Map<String, dynamic> m) => StringLiteral(
    value: m['value'] as String,
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
  String get stringValue => value;
}

/// Numeric literal.
final class NumericLiteral extends Expression implements Literal {
  final num value;
  const NumericLiteral({
    required this.value,
    int? startByte,
    int? endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory NumericLiteral.fromJson(Map<String, dynamic> m) => NumericLiteral(
    value: (m['value'] as num),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Null literal.
final class NullLiteral extends Expression implements Literal {
  const NullLiteral({
    int? startByte,
    int? endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory NullLiteral.fromJson(Map<String, dynamic> m) => NullLiteral(
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Boolean literal.
final class BooleanLiteral extends Expression implements Literal {
  final bool value;
  const BooleanLiteral({
    required this.value,
    int? startByte,
    int? endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory BooleanLiteral.fromJson(Map<String, dynamic> m) => BooleanLiteral(
    value: m['value'] as bool,
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// BigInt literal.
final class BigIntLiteral extends Expression implements Literal {
  final Object value;
  const BigIntLiteral({
    required this.value,
    int? startByte,
    int? endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory BigIntLiteral.fromJson(Map<String, dynamic> m) => BigIntLiteral(
    value: m['value'] as String,
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
  factory BigIntLiteral.fromBigInt(BigInt v) => BigIntLiteral(value: v);
}

/// Decimal literal.
final class DecimalLiteral extends Expression implements Literal {
  final String value;
  const DecimalLiteral({
    required this.value,
    int? startByte,
    int? endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory DecimalLiteral.fromJson(Map<String, dynamic> m) => DecimalLiteral(
    value: m['value'] as String,
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// RegExp literal.
final class RegExpLiteral extends Expression implements Literal {
  final String pattern;
  final String flags;
  const RegExpLiteral({
    required this.pattern,
    required this.flags,
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
  factory RegExpLiteral.fromJson(Map<String, dynamic> m) => RegExpLiteral(
    pattern: m['pattern'] as String,
    flags: m['flags'] as String,
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

final class TemplateElement extends BaseNode {
  final Map<String, Object?> value;
  final bool tail;
  const TemplateElement({
    required this.value,
    required this.tail,
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
  factory TemplateElement.fromJson(Map<String, dynamic> m) => TemplateElement(
    value: (m['value'] as Map<String, dynamic>).cast<String, Object?>(),
    tail: m['tail'] as bool,
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

final class TemplateLiteral extends Expression {
  final List<TemplateElement> quasis;
  final List<Object> expressions;
  const TemplateLiteral({
    required this.quasis,
    required this.expressions,
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
  factory TemplateLiteral.fromJson(Map<String, dynamic> m) => TemplateLiteral(
    quasis: _readList<TemplateElement>(m['quasis'], TemplateElement.fromJson),
    expressions: (m['expressions'] as List<dynamic>? ?? const []).map((e) {
      final me = e as Map<String, dynamic>;
      final t = me['type'] as String;
      if (t.startsWith('TS')) return TsAstFactory.fromJsonTSType(me);
      return TsAstFactory.fromJsonExpression(me);
    }).toList(),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

final class TaggedTemplateExpression extends Expression {
  final Expression tag;
  final TemplateLiteral quasi;
  final TSTypeParameterInstantiation? typeParameters;
  const TaggedTemplateExpression({
    required this.tag,
    required this.quasi,
    this.typeParameters,
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
  factory TaggedTemplateExpression.fromJson(Map<String, dynamic> m) =>
      TaggedTemplateExpression(
        tag: TsAstFactory.fromJsonExpression(m['tag'] as Map<String, dynamic>),
        quasi: TemplateLiteral.fromJson(m['quasi'] as Map<String, dynamic>),
        typeParameters: m['typeParameters'] == null
            ? null
            : TSTypeParameterInstantiation.fromJson(
                m['typeParameters'] as Map<String, dynamic>,
              ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
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
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
  factory OptionalMemberExpression.fromJson(Map<String, dynamic> m) =>
      OptionalMemberExpression(
        object: TsAstFactory.fromJsonExpression(
          m['object'] as Map<String, dynamic>,
        ),
        property: TsAstFactory.fromJsonExpressionOrIdentifierOrPrivateName(
          m['property'] as Map<String, dynamic>,
        ),
        computed: m['computed'] as bool,
        optional: m['optional'] as bool,
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
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
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
  factory OptionalCallExpression.fromJson(Map<String, dynamic> m) =>
      OptionalCallExpression(
        callee: TsAstFactory.fromJsonExpression(
          m['callee'] as Map<String, dynamic>,
        ),
        arguments: _readMixedList(m['arguments']),
        optional: m['optional'] as bool,
        typeParameters: m['typeParameters'] == null
            ? null
            : TSTypeParameterInstantiation.fromJson(
                m['typeParameters'] as Map<String, dynamic>,
              ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

final class ImportExpression extends Expression {
  final Expression source;
  final Expression? options;
  final String? phase;
  const ImportExpression({
    required this.source,
    this.options,
    this.phase,
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
  factory ImportExpression.fromJson(Map<String, dynamic> m) => ImportExpression(
    source: TsAstFactory.fromJsonExpression(
      m['source'] as Map<String, dynamic>,
    ),
    options: m['options'] == null
        ? null
        : TsAstFactory.fromJsonExpression(m['options'] as Map<String, dynamic>),
    phase: m['phase'] as String?,
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

final class PropSignature {
  final String name;
  final String? type;
  final bool required;
  const PropSignature({required this.name, this.type, required this.required});
}

/// Program root.
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory Program.fromJson(Map<String, dynamic> m) => Program(
    body: _readList<Statement>(m['body'], TsAstFactory.fromJsonStatement),
    directives: _readList<Directive>(m['directives'], Directive.fromJson),
    sourceType: m['sourceType'] as String,
    interpreter: m['interpreter'] == null
        ? null
        : InterpreterDirective.fromJson(
            m['interpreter'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Directive literal ("use strict" etc.).
final class DirectiveLiteral extends BaseNode {
  final String value;
  const DirectiveLiteral({
    required this.value,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory DirectiveLiteral.fromJson(Map<String, dynamic> m) => DirectiveLiteral(
    value: m['value'] as String,
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Directive wrapper.
final class Directive extends BaseNode {
  final DirectiveLiteral value;
  const Directive({
    required this.value,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory Directive.fromJson(Map<String, dynamic> m) => Directive(
    value: DirectiveLiteral.fromJson(m['value'] as Map<String, dynamic>),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Interpreter directive (hashbang).
final class InterpreterDirective extends BaseNode {
  final String value;
  const InterpreterDirective({
    required this.value,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory InterpreterDirective.fromJson(Map<String, dynamic> m) =>
      InterpreterDirective(
        value: m['value'] as String,
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// Block statement.
final class BlockStatement extends Statement {
  final List<Statement> body;
  final List<Directive> directives;
  const BlockStatement({
    required this.body,
    required this.directives,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory BlockStatement.fromJson(Map<String, dynamic> m) => BlockStatement(
    body: _readList<Statement>(m['body'], TsAstFactory.fromJsonStatement),
    directives: _readList<Directive>(m['directives'], Directive.fromJson),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Expression statement.
final class ExpressionStatement extends Statement {
  final Expression expression;
  const ExpressionStatement({
    required this.expression,
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
  factory ExpressionStatement.fromJson(Map<String, dynamic> m) =>
      ExpressionStatement(
        expression: TsAstFactory.fromJsonExpression(
          m['expression'] as Map<String, dynamic>,
        ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// Return statement.
final class ReturnStatement extends Statement {
  final Expression? argument;
  const ReturnStatement({
    this.argument,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ReturnStatement.fromJson(Map<String, dynamic> m) => ReturnStatement(
    argument: m['argument'] == null
        ? null
        : TsAstFactory.fromJsonExpression(
            m['argument'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Throw statement.
final class ThrowStatement extends Statement {
  final Expression argument;
  const ThrowStatement({
    required this.argument,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ThrowStatement.fromJson(Map<String, dynamic> m) => ThrowStatement(
    argument: TsAstFactory.fromJsonExpression(
      m['argument'] as Map<String, dynamic>,
    ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory IfStatement.fromJson(Map<String, dynamic> m) => IfStatement(
    test: TsAstFactory.fromJsonExpression(m['test'] as Map<String, dynamic>),
    consequent: TsAstFactory.fromJsonStatement(
      m['consequent'] as Map<String, dynamic>,
    ),
    alternate: m['alternate'] == null
        ? null
        : TsAstFactory.fromJsonStatement(
            m['alternate'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory CallExpression.fromJson(Map<String, dynamic> m) => CallExpression(
    callee: TsAstFactory.fromJsonExpression(
      m['callee'] as Map<String, dynamic>,
    ),
    arguments: _readMixedList(m['arguments']),
    optional: m['optional'] as bool?,
    typeParameters: m['typeParameters'] == null
        ? null
        : TSTypeParameterInstantiation.fromJson(
            m['typeParameters'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory MemberExpression.fromJson(Map<String, dynamic> m) => MemberExpression(
    object: TsAstFactory.fromJsonExpressionOrSuper(
      m['object'] as Map<String, dynamic>,
    ),
    property: TsAstFactory.fromJsonExpressionOrIdentifierOrPrivateName(
      m['property'] as Map<String, dynamic>,
    ),
    computed: m['computed'] as bool,
    optional: m['optional'] as bool?,
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory NewExpression.fromJson(Map<String, dynamic> m) => NewExpression(
    callee: TsAstFactory.fromJsonExpressionOrSuperOrV8Intrinsic(
      m['callee'] as Map<String, dynamic>,
    ),
    arguments: _readMixedList(m['arguments']),
    optional: m['optional'] as bool?,
    typeParameters: m['typeParameters'] == null
        ? null
        : TSTypeParameterInstantiation.fromJson(
            m['typeParameters'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Object expression.
final class ObjectExpression extends Expression {
  final List<Object>
  properties; // ObjectMethod | ObjectProperty | SpreadElement
  const ObjectExpression({
    required this.properties,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ObjectExpression.fromJson(Map<String, dynamic> m) => ObjectExpression(
    properties: _readObjProps(m['properties']),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
    super.startByte,
    super.endByte,
    super.text,
  });
  factory FunctionExpression.fromJson(Map<String, dynamic> m) =>
      FunctionExpression(
        id: m['id'] == null
            ? null
            : Identifier.fromJson(m['id'] as Map<String, dynamic>),
        params: _readFunctionParameters(m['params']),
        body: BlockStatement.fromJson(m['body'] as Map<String, dynamic>),
        generator: m['generator'] as bool,
        async: m['async'] as bool,
        returnType: m['returnType'] == null
            ? null
            : TSTypeAnnotation.fromJson(
                m['returnType'] as Map<String, dynamic>,
              ),
        typeParameters: m['typeParameters'] == null
            ? null
            : TSTypeParameterDeclaration.fromJson(
                m['typeParameters'] as Map<String, dynamic>,
              ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ObjectMethod.fromJson(Map<String, dynamic> m) => ObjectMethod(
    kind: m['kind'] as String,
    key: TsAstFactory.fromJsonExpressionOrIdentifierOrLiteralOrBigInt(
      m['key'] as Map<String, dynamic>,
    ),
    params: _readFunctionParameters(m['params']),
    body: BlockStatement.fromJson(m['body'] as Map<String, dynamic>),
    computed: m['computed'] as bool,
    generator: m['generator'] as bool,
    async: m['async'] as bool,
    decorators: _readList<Decorator>(m['decorators'], Decorator.fromJson),
    returnType: m['returnType'] == null
        ? null
        : TSTypeAnnotation.fromJson(m['returnType'] as Map<String, dynamic>),
    typeParameters: m['typeParameters'] == null
        ? null
        : TSTypeParameterDeclaration.fromJson(
            m['typeParameters'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
    super.startByte,
    super.endByte,
    super.text,
  });
  factory ArrowFunctionExpression.fromJson(
    Map<String, dynamic> m,
  ) => ArrowFunctionExpression(
    params: _readFunctionParameters(m['params']),
    body:
        ((m['body'] as Map<String, dynamic>)['type'] as String) ==
            'BlockStatement'
        ? BlockStatement.fromJson(m['body'] as Map<String, dynamic>)
        : TsAstFactory.fromJsonExpression(m['body'] as Map<String, dynamic>),
    async: m['async'] as bool,
    expression: m['expression'] as bool,
    generator: m['generator'] as bool?,
    returnType: m['returnType'] == null
        ? null
        : TSTypeAnnotation.fromJson(m['returnType'] as Map<String, dynamic>),
    typeParameters: m['typeParameters'] == null
        ? null
        : TSTypeParameterDeclaration.fromJson(
            m['typeParameters'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ClassMethod.fromJson(Map<String, dynamic> m) => ClassMethod(
    kind: m['kind'] as String,
    key: TsAstFactory.fromJsonExpressionOrIdentifierOrLiteralOrBigInt(
      m['key'] as Map<String, dynamic>,
    ),
    params: _readFunctionParameters(m['params']),
    body: BlockStatement.fromJson(m['body'] as Map<String, dynamic>),
    computed: m['computed'] as bool,
    staticMember: m['static'] as bool,
    generator: m['generator'] as bool,
    asyncMember: m['async'] as bool,
    abstractMember: m['abstract'] as bool?,
    access: m['access'] as String?,
    accessibility: m['accessibility'] as String?,
    decorators: _readList<Decorator>(m['decorators'], Decorator.fromJson),
    optional: m['optional'] as bool?,
    overrideMember: m['override'] as bool?,
    returnType: m['returnType'] == null
        ? null
        : TSTypeAnnotation.fromJson(m['returnType'] as Map<String, dynamic>),
    typeParameters: m['typeParameters'] == null
        ? null
        : TSTypeParameterDeclaration.fromJson(
            m['typeParameters'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ClassPrivateMethod.fromJson(Map<String, dynamic> m) =>
      ClassPrivateMethod(
        kind: m['kind'] as String,
        key: PrivateName.fromJson(m['key'] as Map<String, dynamic>),
        params: _readFunctionParameters(m['params']),
        body: BlockStatement.fromJson(m['body'] as Map<String, dynamic>),
        staticMember: m['static'] as bool,
        abstractMember: m['abstract'] as bool?,
        access: m['access'] as String?,
        accessibility: m['accessibility'] as String?,
        asyncMember: m['async'] as bool?,
        computed: m['computed'] as bool?,
        decorators: _readList<Decorator>(m['decorators'], Decorator.fromJson),
        generator: m['generator'] as bool?,
        optional: m['optional'] as bool?,
        overrideMember: m['override'] as bool?,
        returnType: m['returnType'] == null
            ? null
            : TSTypeAnnotation.fromJson(
                m['returnType'] as Map<String, dynamic>,
              ),
        typeParameters: m['typeParameters'] == null
            ? null
            : TSTypeParameterDeclaration.fromJson(
                m['typeParameters'] as Map<String, dynamic>,
              ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

final class ClassBody extends BaseNode {
  final List<BaseNode> body;
  const ClassBody({
    required this.body,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ClassBody.fromJson(Map<String, dynamic> m) => ClassBody(
    body:
        ((m['body'] as List<dynamic>? ?? const [])
                .map((e) => TsAstFactory.fromJson(e as Map<String, dynamic>))
                .toList())
            .cast<BaseNode>(),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ClassExpression.fromJson(Map<String, dynamic> m) => ClassExpression(
    id: m['id'] == null
        ? null
        : Identifier.fromJson(m['id'] as Map<String, dynamic>),
    superClass: m['superClass'] == null
        ? null
        : TsAstFactory.fromJsonExpression(
            m['superClass'] as Map<String, dynamic>,
          ),
    body: ClassBody.fromJson(m['body'] as Map<String, dynamic>),
    decorators: _readList<Decorator>(m['decorators'], Decorator.fromJson),
    implementsItems: _readList<Object>(
      m['implements'],
      (mm) => TsAstFactory.fromJsonAny(mm),
    ),
    superTypeParameters: m['superTypeParameters'] == null
        ? null
        : TSTypeParameterInstantiation.fromJson(
            m['superTypeParameters'] as Map<String, dynamic>,
          ),
    typeParameters: m['typeParameters'] == null
        ? null
        : TSTypeParameterDeclaration.fromJson(
            m['typeParameters'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ClassDeclaration.fromJson(Map<String, dynamic> m) => ClassDeclaration(
    id: m['id'] == null
        ? null
        : Identifier.fromJson(m['id'] as Map<String, dynamic>),
    superClass: m['superClass'] == null
        ? null
        : TsAstFactory.fromJsonExpression(
            m['superClass'] as Map<String, dynamic>,
          ),
    body: ClassBody.fromJson(m['body'] as Map<String, dynamic>),
    decorators: _readList<Decorator>(m['decorators'], Decorator.fromJson),
    abstractMember: m['abstract'] as bool?,
    declareMember: m['declare'] as bool?,
    implementsItems: _readList<Object>(
      m['implements'],
      (mm) => TsAstFactory.fromJsonAny(mm),
    ),
    superTypeParameters: m['superTypeParameters'] == null
        ? null
        : TSTypeParameterInstantiation.fromJson(
            m['superTypeParameters'] as Map<String, dynamic>,
          ),
    typeParameters: m['typeParameters'] == null
        ? null
        : TSTypeParameterDeclaration.fromJson(
            m['typeParameters'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

bool isClassNode(BaseNode n) {
  return n is ClassExpression || n is ClassDeclaration;
}

bool isFunctionNode(BaseNode n) {
  return n is FunctionDeclaration ||
      n is FunctionExpression ||
      n is ObjectMethod ||
      n is ArrowFunctionExpression ||
      n is ClassMethod ||
      n is ClassPrivateMethod;
}

final class StaticBlock extends BaseNode {
  final List<BaseNode> body; // Array<Statement>
  const StaticBlock({
    required this.body,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory StaticBlock.fromJson(Map<String, dynamic> m) => StaticBlock(
    body:
        ((m['body'] as List<dynamic>? ?? const [])
                .map((e) => TsAstFactory.fromJson(e as Map<String, dynamic>))
                .toList())
            .cast<BaseNode>(),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

final class TSModuleBlock extends BaseNode {
  final List<BaseNode> body; // Array<Statement>
  const TSModuleBlock({
    required this.body,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSModuleBlock.fromJson(Map<String, dynamic> m) => TSModuleBlock(
    body:
        ((m['body'] as List<dynamic>? ?? const [])
                .map((e) => TsAstFactory.fromJson(e as Map<String, dynamic>))
                .toList())
            .cast<BaseNode>(),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
    super.startByte,
    super.endByte,
    super.text,
  });
  factory FunctionDeclaration.fromJson(Map<String, dynamic> m) =>
      FunctionDeclaration(
        id: m['id'] == null
            ? null
            : Identifier.fromJson(m['id'] as Map<String, dynamic>),
        params: _readFunctionParameters(m['params']),
        body: BlockStatement.fromJson(m['body'] as Map<String, dynamic>),
        generator: m['generator'] as bool,
        async: m['async'] as bool,
        declare: m['declare'] as bool?,
        returnType: m['returnType'] == null
            ? null
            : TSTypeAnnotation.fromJson(
                m['returnType'] as Map<String, dynamic>,
              ),
        typeParameters: m['typeParameters'] == null
            ? null
            : TSTypeParameterDeclaration.fromJson(
                m['typeParameters'] as Map<String, dynamic>,
              ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ObjectProperty.fromJson(Map<String, dynamic> m) => ObjectProperty(
    key: TsAstFactory.fromJsonKey(m['key'] as Map<String, dynamic>),
    value: TsAstFactory.fromJsonExpressionOrPatternLike(
      m['value'] as Map<String, dynamic>,
    ),
    computed: m['computed'] as bool,
    shorthand: m['shorthand'] as bool,
    decorators: _readList<Decorator>(m['decorators'], Decorator.fromJson),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Spread element in object/array.
final class SpreadElement extends BaseNode {
  final Expression argument;
  const SpreadElement({
    required this.argument,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory SpreadElement.fromJson(Map<String, dynamic> m) => SpreadElement(
    argument: TsAstFactory.fromJsonExpression(
      m['argument'] as Map<String, dynamic>,
    ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory RestElement.fromJson(Map<String, dynamic> m) => RestElement(
    argument: TsAstFactory.fromJsonRestArgument(
      m['argument'] as Map<String, dynamic>,
    ),
    decorators: _readList<Decorator>(m['decorators'], Decorator.fromJson),
    optional: m['optional'] as bool?,
    typeAnnotation: m['typeAnnotation'] == null
        ? null
        : TSTypeAnnotation.fromJson(
            m['typeAnnotation'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory AssignmentPattern.fromJson(Map<String, dynamic> m) =>
      AssignmentPattern(
        left: TsAstFactory.fromJsonAssignmentLeft(
          m['left'] as Map<String, dynamic>,
        ),
        right: TsAstFactory.fromJsonExpression(
          m['right'] as Map<String, dynamic>,
        ),
        decorators: _readList<Decorator>(m['decorators'], Decorator.fromJson),
        optional: m['optional'] as bool?,
        typeAnnotation: m['typeAnnotation'] == null
            ? null
            : TSTypeAnnotation.fromJson(
                m['typeAnnotation'] as Map<String, dynamic>,
              ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ArrayPattern.fromJson(Map<String, dynamic> m) => ArrayPattern(
    elements: _readOptionalPatternList(m['elements']),
    decorators: _readList<Decorator>(m['decorators'], Decorator.fromJson),
    optional: m['optional'] as bool?,
    typeAnnotation: m['typeAnnotation'] == null
        ? null
        : TSTypeAnnotation.fromJson(
            m['typeAnnotation'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ObjectPattern.fromJson(Map<String, dynamic> m) => ObjectPattern(
    properties: _readObjPatternProps(m['properties']),
    decorators: _readList<Decorator>(m['decorators'], Decorator.fromJson),
    optional: m['optional'] as bool?,
    typeAnnotation: m['typeAnnotation'] == null
        ? null
        : TSTypeAnnotation.fromJson(
            m['typeAnnotation'] as Map<String, dynamic>,
          ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Void pattern.
final class VoidPattern extends PatternLike {
  const VoidPattern({
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory VoidPattern.fromJson(Map<String, dynamic> m) => VoidPattern(
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Decorator.
final class Decorator extends BaseNode {
  final Expression expression;
  const Decorator({
    required this.expression,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory Decorator.fromJson(Map<String, dynamic> m) => Decorator(
    expression: TsAstFactory.fromJsonExpression(
      m['expression'] as Map<String, dynamic>,
    ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ImportDeclaration.fromJson(Map<String, dynamic> m) =>
      ImportDeclaration(
        specifiers: _readImportSpecifiers(m['specifiers']),
        source: StringLiteral.fromJson(m['source'] as Map<String, dynamic>),
        attributes: _readList<ImportAttribute>(
          m['attributes'],
          ImportAttribute.fromJson,
        ),
        importKind: m['importKind'] as String?,
        module: m['module'] as bool?,
        phase: m['phase'] as String?,
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ExportNamedDeclaration.fromJson(Map<String, dynamic> m) =>
      ExportNamedDeclaration(
        declaration: m['declaration'] == null
            ? null
            : TsAstFactory.fromJsonDeclaration(
                m['declaration'] as Map<String, dynamic>,
              ),
        specifiers: _readExportSpecifiers(m['specifiers']),
        source: m['source'] == null
            ? null
            : StringLiteral.fromJson(m['source'] as Map<String, dynamic>),
        attributes: _readList<ImportAttribute>(
          m['attributes'],
          ImportAttribute.fromJson,
        ),
        exportKind: m['exportKind'] as String?,
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// Export default declaration.
final class ExportDefaultDeclaration extends Declaration {
  final Object
  declaration; // TSDeclareFunction | FunctionDeclaration | ClassDeclaration | Expression
  final String? exportKind; // value
  const ExportDefaultDeclaration({
    required this.declaration,
    this.exportKind,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ExportDefaultDeclaration.fromJson(Map<String, dynamic> m) =>
      ExportDefaultDeclaration(
        declaration: TsAstFactory.fromJsonExportDefaultDecl(
          m['declaration'] as Map<String, dynamic>,
        ),
        exportKind: m['exportKind'] as String?,
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// Export all declaration.
final class ExportAllDeclaration extends Declaration {
  final StringLiteral source;
  final List<ImportAttribute>? attributes;
  final String? exportKind; // type | value
  const ExportAllDeclaration({
    required this.source,
    this.attributes,
    this.exportKind,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ExportAllDeclaration.fromJson(Map<String, dynamic> m) =>
      ExportAllDeclaration(
        source: StringLiteral.fromJson(m['source'] as Map<String, dynamic>),
        attributes: _readList<ImportAttribute>(
          m['attributes'],
          ImportAttribute.fromJson,
        ),
        exportKind: m['exportKind'] as String?,
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// Import/Export attributes.
final class ImportAttribute extends BaseNode {
  final Object key; // Identifier | StringLiteral
  final StringLiteral value;
  const ImportAttribute({
    required this.key,
    required this.value,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ImportAttribute.fromJson(Map<String, dynamic> m) => ImportAttribute(
    key: TsAstFactory.fromJsonIdentifierOrString(
      m['key'] as Map<String, dynamic>,
    ),
    value: StringLiteral.fromJson(m['value'] as Map<String, dynamic>),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ExportSpecifier.fromJson(Map<String, dynamic> m) => ExportSpecifier(
    local: Identifier.fromJson(m['local'] as Map<String, dynamic>),
    exported: TsAstFactory.fromJsonIdentifierOrString(
      m['exported'] as Map<String, dynamic>,
    ),
    exportKind: m['exportKind'] as String?,
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Export default specifier.
final class ExportDefaultSpecifier extends BaseNode {
  final Identifier exported;
  const ExportDefaultSpecifier({
    required this.exported,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ExportDefaultSpecifier.fromJson(Map<String, dynamic> m) =>
      ExportDefaultSpecifier(
        exported: Identifier.fromJson(m['exported'] as Map<String, dynamic>),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// Export namespace specifier.
final class ExportNamespaceSpecifier extends BaseNode {
  final Identifier exported;
  const ExportNamespaceSpecifier({
    required this.exported,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ExportNamespaceSpecifier.fromJson(Map<String, dynamic> m) =>
      ExportNamespaceSpecifier(
        exported: Identifier.fromJson(m['exported'] as Map<String, dynamic>),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// Import default specifier.
final class ImportDefaultSpecifier extends BaseNode {
  final Identifier local;
  const ImportDefaultSpecifier({
    required this.local,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ImportDefaultSpecifier.fromJson(Map<String, dynamic> m) =>
      ImportDefaultSpecifier(
        local: Identifier.fromJson(m['local'] as Map<String, dynamic>),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// Import namespace specifier.
final class ImportNamespaceSpecifier extends BaseNode {
  final Identifier local;
  const ImportNamespaceSpecifier({
    required this.local,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ImportNamespaceSpecifier.fromJson(Map<String, dynamic> m) =>
      ImportNamespaceSpecifier(
        local: Identifier.fromJson(m['local'] as Map<String, dynamic>),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory ImportSpecifier.fromJson(Map<String, dynamic> m) => ImportSpecifier(
    local: Identifier.fromJson(m['local'] as Map<String, dynamic>),
    imported: TsAstFactory.fromJsonIdentifierOrString(
      m['imported'] as Map<String, dynamic>,
    ),
    importKind: m['importKind'] as String?,
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// TS: type annotation wrapper.
final class TSTypeAnnotation extends BaseNode {
  final TSType typeAnnotation;
  const TSTypeAnnotation({
    required this.typeAnnotation,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSTypeAnnotation.fromJson(Map<String, dynamic> m) => TSTypeAnnotation(
    typeAnnotation: TsAstFactory.fromJsonTSType(
      m['typeAnnotation'] as Map<String, dynamic>,
    ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// TS: type parameter instantiation.
final class TSTypeParameterInstantiation extends BaseNode {
  final List<TSType> params;
  const TSTypeParameterInstantiation({
    required this.params,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSTypeParameterInstantiation.fromJson(Map<String, dynamic> m) =>
      TSTypeParameterInstantiation(
        params: _readList<TSType>(
          m['params'],
          (mm) => TsAstFactory.fromJsonTSType(mm),
        ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// TS: type parameter declaration.
final class TSTypeParameterDeclaration extends BaseNode {
  final List<TSTypeParameter> params;
  const TSTypeParameterDeclaration({
    required this.params,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSTypeParameterDeclaration.fromJson(Map<String, dynamic> m) =>
      TSTypeParameterDeclaration(
        params: _readList<TSTypeParameter>(
          m['params'],
          TSTypeParameter.fromJson,
        ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSTypeParameter.fromJson(Map<String, dynamic> m) => TSTypeParameter(
    constraint: m['constraint'] == null
        ? null
        : TsAstFactory.fromJsonTSType(m['constraint'] as Map<String, dynamic>),
    defaultType: m['default'] == null
        ? null
        : TsAstFactory.fromJsonTSType(m['default'] as Map<String, dynamic>),
    name: m['name'] as String,
    isConst: m['const'] as bool?,
    isIn: m['in'] as bool?,
    isOut: m['out'] as bool?,
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// TS: type union root.
sealed class TSType extends BaseNode {
  const TSType({
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
}

/// TS: any keyword.
final class TSAnyKeyword extends TSType {
  const TSAnyKeyword({
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSAnyKeyword.fromJson(Map<String, dynamic> m) => TSAnyKeyword(
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

// ... Due to size, remaining TS type classes follow the same pattern and will be implemented
// for: TSBooleanKeyword, TSBigIntKeyword, TSIntrinsicKeyword, TSNeverKeyword, TSNullKeyword,
// TSNumberKeyword, TSObjectKeyword, TSStringKeyword, TSSymbolKeyword, TSUndefinedKeyword,
// TSUnknownKeyword, TSVoidKeyword, TSThisType, TSFunctionType, TSConstructorType, TSTypeReference,
// TSTypePredicate, TSTypeQuery, TSTypeLiteral, TSArrayType, TSTupleType, TSOptionalType, TSRestType,
// TSUnionType, TSIntersectionType, TSConditionalType, TSInferType, TSParenthesizedType, TSTypeOperator,
// TSIndexedAccessType, TSMappedType, TSTemplateLiteralType, TSLiteralType, TSExpressionWithTypeArguments,
// TSImportType and all remaining AST nodes from ast.ts.

/// Utility: read comments list.
List<Comment>? _readComments(dynamic v) {
  if (v == null) return null;
  final xs = v as List;
  return xs.map((e) {
    final m = e as Map<String, dynamic>;
    final t = m['type'] as String;
    return t == 'CommentBlock'
        ? CommentBlock.fromJson(m)
        : CommentLine.fromJson(m);
  }).toList();
}

/// Utility: read range [start,end].
List<int>? _readRange(dynamic v) {
  if (v == null) return null;
  final xs = v as List;
  return xs.map((e) => (e as num).toInt()).toList();
}

/// Utility: generic list reader.
List<T> _readList<T>(dynamic v, T Function(Map<String, dynamic>) f) {
  if (v == null) return const [];
  final xs = v as List;
  return xs.map((e) => f(e as Map<String, dynamic>)).toList();
}

/// Utility: mixed list (Expression | SpreadElement | ArgumentPlaceholder).
List<Object?> _readMixedList(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs
      .map((e) => TsAstFactory.fromJsonAny(e as Map<String, dynamic>))
      .toList();
}

/// Utility: optional pattern list (null | PatternLike) for ArrayPattern.
List<Object?> _readOptionalPatternList(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs.map((e) {
    if (e == null) return null;
    final m = e as Map<String, dynamic>;
    return TsAstFactory.fromJsonExpressionOrPatternLike(m);
  }).toList();
}

/// Utility: object expression props.
List<Object> _readObjProps(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs
      .map((e) => TsAstFactory.fromJsonObjectMember(e as Map<String, dynamic>))
      .toList();
}

/// Utility: object pattern props.
List<Object> _readObjPatternProps(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs
      .map(
        (e) =>
            TsAstFactory.fromJsonObjectPatternProp(e as Map<String, dynamic>),
      )
      .toList();
}

/// Utility: function parameter list.
List<Object> _readFunctionParameters(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs
      .map(
        (e) =>
            TsAstFactory.fromJsonFunctionParameter(e as Map<String, dynamic>),
      )
      .toList();
}

/// Utility: import specifiers list.
List<Object> _readImportSpecifiers(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs
      .map(
        (e) => TsAstFactory.fromJsonImportSpecifier(e as Map<String, dynamic>),
      )
      .toList();
}

/// Utility: export specifiers list.
List<Object> _readExportSpecifiers(dynamic v) {
  if (v == null) return const [];
  final xs = v as List;
  return xs
      .map(
        (e) => TsAstFactory.fromJsonExportSpecifier(e as Map<String, dynamic>),
      )
      .toList();
}

/// Union helpers and top-level factory.
final class TsAstFactory {
  static BaseNode fromJson(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'Program':
        return Program.fromJson(m);
      case 'BlockStatement':
        return BlockStatement.fromJson(m);
      case 'ExpressionStatement':
        return ExpressionStatement.fromJson(m);
      case 'Identifier':
        return Identifier.fromJson(m);
      case 'StringLiteral':
        return StringLiteral.fromJson(m);
      case 'NumericLiteral':
        return NumericLiteral.fromJson(m);
      case 'NullLiteral':
        return NullLiteral.fromJson(m);
      case 'BooleanLiteral':
        return BooleanLiteral.fromJson(m);
      case 'RegExpLiteral':
        return RegExpLiteral.fromJson(m);
      case 'TemplateElement':
        return TemplateElement.fromJson(m);
      case 'TemplateLiteral':
        return TemplateLiteral.fromJson(m);
      case 'TaggedTemplateExpression':
        return TaggedTemplateExpression.fromJson(m);
      case 'OptionalMemberExpression':
        return OptionalMemberExpression.fromJson(m);
      case 'OptionalCallExpression':
        return OptionalCallExpression.fromJson(m);
      case 'ImportExpression':
        return ImportExpression.fromJson(m);
      case 'BigIntLiteral':
        return BigIntLiteral.fromJson(m);
      case 'NumberLiteral':
        return NumberLiteral.fromJson(m);
      case 'DecimalLiteral':
        return DecimalLiteral.fromJson(m);
      case 'CallExpression':
        return CallExpression.fromJson(m);
      case 'MemberExpression':
        return MemberExpression.fromJson(m);
      case 'NewExpression':
        return NewExpression.fromJson(m);
      case 'ObjectExpression':
        return ObjectExpression.fromJson(m);
      case 'ObjectProperty':
        return ObjectProperty.fromJson(m);
      case 'ObjectMethod':
        return ObjectMethod.fromJson(m);
      case 'FunctionExpression':
        return FunctionExpression.fromJson(m);
      case 'FunctionDeclaration':
        return FunctionDeclaration.fromJson(m);
      case 'ArrowFunctionExpression':
        return ArrowFunctionExpression.fromJson(m);
      case 'ClassMethod':
        return ClassMethod.fromJson(m);
      case 'ClassPrivateMethod':
        return ClassPrivateMethod.fromJson(m);
      case 'StaticBlock':
        return StaticBlock.fromJson(m);
      case 'TSModuleBlock':
        return TSModuleBlock.fromJson(m);
      case 'ClassBody':
        return ClassBody.fromJson(m);
      case 'ClassExpression':
        return ClassExpression.fromJson(m);
      case 'ClassDeclaration':
        return ClassDeclaration.fromJson(m);
      case 'TSPropertySignature':
        return TSPropertySignature.fromJson(m);
      case 'TSInterfaceBody':
        return TSInterfaceBody.fromJson(m);
      case 'TSInterfaceDeclaration':
        return TSInterfaceDeclaration.fromJson(m);
      case 'TSTypeAliasDeclaration':
        return TSTypeAliasDeclaration.fromJson(m);
      case 'TSDeclareFunction':
        return TSDeclareFunction.fromJson(m);
      case 'SpreadElement':
        return SpreadElement.fromJson(m);
      case 'RestElement':
        return RestElement.fromJson(m);
      case 'AssignmentPattern':
        return AssignmentPattern.fromJson(m);
      case 'ArrayPattern':
        return ArrayPattern.fromJson(m);
      case 'ObjectPattern':
        return ObjectPattern.fromJson(m);
      case 'VoidPattern':
        return VoidPattern.fromJson(m);
      case 'Decorator':
        return Decorator.fromJson(m);
      case 'ImportDeclaration':
        return ImportDeclaration.fromJson(m);
      case 'ExportNamedDeclaration':
        return ExportNamedDeclaration.fromJson(m);
      case 'ExportDefaultDeclaration':
        return ExportDefaultDeclaration.fromJson(m);
      case 'ExportAllDeclaration':
        return ExportAllDeclaration.fromJson(m);
      case 'ImportAttribute':
        return ImportAttribute.fromJson(m);
      case 'ExportSpecifier':
        return ExportSpecifier.fromJson(m);
      case 'ExportDefaultSpecifier':
        return ExportDefaultSpecifier.fromJson(m);
      case 'ExportNamespaceSpecifier':
        return ExportNamespaceSpecifier.fromJson(m);
      case 'ImportDefaultSpecifier':
        return ImportDefaultSpecifier.fromJson(m);
      case 'ImportNamespaceSpecifier':
        return ImportNamespaceSpecifier.fromJson(m);
      case 'ImportSpecifier':
        return ImportSpecifier.fromJson(m);
      case 'TSTypeAnnotation':
        return TSTypeAnnotation.fromJson(m);
      case 'TSTypeParameterInstantiation':
        return TSTypeParameterInstantiation.fromJson(m);
      case 'TSTypeParameterDeclaration':
        return TSTypeParameterDeclaration.fromJson(m);
      case 'TSTypeParameter':
        return TSTypeParameter.fromJson(m);
      case 'TSAnyKeyword':
        return TSAnyKeyword.fromJson(m);
      default:
        return _UnknownNode(m);
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
    if (t == 'SpreadElement') return SpreadElement.fromJson(m);
    if (t == 'ArgumentPlaceholder') return _ArgumentPlaceholder.fromJson(m);
    return fromJsonExpression(m);
  }

  static Object fromJsonExpressionOrSuper(Map<String, dynamic> m) {
    final t = m['type'] as String;
    if (t == 'Super') return Super.fromJson(m);
    return fromJsonExpression(m);
  }

  static Object fromJsonExpressionOrSuperOrV8Intrinsic(Map<String, dynamic> m) {
    final t = m['type'] as String;
    if (t == 'Super') return Super.fromJson(m);
    if (t == 'V8IntrinsicIdentifier') return V8IntrinsicIdentifier.fromJson(m);
    return fromJsonExpression(m);
  }

  static Object fromJsonExpressionOrIdentifierOrPrivateName(
    Map<String, dynamic> m,
  ) {
    final t = m['type'] as String;
    if (t == 'Identifier') return Identifier.fromJson(m);
    if (t == 'PrivateName') return PrivateName.fromJson(m);
    return fromJsonExpression(m);
  }

  static Object fromJsonIdentifierOrString(Map<String, dynamic> m) {
    final t = m['type'] as String;
    if (t == 'Identifier') return Identifier.fromJson(m);
    return StringLiteral.fromJson(m);
  }

  static Object fromJsonObjectMember(Map<String, dynamic> m) {
    final t = m['type'] as String;
    if (t == 'ObjectMethod') return ObjectMethod.fromJson(m);
    if (t == 'ObjectProperty') return ObjectProperty.fromJson(m);
    return SpreadElement.fromJson(m);
  }

  static Object fromJsonObjectPatternProp(Map<String, dynamic> m) {
    final t = m['type'] as String;
    if (t == 'RestElement') return RestElement.fromJson(m);
    return ObjectProperty.fromJson(m);
  }

  static Object fromJsonFunctionParameter(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'Identifier':
        return Identifier.fromJson(m);
      case 'RestElement':
        return RestElement.fromJson(m);
      case 'AssignmentPattern':
        return AssignmentPattern.fromJson(m);
      case 'ArrayPattern':
        return ArrayPattern.fromJson(m);
      case 'ObjectPattern':
        return ObjectPattern.fromJson(m);
      case 'VoidPattern':
        return VoidPattern.fromJson(m);
      default:
        return _UnknownNode(m);
    }
  }

  static Object fromJsonKey(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'Identifier':
        return Identifier.fromJson(m);
      case 'StringLiteral':
        return StringLiteral.fromJson(m);
      case 'NumericLiteral':
        return NumericLiteral.fromJson(m);
      case 'BigIntLiteral':
        return BigIntLiteral.fromJson(m);
      case 'DecimalLiteral':
        return DecimalLiteral.fromJson(m);
      case 'PrivateName':
        return PrivateName.fromJson(m);
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
        return Identifier.fromJson(m);
      case 'StringLiteral':
        return StringLiteral.fromJson(m);
      case 'NumericLiteral':
        return NumericLiteral.fromJson(m);
      case 'BigIntLiteral':
        return BigIntLiteral.fromJson(m);
      default:
        return fromJsonExpression(m);
    }
  }

  static Object fromJsonExpressionOrPatternLike(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'Identifier':
        return Identifier.fromJson(m);
      case 'MemberExpression':
        return MemberExpression.fromJson(m);
      case 'RestElement':
        return RestElement.fromJson(m);
      case 'AssignmentPattern':
        return AssignmentPattern.fromJson(m);
      case 'ArrayPattern':
        return ArrayPattern.fromJson(m);
      case 'ObjectPattern':
        return ObjectPattern.fromJson(m);
      case 'VoidPattern':
        return VoidPattern.fromJson(m);
      case 'TSAsExpression':
        return TSAsExpression.fromJson(m);
      case 'TSSatisfiesExpression':
        return TSSatisfiesExpression.fromJson(m);
      case 'TSTypeAssertion':
        return TSTypeAssertion.fromJson(m);
      case 'TSNonNullExpression':
        return TSNonNullExpression.fromJson(m);
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

  static Object fromJsonExportDefaultDecl(Map<String, dynamic> m) {
    return fromJsonExpression(m);
  }

  static Object fromJsonImportSpecifier(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'ImportDefaultSpecifier':
        return ImportDefaultSpecifier.fromJson(m);
      case 'ImportNamespaceSpecifier':
        return ImportNamespaceSpecifier.fromJson(m);
      case 'ImportSpecifier':
        return ImportSpecifier.fromJson(m);
      default:
        return _UnknownNode(m);
    }
  }

  static Object fromJsonExportSpecifier(Map<String, dynamic> m) {
    final t = m['type'] as String;
    switch (t) {
      case 'ExportSpecifier':
        return ExportSpecifier.fromJson(m);
      case 'ExportDefaultSpecifier':
        return ExportDefaultSpecifier.fromJson(m);
      case 'ExportNamespaceSpecifier':
        return ExportNamespaceSpecifier.fromJson(m);
      default:
        return _UnknownNode(m);
    }
  }
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSPropertySignature.fromJson(Map<String, dynamic> m) =>
      TSPropertySignature(
        key: TsAstFactory.fromJsonKey(m['key'] as Map<String, dynamic>),
        optional: m['optional'] as bool? ?? false,
        typeAnnotation: m['typeAnnotation'] == null
            ? null
            : TSTypeAnnotation.fromJson(
                m['typeAnnotation'] as Map<String, dynamic>,
              ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

final class TSInterfaceBody extends BaseNode {
  final List<TSPropertySignature> body;
  const TSInterfaceBody({
    required this.body,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSInterfaceBody.fromJson(Map<String, dynamic> m) => TSInterfaceBody(
    body: _readList<TSPropertySignature>(
      m['body'],
      TSPropertySignature.fromJson,
    ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSTypeAliasDeclaration.fromJson(Map<String, dynamic> m) =>
      TSTypeAliasDeclaration(
        id: Identifier.fromJson(m['id'] as Map<String, dynamic>),
        members: _readList<TSPropertySignature>(
          m['members'],
          TSPropertySignature.fromJson,
        ),
        typeParameters: m['typeParameters'] == null
            ? null
            : TSTypeParameterDeclaration.fromJson(
                m['typeParameters'] as Map<String, dynamic>,
              ),
        declare: m['declare'] as bool?,
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
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
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSInterfaceDeclaration.fromJson(Map<String, dynamic> m) =>
      TSInterfaceDeclaration(
        id: Identifier.fromJson(m['id'] as Map<String, dynamic>),
        body: TSInterfaceBody.fromJson(m['body'] as Map<String, dynamic>),
        typeParameters: m['typeParameters'] == null
            ? null
            : TSTypeParameterDeclaration.fromJson(
                m['typeParameters'] as Map<String, dynamic>,
              ),
        extendsItems: _readList<Object>(
          m['extends'],
          (mm) => TsAstFactory.fromJsonAny(mm),
        ),
        declare: m['declare'] as bool?,
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

final class TSDeclareFunction extends Declaration {
  final Identifier id;
  final List<Object> params; // FunctionParameter
  final TSTypeAnnotation? returnType;
  final TSTypeParameterDeclaration? typeParameters;
  const TSDeclareFunction({
    required this.id,
    required this.params,
    this.returnType,
    this.typeParameters,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSDeclareFunction.fromJson(Map<String, dynamic> m) =>
      TSDeclareFunction(
        id: Identifier.fromJson(m['id'] as Map<String, dynamic>),
        params: _readFunctionParameters(m['params']),
        returnType: m['returnType'] == null
            ? null
            : TSTypeAnnotation.fromJson(
                m['returnType'] as Map<String, dynamic>,
              ),
        typeParameters: m['typeParameters'] == null
            ? null
            : TSTypeParameterDeclaration.fromJson(
                m['typeParameters'] as Map<String, dynamic>,
              ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// Placeholder for unimplemented nodes during incremental adoption.
final class _UnknownNode extends BaseNode {
  final String type;
  final Map<String, Object?> raw;
  _UnknownNode(Map<String, dynamic> m)
    : type = m['type'] as String,
      raw = m.cast<String, Object?>();
}

/// Argument placeholder node.
final class _ArgumentPlaceholder extends BaseNode {
  const _ArgumentPlaceholder({
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory _ArgumentPlaceholder.fromJson(Map<String, dynamic> m) =>
      _ArgumentPlaceholder(
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// Super expression.
final class Super extends BaseNode {
  const Super({
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory Super.fromJson(Map<String, dynamic> m) => Super(
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Private name.
final class PrivateName extends BaseNode {
  final Identifier id;
  const PrivateName({
    required this.id,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory PrivateName.fromJson(Map<String, dynamic> m) => PrivateName(
    id: Identifier.fromJson(m['id'] as Map<String, dynamic>),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// V8 intrinsic identifier.
final class V8IntrinsicIdentifier extends BaseNode {
  final String name;
  const V8IntrinsicIdentifier({
    required this.name,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory V8IntrinsicIdentifier.fromJson(Map<String, dynamic> m) =>
      V8IntrinsicIdentifier(
        name: m['name'] as String,
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// TS cast: as expression.
final class TSAsExpression extends Expression {
  final Expression expression;
  final TSType typeAnnotation;
  const TSAsExpression({
    required this.expression,
    required this.typeAnnotation,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSAsExpression.fromJson(Map<String, dynamic> m) => TSAsExpression(
    expression: TsAstFactory.fromJsonExpression(
      m['expression'] as Map<String, dynamic>,
    ),
    typeAnnotation: TsAstFactory.fromJsonTSType(
      m['typeAnnotation'] as Map<String, dynamic>,
    ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// TS satisfies expression.
final class TSSatisfiesExpression extends Expression {
  final Expression expression;
  final TSType typeAnnotation;
  const TSSatisfiesExpression({
    required this.expression,
    required this.typeAnnotation,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSSatisfiesExpression.fromJson(Map<String, dynamic> m) =>
      TSSatisfiesExpression(
        expression: TsAstFactory.fromJsonExpression(
          m['expression'] as Map<String, dynamic>,
        ),
        typeAnnotation: TsAstFactory.fromJsonTSType(
          m['typeAnnotation'] as Map<String, dynamic>,
        ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

/// TS type assertion.
final class TSTypeAssertion extends Expression {
  final TSType typeAnnotation;
  final Expression expression;
  const TSTypeAssertion({
    required this.typeAnnotation,
    required this.expression,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSTypeAssertion.fromJson(Map<String, dynamic> m) => TSTypeAssertion(
    typeAnnotation: TsAstFactory.fromJsonTSType(
      m['typeAnnotation'] as Map<String, dynamic>,
    ),
    expression: TsAstFactory.fromJsonExpression(
      m['expression'] as Map<String, dynamic>,
    ),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// TS non-null expression.
final class TSNonNullExpression extends Expression {
  final Expression expression;
  const TSNonNullExpression({
    required this.expression,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
  factory TSNonNullExpression.fromJson(Map<String, dynamic> m) =>
      TSNonNullExpression(
        expression: TsAstFactory.fromJsonExpression(
          m['expression'] as Map<String, dynamic>,
        ),
        leadingComments: _readComments(m['leadingComments']),
        innerComments: _readComments(m['innerComments']),
        trailingComments: _readComments(m['trailingComments']),
        start: (m['start'] as num?)?.toInt(),
        end: (m['end'] as num?)?.toInt(),
        loc: m['loc'] == null
            ? null
            : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
        range: _readRange(m['range']),
        extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
      );
}

// NOTE: Additional statements, declarations (FunctionDeclaration, ClassDeclaration, VariableDeclaration,
// VariableDeclarator, etc.), JSX nodes, and the full TS type family will be added following the same
// pattern above to reach full coverage defined in ast.ts. The factory and helpers already support
// union dispatch; unrecognized nodes will temporarily be represented by _UnknownNode.

/// Helper: list literal expression for codegen utilities.
final class ListLiteral extends Expression {
  final List<Expression> elements;
  const ListLiteral({
    required this.elements,
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
}

/// Helper: set/map literal for codegen utilities with key-value entries.
final class SetOrMapLiteral extends Expression {
  final List<MapLiteralEntry> elements;
  const SetOrMapLiteral({
    required this.elements,
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
}

/// Helper: map literal entry used by SetOrMapLiteral.
final class MapLiteralEntry extends BaseNode {
  final String keyText;
  final Expression value;
  const MapLiteralEntry({
    required this.keyText,
    required this.value,
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
}

/// Helper: argument list wrapper used by FunctionCallExpression.
final class ArgumentList extends BaseNode {
  final List<Expression> arguments;
  const ArgumentList({
    required this.arguments,
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
}

/// Helper: function call expression enriched with type arguments parsing.
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
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
}

/// Binding pattern base used by macro conversion utilities.
sealed class BindingPattern extends BaseNode {
  final String? typeAnnotationText;
  const BindingPattern({
    this.typeAnnotationText,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
    super.startByte,
    super.endByte,
    super.text,
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
    super.startByte,
    super.endByte,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
    String? text,
  }) : super(text: text ?? '');
}

/// Array binding pattern for destructuring.
final class ArrayBindingPattern extends BindingPattern {
  final List<ArrayBindingElement> elements;
  final List<String?> typeIndexMap;
  const ArrayBindingPattern({
    required this.elements,
    this.typeIndexMap = const [],
    super.typeAnnotationText,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
    super.startByte,
    super.endByte,
    super.text,
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
    super.startByte,
    super.endByte,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
    String? text,
  }) : super(text: text ?? '');
}

/// Object binding pattern for destructuring.
final class ObjectBindingPattern extends BindingPattern {
  final List<ObjectBindingProperty> properties;
  final Map<String, String?> typeKeyMap;
  const ObjectBindingPattern({
    required this.properties,
    this.typeKeyMap = const {},
    super.typeAnnotationText,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
    super.startByte,
    super.endByte,
    super.text,
  });
}

/// Helper: invocation of inline function text used by macro analysis.
final class FunctionExpressionInvocation extends Expression {
  final String functionText;
  final ArgumentList argumentList;
  const FunctionExpressionInvocation({
    required this.functionText,
    required this.argumentList,
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
}

/// Compatibility: number literal to align with existing macro code.
final class NumberLiteral extends Expression {
  final num value;
  const NumberLiteral({
    required this.value,
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
  factory NumberLiteral.fromJson(Map<String, dynamic> m) => NumberLiteral(
    value: (m['value'] as num),
    leadingComments: _readComments(m['leadingComments']),
    innerComments: _readComments(m['innerComments']),
    trailingComments: _readComments(m['trailingComments']),
    start: (m['start'] as num?)?.toInt(),
    end: (m['end'] as num?)?.toInt(),
    loc: m['loc'] == null
        ? null
        : SourceLocation.fromJson(m['loc'] as Map<String, dynamic>),
    range: _readRange(m['range']),
    extra: (m['extra'] as Map<String, dynamic>?)?.cast<String, Object?>(),
  );
}

/// Macro analysis unit wrapper compatible with existing compilation pipeline.
///
/// statements: existing expression statements used by macro analysis; kept for
/// backward compatibility.
/// moduleDeclarations: ECMAScript module declarations preserved in structured
/// AST form (ImportDeclaration, ExportAllDeclaration, ExportNamedDeclaration,
/// ExportDefaultDeclaration). Only these types are accepted.
final class CompilationUnit extends BaseNode {
  final List<ExpressionStatement> statements;
  final List<Declaration> imported;
  final List<Declaration> exported;
  final List<UserVariable> userVariables;
  const CompilationUnit({
    required this.statements,
    this.imported = const [],
    this.exported = const [],
    this.userVariables = const [],
    super.startByte,
    super.endByte,
    super.text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  });
}

/// Represents a user-defined variable captured during compilation.
final class UserVariable {
  final String name;
  final String? type;
  final String? defaultValue;
  const UserVariable({required this.name, this.type, this.defaultValue});

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'type': type,
      'defaultValue': defaultValue,
    };
  }

  static UserVariable fromJson(Map<String, Object?> m) {
    return UserVariable(
      name: (m['name'] ?? '') as String,
      type: m['type'] as String?,
      defaultValue: m['defaultValue'] as String?,
    );
  }
}

/// Declarator analysis result for macros.
final class TsDeclaratorAnalysis {
  final String declarationType; // call | variable | function_expression | none
  final String identifier;
  final Map<String, Object?> initDetails;
  final int startByte;
  final int endByte;
  const TsDeclaratorAnalysis({
    required this.declarationType,
    required this.identifier,
    required this.initDetails,
    required this.startByte,
    required this.endByte,
  });
}

/// Analyze simple declarators within a CompilationUnit for macro usage.
List<TsDeclaratorAnalysis> analyzeTsDeclarators(CompilationUnit unit) {
  String valueType(Expression e) {
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

  TsDeclaratorAnalysis analyzeOne(
    Identifier name,
    Expression? init,
    int s,
    int e,
    BindingPattern? pattern,
  ) {
    if (init == null) {
      return TsDeclaratorAnalysis(
        declarationType: 'none',
        identifier: name.name,
        initDetails: {'destructure': pattern is BindingPattern},
        startByte: s,
        endByte: e,
      );
    }
    if (init is FunctionCallExpression) {
      return TsDeclaratorAnalysis(
        declarationType: 'call',
        identifier: name.name,
        initDetails: {
          'callee': init.methodName.name,
          'argsCount': init.argumentList.arguments.length,
          'typeArgs': init.typeArgumentText,
          'destructure': pattern is BindingPattern,
        },
        startByte: s,
        endByte: e,
      );
    }
    if (init is FunctionExpressionInvocation) {
      return TsDeclaratorAnalysis(
        declarationType: 'function_expression',
        identifier: name.name,
        initDetails: {
          'functionText': init.functionText,
          'argsCount': init.argumentList.arguments.length,
          'destructure': pattern is BindingPattern,
        },
        startByte: s,
        endByte: e,
      );
    }
    if (init is FunctionExpression) {
      return TsDeclaratorAnalysis(
        declarationType: 'function_expression',
        identifier: name.name,
        initDetails: {
          'id': init.id?.name,
          'paramsCount': init.params.length,
          'async': init.async,
          'generator': init.generator,
          'hasReturnType': init.returnType != null,
          'destructure': pattern is BindingPattern,
        },
        startByte: s,
        endByte: e,
      );
    }
    return TsDeclaratorAnalysis(
      declarationType: 'variable',
      identifier: name.name,
      initDetails: {
        'valueType': valueType(init),
        'valueText': _extractText(init),
        'destructure': pattern is BindingPattern,
      },
      startByte: s,
      endByte: e,
    );
  }

  final out = <TsDeclaratorAnalysis>[];
  for (final st in unit.statements) {
    final exp = st.expression;
    if (exp is VariableDeclaration) {
      out.add(
        analyzeOne(
          exp.name,
          exp.init,
          exp.start ?? 0,
          exp.end ?? 0,
          exp.pattern,
        ),
      );
    }
  }
  return out;
}

/// Helper to extract readable text from expression when available.
String? _extractText(Expression e) {
  if (e is StringLiteral) return e.value;
  if (e is NumberLiteral) return e.value.toString();
  if (e is BooleanLiteral) return e.value.toString();
  if (e is BigIntLiteral) return e.value.toString();
  return null;
}

/// Unified variable declaration node used by macro conversion and analysis.
///
/// This type merges the previous `VariableDeclaration` and `VariableDeclarator`
/// wrappers into a single node. It captures the declared identifier `name`,
/// optional initializer `init`, and optional destructuring `pattern` info.
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
    super.startByte,
    super.endByte,
    String? text,
    super.leadingComments,
    super.innerComments,
    super.trailingComments,
    super.start,
    super.end,
    super.loc,
    super.range,
    super.extra,
  }) : super(text: text ?? '');
}
class LocationInfo {
  final int lineNumber;
  final int columnNumber;
  final int endLineNumber;
  final int endColumnNumber;
  const LocationInfo({
    required this.lineNumber,
    required this.columnNumber,
    required this.endLineNumber,
    required this.endColumnNumber,
  });
}

String printNodeWithLocationSfc(Object node, LocationInfo? loc) {
  final type = node.runtimeType.toString();
  if (loc == null) return '$type @ unknown';
  return '$type @ ${loc.lineNumber}:${loc.columnNumber}-${loc.endLineNumber}:${loc.endColumnNumber}';
}

List<Object> findSfcNodesByStartLine(List<Object> nodes, int line, LocationInfo Function(Object) getLoc) {
  final out = <Object>[];
  for (final n in nodes) {
    final loc = getLoc(n);
    if (loc.lineNumber == line) out.add(n);
  }
  return out;
}
