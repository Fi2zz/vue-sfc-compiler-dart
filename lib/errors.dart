class SfcError implements Exception {
  final String? message;
  SfcError({this.message});

  @override
  String toString() {
    return '[@vue/compiler-sfc] $message';
  }
}

class DuplicateBlockError extends SfcError {
  String type;

  @override
  get message => "Single file component can contain only one <$type> element";

  DuplicateBlockError({required this.type});
}

class DuplicateDefineSlotsError extends SfcError {
  @override
  String? get message =>
      "Single file component can contain only one defineSlots() call.";
}

class SetupExportError extends SfcError {
  @override
  String? get message =>
      "<script setup> cannot contain ES module exports. If you are using a previous version of <script setup>, please consult the updated RFC at https://github.com/vuejs/rfcs/pull/227.";
}

class ScriptError extends SfcError {
  ScriptError({required super.message});
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

class WithDefaultsRequiredDefineProps extends SfcError {
  @override
  String get message =>
      "withDefaults' first argument must be a defineProps call.";
}

class MissingTemplateOrScript extends SfcError {
  @override
  String? get message =>
      " At least one <template> or <script setup> is required in a single file component. $filename";

  String filename;

  MissingTemplateOrScript({required this.filename});
}

class ScriptSetupAttributeError extends SfcError {
  @override
  String? get message => """
  <script setup> cannot use the "src" attribute because 
  its syntax will be ambiguous outside of the component.
""";
}

class ScriptLangMismatchError extends SfcError {
  @override
  String? get message => """
  <script> and <script setup> must use the same "lang" attribute.
""";
}

class ScriptSrcAttributeError extends SfcError {
  @override
  String? get message => """
   <script> cannot use the "src" attribute when <script setup> is also present because they must be processed together.
""";
}

class DefineOptionsError extends SfcError {
  final String type;

  @override
  String? get message {
    if (type == 'props') {
      return "defineOptions() cannot be used to declare props. Use defineProps() instead.";
    }

    if (type == 'emits') {
      return "defineOptions() cannot be used to declare props. Use defineEmits() instead.";
    }

    if (type == 'expose') {
      return "defineOptions() cannot be used to declare props. Use defineExpose() instead.";
    }
    if (type == 'slots') {
      return "defineOptions() cannot be used to declare props. Use defineSlots() instead.";
    }
    return null;
  }

  DefineOptionsError({required this.type});
}
