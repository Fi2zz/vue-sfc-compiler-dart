import 'package:vue_sfc_parser/sfc_error.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';
import 'package:vue_sfc_parser/ts_ast.dart';
import 'package:vue_sfc_parser/ts_parser.dart';

void validateUsage({
  required AstNode rootAst,
  required CompilationUnit unit,
  required String src,
  required String filename,
}) {
  // Only disallow `export default` inside <script setup>; allow named exports
  int defaultExportStart = -1;
  int defaultExportEnd = -1;
  void scanExport(AstNode n) {
    if (n.type.contains('export')) {
      final text = slice(src, n.startByte, n.endByte);
      if (RegExp(r'export\s+default').hasMatch(text)) {
        defaultExportStart = n.startByte;
        defaultExportEnd = n.endByte;
        return;
      }
    }
    for (final c in n.children) {
      if (defaultExportStart >= 0) return;
      scanExport(c);
    }
  }

  scanExport(rootAst);
  if (defaultExportStart >= 0) {
    throw SfcCompileError(
      filename: filename,
      reason: '<script setup> cannot contain `export default`.',
      line1: '1 | <script setup lang="ts">',
      caret1: ' | ^',
      line2: '2 | export default {...}',
      caret2: ' | ^^^^^^^^^^^^^^^^^^^^^',
      line3: '3 | </script>',
      locStart: defaultExportStart,
      locEnd: defaultExportEnd,
    );
  }

  // defineSlots() cannot accept runtime arguments
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'defineSlots') {
      if (e.argumentList.arguments.isNotEmpty) {
        final lines = renderErrorThreeLines(src, 'defineSlots({})');
        throw SfcCompileError(
          filename: filename,
          reason: 'defineSlots() cannot accept arguments',
          line1: lines[0],
          caret1: lines[1],
          line2: lines[2],
          caret2: lines[3],
          line3: lines[4],
          locStart: st.startByte,
          locEnd: st.endByte,
        );
      }
    }
  }

  // withDefaults must wrap defineProps with type arguments
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'withDefaults') {
      if (e.argumentList.arguments.isEmpty) {
        final lines = renderErrorThreeLines(
          src,
          'withDefaults(defineProps(), {})',
        );
        throw SfcCompileError(
          filename: filename,
          reason: 'withDefaults() expects defineProps() as first argument',
          line1: lines[0],
          caret1: lines[1],
          line2: lines[2],
          caret2: lines[3],
          line3: lines[4],
          locStart: st.startByte,
          locEnd: st.endByte,
        );
      }
      final first = e.argumentList.arguments.first;
      if (first is! FunctionCallExpression ||
          first.methodName.name != 'defineProps') {
        throw ScriptError(
          message:
              'Vue Compile Error: [@vue/compiler-sfc] withDefaults() expects defineProps() as first argument',
          locStart: st.startByte,
          locEnd: st.endByte,
        );
      }
      if (first.typeArgumentProps.isEmpty) {
        final lines = renderErrorThreeLines(
          src,
          'withDefaults(defineProps({}), {})',
        );
        throw SfcCompileError(
          filename: filename,
          reason: 'withDefaults() only works with typed defineProps()',
          line1: lines[0],
          caret1: lines[1],
          line2: lines[2],
          caret2: lines[3],
          line3: lines[4],
          locStart: st.startByte,
          locEnd: st.endByte,
        );
      }
    }
  }

  // defineProps cannot provide both type args and runtime object
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'defineProps') {
      final hasObj = firstObjectArg(e) != null;
      final hasType = e.typeArgumentProps.isNotEmpty;
      if (hasObj && hasType) {
        final lines = renderErrorThreeLines(
          src,
          'defineProps<{ a: number }>({ a: Number })',
        );
        throw SfcCompileError(
          filename: filename,
          reason:
              'defineProps() cannot mix type arguments with runtime props object',
          line1: lines[0],
          caret1: lines[1],
          line2: lines[2],
          caret2: lines[3],
          line3: lines[4],
          locStart: st.startByte,
          locEnd: st.endByte,
        );
      }
    }
  }

  // Duplicate macro usage checks
  int propsCount = 0;
  int emitsCount = 0;
  int optionsCount = 0;
  final modelNames = <String>{};
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is! FunctionCallExpression) continue;
    switch (e.methodName.name) {
      case 'defineProps':
        propsCount++;
        break;
      case 'defineEmits':
        emitsCount++;
        break;
      case 'defineOptions':
        optionsCount++;
        break;
      case 'defineModel':
        final name = firstStringArg(e) ?? '"modelValue"';
        final raw = name.replaceAll('"', '');
        if (modelNames.contains(raw)) {
          final lines = renderErrorThreeLines(src, 'defineModel("$raw")');
          throw SfcCompileError(
            filename: filename,
            reason: 'duplicate defineModel name: $raw',
            line1: lines[0],
            caret1: lines[1],
            line2: lines[2],
            caret2: lines[3],
            line3: lines[4],
            locStart: st.startByte,
            locEnd: st.endByte,
          );
        }
        modelNames.add(raw);
        break;
    }
  }
  if (propsCount > 1) {
    final lines = renderErrorThreeLines(src, 'defineProps() x 2');
    throw SfcCompileError(
      filename: filename,
      reason: 'duplicate defineProps() calls are not allowed',
      line1: lines[0],
      caret1: lines[1],
      line2: lines[2],
      caret2: lines[3],
      line3: lines[4],
      locStart: unit.startByte,
      locEnd: unit.endByte,
    );
  }
  if (emitsCount > 1) {
    final lines = renderErrorThreeLines(src, 'defineEmits() x 2');
    throw SfcCompileError(
      filename: filename,
      reason: 'duplicate defineEmits() calls are not allowed',
      line1: lines[0],
      caret1: lines[1],
      line2: lines[2],
      caret2: lines[3],
      line3: lines[4],
      locStart: unit.startByte,
      locEnd: unit.endByte,
    );
  }
  if (optionsCount > 1) {
    final lines = renderErrorThreeLines(src, 'defineOptions() x 2');
    throw SfcCompileError(
      filename: filename,
      reason: 'duplicate defineOptions() calls are not allowed',
      line1: lines[0],
      caret1: lines[1],
      line2: lines[2],
      caret2: lines[3],
      line3: lines[4],
      locStart: unit.startByte,
      locEnd: unit.endByte,
    );
  }

  // defineEmits mixed type/object/array error + invalid type signatures
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'defineEmits') {
      final hasType =
          (e.typeArgumentText != null && e.typeArgumentText!.isNotEmpty);
      final hasObj = firstObjectArg(e) != null;
      final hasArr = firstArrayArg(e) != null;
      if (hasType && (hasObj || hasArr)) {
        final lines = renderErrorThreeLines(src, 'defineEmits<...>(...)');
        throw SfcCompileError(
          filename: filename,
          reason: 'defineEmits() cannot mix type arguments with runtime args',
          line1: lines[0],
          caret1: lines[1],
          line2: lines[2],
          caret2: lines[3],
          line3: lines[4],
          locStart: st.startByte,
          locEnd: st.endByte,
        );
      }
      if (hasType) {
        final t = e.typeArgumentText!.replaceAll(RegExp(r'[<>]'), '');
        final hasFnSig = RegExp(r'\(\s*[A-Za-z_\$]').hasMatch(t);
        final hasPropSig = RegExp(r'[A-Za-z_\$]\\w*\s*:').hasMatch(t);
        if (hasPropSig && !hasFnSig) {
          final lines = renderErrorThreeLines(src, 'defineEmits<{ a: any }>()');
          throw SfcCompileError(
            filename: filename,
            reason:
                'defineEmits() type must be function signatures, not properties',
            line1: lines[0],
            caret1: lines[1],
            line2: lines[2],
            caret2: lines[3],
            line3: lines[4],
            locStart: st.startByte,
            locEnd: st.endByte,
          );
        }
      }
    }
  }

  // defineOptions: forbid type args and props/emits keys inside object
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'defineOptions') {
      if (e.typeArgumentText != null && e.typeArgumentText!.isNotEmpty) {
        final lines = renderErrorThreeLines(src, 'defineOptions<{}>({})');
        throw SfcCompileError(
          filename: filename,
          reason: 'defineOptions() does not accept type arguments',
          line1: lines[0],
          caret1: lines[1],
          line2: lines[2],
          caret2: lines[3],
          line3: lines[4],
          locStart: st.startByte,
          locEnd: st.endByte,
        );
      }
      final obj = firstObjectArg(e);
      if (obj != null) {
        for (final m in obj.elements) {
          if (m.keyText == 'props' || m.keyText == 'emits') {
            final lines = renderErrorThreeLines(
              src,
              'defineOptions({ props: {...} })',
            );
            throw SfcCompileError(
              filename: filename,
              reason: 'defineOptions() cannot contain `props` or `emits` keys',
              line1: lines[0],
              caret1: lines[1],
              line2: lines[2],
              caret2: lines[3],
              line3: lines[4],
              locStart: st.startByte,
              locEnd: st.endByte,
            );
          }
        }
      }
    }
  }
}
