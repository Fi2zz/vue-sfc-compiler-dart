import 'package:vue_sfc_parser/sfc_descriptor.dart';

// import 'package:vue_sfc_parser/result.dart';
import 'ts_ast.dart';
import 'ts_parser.dart';

class SetupResult {
  final CompilationUnit compilation;
  final AstNode rootAst;
  final String source;
  final String filename;
  // Normal <script> default export object text to merge into component options
  final String? normalScriptSpreadText;
  // Normal <script> import lines to include in output
  final List<String>? normalScriptImportLines;
  // <script setup> import lines to include in output
  final List<String>? setupImportLines;
  String get name => _inferComponentName(filename);
  SetupResult({
    required this.compilation,
    required this.rootAst,
    required this.source,
    required this.filename,
    this.normalScriptSpreadText,
    this.normalScriptImportLines,
    this.setupImportLines,
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
