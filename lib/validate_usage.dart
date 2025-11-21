import 'package:vue_sfc_parser/generate_code_frame.dart';
import 'package:vue_sfc_parser/sfc_error.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';

void validateUsage({
  required CompilationUnit unit,
  required String src,
  required String filename,
}) {
  // Validate variable declaration kind presence for SWC-originated declarations
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is VariableDeclaration) {
      final needsKind = e.init != null || e.pattern != null;
      if (needsKind) {
        final k = e.declKind;
        if (k == null || (k != 'const' && k != 'let' && k != 'var')) {
          final lc = computeLineCol(src, st.startByte);
          throw SfcCompileError(
            filename: filename,
            reason: 'missing or invalid variable declaration kind (const/let/var)',
            line1: generateCodeFrame(src, st.startByte, st.endByte)[0],
            caret1: generateCodeFrame(src, st.startByte, st.endByte)[1],
            line2: generateCodeFrame(src, st.startByte, st.endByte)[2],
            caret2: generateCodeFrame(src, st.startByte, st.endByte)[3],
            line3: generateCodeFrame(src, st.startByte, st.endByte)[4],
            locStart: st.startByte,
            locEnd: st.endByte,
            line: lc[0],
            column: lc[1],
          );
        }
      }
    }
  }
  // defineSlots() cannot accept runtime arguments
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'defineSlots') {
      if (e.argumentList.arguments.isNotEmpty) {
        final lines = generateCodeFrame(src, st.startByte, st.endByte);
        final lc = computeLineCol(src, st.startByte);
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
          line: lc[0],
          column: lc[1],
        );
      }
    }
  }

  // withDefaults must wrap defineProps with type arguments
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'withDefaults') {
      if (e.argumentList.arguments.isEmpty) {
        final lines = generateCodeFrame(src, st.startByte, st.endByte);
        final lc = computeLineCol(src, st.startByte);
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
          line: lc[0],
          column: lc[1],
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
        final lines = generateCodeFrame(src, st.startByte, st.endByte);
        final lc = computeLineCol(src, st.startByte);
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
          line: lc[0],
          column: lc[1],
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
        final lines = generateCodeFrame(src, st.startByte, st.endByte);
        final lc = computeLineCol(src, st.startByte);
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
          line: lc[0],
          column: lc[1],
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
          final lines = generateCodeFrame(src, st.startByte, st.endByte);
          final lc = computeLineCol(src, st.startByte);
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
            line: lc[0],
            column: lc[1],
          );
        }
        modelNames.add(raw);
        break;
    }
  }
  if (propsCount > 1) {
    final lines = generateCodeFrame(src, unit.startByte, unit.endByte);
    final lc = computeLineCol(src, unit.startByte);
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
      line: lc[0],
      column: lc[1],
    );
  }
  if (emitsCount > 1) {
    final lines = generateCodeFrame(src, unit.startByte, unit.endByte);
    final lc = computeLineCol(src, unit.startByte);
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
      line: lc[0],
      column: lc[1],
    );
  }
  if (optionsCount > 1) {
    final lines = generateCodeFrame(src, unit.startByte, unit.endByte);
    final lc = computeLineCol(src, unit.startByte);
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
      line: lc[0],
      column: lc[1],
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
        final lines = generateCodeFrame(src, st.startByte, st.endByte);
        final lc = computeLineCol(src, st.startByte);
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
          line: lc[0],
          column: lc[1],
        );
      }
      if (hasType) {
        final t = e.typeArgumentText!.replaceAll(RegExp(r'[<>]'), '');
        final hasFnSig = RegExp(r'\(\s*[A-Za-z_\$]').hasMatch(t);
        final hasPropSig = RegExp(r'[A-Za-z_\$]\\w*\s*:').hasMatch(t);
        if (hasPropSig && !hasFnSig) {
          final lines = generateCodeFrame(src, st.startByte, st.endByte);
          final lc = computeLineCol(src, st.startByte);
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
            line: lc[0],
            column: lc[1],
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
        final lines = generateCodeFrame(src, st.startByte, st.endByte);
        final lc = computeLineCol(src, st.startByte);
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
          line: lc[0],
          column: lc[1],
        );
      }
      final obj = firstObjectArg(e);
      if (obj != null) {
        for (final m in obj.elements) {
          if (m.keyText == 'props' || m.keyText == 'emits') {
            final lines = generateCodeFrame(src, st.startByte, st.endByte);
            final lc = computeLineCol(src, st.startByte);
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
              line: lc[0],
              column: lc[1],
            );
          }
        }
      }
    }
  }

  _validateDestructureIdentifiers(unit, src, filename);
}

void _validateDestructureIdentifiers(
  CompilationUnit unit,
  String src,
  String filename,
) {
  for (final st in unit.statements) {
    final exp = st.expression;
    if (exp is VariableDeclaration && exp.pattern != null) {
      final pat = exp.pattern!;
      if (pat is ArrayBindingPattern) _checkArray(pat);
      if (pat is ObjectBindingPattern) _checkObject(pat);
    }
    // Deprecated VariableDeclarator path removed; unified VariableDeclaration covers destructure checks.
  }
}

bool _isIdentifierName(String s) {
  bool isFirstValid(int c) {
    final isAlpha = (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
    return isAlpha || c == 95 || c == 36;
  }

  bool isRestValid(int c) {
    final isAlphaNum =
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57);
    return isAlphaNum || c == 95 || c == 36;
  }

  if (s.isEmpty) return false;
  final bytes = s.codeUnits;
  if (!isFirstValid(bytes[0])) return false;
  for (var i = 1; i < bytes.length; i++) {
    if (!isRestValid(bytes[i])) return false;
  }
  return true;
}

void _checkArray(ArrayBindingPattern p) {
  for (final el in p.elements) {
    final id = el.target?.name;
    if (id != null && !_isIdentifierName(id)) {
      throw ScriptError(
        message: 'Vue Compile Error: invalid destructure identifier: $id',
        locStart: el.startByte,
        locEnd: el.endByte,
      );
    }
    if (el.nested is ArrayBindingPattern) {
      _checkArray(el.nested as ArrayBindingPattern);
    } else if (el.nested is ObjectBindingPattern) {
      _checkObject(el.nested as ObjectBindingPattern);
    }
  }
}

void _checkObject(ObjectBindingPattern p) {
  for (final prop in p.properties) {
    final alias = prop.alias?.name;
    if (alias != null && !_isIdentifierName(alias)) {
      throw ScriptError(
        message: 'Vue Compile Error: invalid destructure identifier: $alias',
        locStart: prop.startByte,
        locEnd: prop.endByte,
      );
    }
    if (prop.nested is ArrayBindingPattern) {
      _checkArray(prop.nested as ArrayBindingPattern);
    } else if (prop.nested is ObjectBindingPattern) {
      _checkObject(prop.nested as ObjectBindingPattern);
    }
  }
}
