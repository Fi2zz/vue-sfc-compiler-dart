// Minimal analyzer-compatible AST model for JS/TS via Tree-sitter.
// This mirrors the shapes used in sfc_macro.dart so JS/TS can be parsed
// and processed with similar logic to Dart analyzer nodes.

/// Base node with source text snapshot and position for debugging.
final class Node {
  final int startByte;
  final int endByte;
  final String text;
  const Node({
    required this.startByte,
    required this.endByte,
    required this.text,
  });
}

/// Expressions base class.
sealed class Expression extends Node {
  const Expression({
    required super.startByte,
    required super.endByte,
    required super.text,
  });
}

/// Generic expression wrapper for unsupported JS/TS nodes
/// so macro visitors can still access readable source text.
final class RawExpression extends Expression {
  const RawExpression({
    required super.startByte,
    required super.endByte,
    required super.text,
  });
}

final class CompilationUnit extends Node {
  final List<ExpressionStatement> statements;
  const CompilationUnit({
    required super.startByte,
    required super.endByte,
    required super.text,
    required this.statements,
  });
}

final class ExpressionStatement extends Node {
  final Expression expression;
  const ExpressionStatement({
    required super.startByte,
    required super.endByte,
    required super.text,
    required this.expression,
  });
}

final class Identifier extends Expression {
  const Identifier({
    required super.startByte,
    required super.endByte,
    required super.text,
  });
  String get name => text;
}

final class ArgumentList extends Node {
  final List<Expression> arguments;
  const ArgumentList({
    required super.startByte,
    required super.endByte,
    required super.text,
    required this.arguments,
  });
}

/// Method/function call, e.g. defineProps({...}) or foo(bar)
final class FunctionCallExpression extends Expression {
  final Identifier methodName;
  final ArgumentList argumentList;
  final String? typeArgumentText; // raw text for T args when available
  final List<PropSignature>
  typeArgumentProps; // structured props from type arguments
  const FunctionCallExpression({
    required super.startByte,
    required super.endByte,
    required super.text,
    required this.methodName,
    required this.argumentList,
    this.typeArgumentText,
    this.typeArgumentProps = const [],
  });
}

final class FunctionExpressionInvocation extends Expression {
  final String functionText;
  final ArgumentList argumentList;
  const FunctionExpressionInvocation({
    required super.startByte,
    required super.endByte,
    required super.text,
    required this.functionText,
    required this.argumentList,
  });
}

final class SetOrMapLiteral extends Expression {
  final List<MapLiteralEntry> elements;
  const SetOrMapLiteral({
    required super.startByte,
    required super.endByte,
    required super.text,
    required this.elements,
  });
}

final class MapLiteralEntry extends Node {
  final String keyText;
  final Expression value;
  const MapLiteralEntry({
    required super.startByte,
    required super.endByte,
    required super.text,
    required this.keyText,
    required this.value,
  });
}

final class ListLiteral extends Expression {
  final List<Expression> elements;
  const ListLiteral({
    required super.startByte,
    required super.endByte,
    required super.text,
    required this.elements,
  });
}

final class StringLiteral extends Expression {
  final String stringValue;
  const StringLiteral({
    required super.startByte,
    required super.endByte,
    required super.text,
    required this.stringValue,
  });
}

final class BooleanLiteral extends Expression {
  final bool value;
  const BooleanLiteral({
    required super.startByte,
    required super.endByte,
    required super.text,
    required this.value,
  });
}

/// Property signature extracted from TypeScript type arguments.
final class PropSignature {
  final String name;
  final String? type;
  final bool required;
  const PropSignature({required this.name, this.type, required this.required});
}
