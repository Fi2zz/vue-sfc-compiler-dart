import 'package:vue_sfc_parser/sfc_ast.dart';
import 'package:vue_sfc_parser/swc_parser.dart';

Expression parseSimpleExpression(String t, int start, int end) {
  final sp = SwcParser();
  try {
    final m = sp.parseExpr(code: t, language: 'ts');
    final expr = m['expr'] as Map<String, dynamic>;
    // ignore: unused_local_variable
    final type = expr['type'] as String;
    Expression fromExprOut(Map<String, dynamic> ex, int s, int e) {
      final tt = ex['type'] as String;
      switch (tt) {
        case 'NullLiteral':
          return NullLiteral(startByte: s, endByte: e, text: t);
        case 'BooleanLiteral':
          return BooleanLiteral(
            startByte: s,
            endByte: e,
            text: t,
            value: (ex['value'] as bool? ?? false),
          );
        case 'NumberLiteral':
          final v = ex['value'] as num? ?? 0;
          return NumberLiteral(startByte: s, endByte: e, text: t, value: v);
        case 'BigIntLiteral':
          final s0 = ex['value'] as String? ?? '0';
          return BigIntLiteral(
            startByte: s,
            endByte: e,
            text: t,
            value: BigInt.tryParse(s0) ?? BigInt.zero,
          );
        case 'StringLiteral':
          final sv = ex['value'] as String? ?? t;
          return StringLiteral(
            startByte: s,
            endByte: e,
            text: t,
            stringValue: sv,
          );
        case 'Identifier':
          final name = ex['name'] as String? ?? t;
          return Identifier(startByte: s, endByte: e, text: name);
        case 'FunctionExpression':
          final ft = ex['function_text'] as String? ?? t;
          return FunctionExpressionInvocation(
            functionText: ft,
            argumentList: const ArgumentList(arguments: []),
            startByte: s,
            endByte: e,
            text: t,
          );
        case 'ArrowFunctionExpression':
          final ft = ex['function_text'] as String? ?? t;
          return FunctionExpressionInvocation(
            functionText: ft,
            argumentList: const ArgumentList(arguments: []),
            startByte: s,
            endByte: e,
            text: t,
          );
        case 'ArrayExpression':
          final xs = (ex['elements'] as List<dynamic>? ?? const [])
              .map((el) => fromExprOut(el as Map<String, dynamic>, s, e))
              .toList();
          return ListLiteral(startByte: s, endByte: e, text: t, elements: xs);
        case 'ObjectExpression':
          final props = <MapLiteralEntry>[];
          for (final p in (ex['properties'] as List<dynamic>? ?? const [])) {
            final pm = p as Map<String, dynamic>;
            String computeKeyText(Map<String, dynamic>? key) {
              if (key == null) return '';
              final kt = key['type'] as String? ?? '';
              switch (kt) {
                case 'Identifier':
                  return key['name'] as String? ?? '';
                case 'StringLiteral':
                  return key['value'] as String? ?? '';
                case 'NumberLiteral':
                  final v = key['value'];
                  return v == null ? '' : v.toString();
                case 'BigIntLiteral':
                  return key['value'] as String? ?? '';
                default:
                  return '';
              }
            }
            final keyExpr = pm['key'] as Map<String, dynamic>?;
            final keyText = computeKeyText(keyExpr);
            final valExpr = fromExprOut(
              pm['value'] as Map<String, dynamic>,
              s,
              e,
            );
            props.add(
              MapLiteralEntry(
                keyText: keyText,
                value: valExpr,
                startByte: s,
                endByte: e,
              ),
            );
          }
          return SetOrMapLiteral(
            startByte: s,
            endByte: e,
            text: t,
            elements: props,
          );
        default:
          return Identifier(startByte: s, endByte: e, text: t);
      }
    }

    return fromExprOut(expr, start, end);
  } catch (_) {
    // 安全回退：保留原文本
    return Identifier(startByte: start, endByte: end, text: t);
  }
}
