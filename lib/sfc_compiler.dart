import 'package:vue_sfc_parser/sfc_descriptor.dart';

// import 'package:vue_sfc_parser/result.dart';
import 'sfc_ast.dart';

class Prepared {
  final CompilationUnit setup;
  final CompilationUnit? normal;
  // final Module setupModule;
  // final Module? normalModule;
  final String source;
  final String filename;
  // <script setup> import lines to include in output
  final String language;
  String get name => _inferComponentName(filename);
  bool get isTypescript => language == 'ts' || language == 'tsx';
  Prepared({
    this.normal,
    required this.language,
    required this.setup,
    required this.source,
    required this.filename,
  });
}

/// SFC编译结果
class CompileResult {
  final String template;
  final String script;
  final List<String> styles;
  final Map<String, dynamic> metadata;
  CompileResult({
    required this.template,
    required this.script,
    required this.styles,
    required this.metadata,
  });
}

/// 编译后的样式内容
List<String> compileStyles(SfcDescriptor descriptor) {
  return [];
}

String compileTemplate(SfcDescriptor descriptor) {
  return '';
}

String _inferComponentName(String filename) {
  final parts = filename.split('/');
  final base = parts.isNotEmpty ? parts.last : filename;
  final dot = base.lastIndexOf('.');
  return dot > 0 ? base.substring(0, dot) : base;
}
