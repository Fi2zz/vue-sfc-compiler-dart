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

class DuplicateDefineSlotsError extends SfcError {
  @override
  String? get message =>
      "Single file component can contain only one defineSlots() call.";

  DuplicateDefineSlotsError({required super.locStart, required super.locEnd});
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
  final String line1;
  final String caret1;
  final String line2;
  final String caret2;
  final String line3;
  final int? line;
  final int? column;
  SfcCompileError({
    required this.filename,
    required this.reason,
    required this.line1,
    required this.caret1,
    required this.line2,
    required this.caret2,
    required this.line3,
    required super.locStart,
    required super.locEnd,
    this.line,
    this.column,
  }) : super(message: reason);

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('[vue/compiler-sfc] $reason');
    buf.writeln('');
    String fn = filename;
    if (fn.startsWith('./')) fn = fn.substring(2);
    final locSuffix = (line != null && column != null) ? ':$line:$column' : '';
    buf.writeln('./$fn$locSuffix');
    buf.writeln(line1);
    buf.writeln(caret1);
    buf.writeln(line2);
    buf.writeln(caret2);
    buf.writeln(line3);
    return buf.toString();
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
