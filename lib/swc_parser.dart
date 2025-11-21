import 'dart:convert';
import 'swc_ffi.dart';
import 'swc_ast.dart';

class SwcParser {
  final SwcFFI _ffi = SwcFFI.load();

  Module parse({required String code, required String language}) {
    final tsx = language == 'tsx';
    final jsonStr = _ffi.parse(code, tsx: tsx, keepComments: true);
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;
    if (decoded.containsKey('error')) {
      throw StateError('SWC parse error: ${decoded['error']}');
    }
    return swcModuleFromJson(decoded);
  }

  Map<String, dynamic> parseExpr({
    required String code,
    required String language,
  }) {
    final tsx = language == 'tsx';
    final jsonStr = _ffi.parseExpr(code, tsx: tsx);
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;
    if (decoded.containsKey('error')) {
      throw StateError('SWC parse expr error: ${decoded['error']}');
    }
    return decoded;
  }
}
