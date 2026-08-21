import 'package:vue_sfc_parser/script/script_error.dart';

class SfcError implements Exception {
  final String? message;
  final int locStart;
  final int locEnd;

  SfcError({this.message, required this.locStart, required this.locEnd});

  @override
  String toString() {
    return 'SfcParserError: $message (loc: $locStart-$locEnd)';
  }
}

class DuplicateBlockError extends SfcError {
  String type;

  @override
  get message => "Single file component can contain only one <$type> element";

  DuplicateBlockError({
    required this.type,
    required super.locStart,
    required super.locEnd,
  });
}

class ScriptError extends SfcError {
  ScriptError({
    required super.message,
    required super.locStart,
    required super.locEnd,
  });
}

class SfcCompileError extends SfcError {
  final String filename;
  final String reason;
  final String source; // full SFC source for the code frame
  SfcCompileError({
    required this.filename,
    required this.reason,
    required this.source,
    required super.locStart,
    required super.locEnd,
  }) : super(message: reason);

  @override
  String toString() {
    String fn = filename;
    if (fn.startsWith('./')) fn = fn.substring(2);
    return 'Vue Compile Error: [vue/compiler-sfc] $reason\n\n'
        './$fn\n${generateCodeFrame(source, locStart, locEnd)}';
  }
}

class MissingTemplateOrScript extends SfcError {
  @override
  String? get message =>
      " At least one <template> or <script setup> is required in a single file component. $filename";

  String filename;

  MissingTemplateOrScript({
    required super.locStart,
    required super.locEnd,
    required this.filename,
  });
}

class ScriptSetupAttributeError extends SfcError {
  @override
  String? get message => """
  <script setup> cannot use the "src" attribute because 
  its syntax will be ambiguous outside of the component.
""";

  ScriptSetupAttributeError({required super.locStart, required super.locEnd});
}

class ScriptLangMismatchError extends SfcError {
  @override
  String? get message => """
  <script> and <script setup> must use the same "lang" attribute.
""";

  ScriptLangMismatchError({required super.locStart, required super.locEnd});
}

class ScriptSrcAttributeError extends SfcError {
  @override
  String? get message => """
   <script> cannot use the "src" attribute when <script setup> is also present because they must be processed together.
""";

  ScriptSrcAttributeError({required super.locStart, required super.locEnd});
}
