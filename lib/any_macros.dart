import 'package:vue_sfc_parser/errors.dart';

import 'ast.dart';
import 'sfc_script_codegen_helpers.dart';

class AnyMacros {
  bool? _defineModel;
  bool? _defineOptions;
  bool? _defineProps;
  bool? _withDefault;
  bool? _defineExpose;
  bool? _defineSlots;
  bool? _defineEmits;

  void setDefineModel(String value) {
    _defineModel ??= CodegenHelpers.isDefineModel(value);
  }

  void setDefineOptions(String value) {
    _defineOptions = CodegenHelpers.isDefineOptions(value);
  }

  void setDefineProps(String value) {
    _defineProps ??= CodegenHelpers.isDefineOptions(value);
  }

  void setWithDefault(String value) {
    _withDefault ??= CodegenHelpers.isWithDefaults(value);
  }

  void setDefineExpose(String value) {
    _defineExpose ??= CodegenHelpers.isDefineExpose(value);
  }

  void setDefineSlots(String value) {
    _defineSlots ??= CodegenHelpers.isDefineSlots(value);
  }

  void setDefineEmits(String value) {
    _defineEmits ??= CodegenHelpers.isDefineEmits(value);
  }

  set defineProps(bool val) {
    _defineProps = val;
  }

  bool get defineModel => _defineModel == true;
  bool get defineOptions => _defineOptions == true;
  bool get defineProps => _defineProps == true;
  bool get withDefault => _withDefault == true;
  bool get defineExpose => _defineExpose == true;
  bool get defineSlots => _defineSlots == true;
  bool get defineEmits => _defineEmits == true;

  // AnyMacros();

  @override
  String toString() {
    return """
    defineOptions:$_defineOptions
    defineModel:$_defineModel
    defineExpose:$_defineExpose
    defineSlots:$_defineSlots
    defineEmits:$_defineEmits
    defineProps:$_defineProps
    withDefault:$_withDefault
    """
        .trim();
  }
}

AnyMacros anyVueMarcos(CompilationUnit unit) {
  AnyMacros macros = AnyMacros();

  for (final node in unit.statements) {
    Identifier? id = vueMarco(node.expression);
    if (id != null) {
      macros.setDefineModel(id.name.trim());
      macros.setDefineEmits(id.name.trim());
      macros.setDefineExpose(id.name.trim());
      macros.setDefineOptions(id.name.trim());
      macros.setDefineProps(id.name.trim());
      macros.setWithDefault(id.name.trim());
      if (macros.withDefault == true) {
        macros.defineProps = withDefault(node.expression);
      }
    }
  }

  return macros;
}

bool maybeWithDefault(Expression? exp) {
  if (exp == null) return false;
  if (exp is! FunctionCallExpression) return false;

  Identifier? id = vueMarco(exp);
  if (id == null) return false;
  bool cond1 = CodegenHelpers.isWithDefaults(id.name);
  if (cond1 == true) {
    ArgumentList argumentList = exp.argumentList;
    List<Expression> arguments = argumentList.arguments;
    if (arguments.isEmpty) {
      throw WithDefaultsRequiredDefineProps();
    } else {
      Identifier first = arguments.first as Identifier;
      bool matched = CodegenHelpers.isDefineProps(first.name);
      if (!matched) throw WithDefaultsRequiredDefineProps();
      return true;
    }
  }
  return CodegenHelpers.isDefineProps(id.name);
}

bool withDefault(Expression? exp) {
  if (exp == null) return false;
  if (exp is! FunctionCallExpression) return false;
  ArgumentList argumentList = exp.argumentList;
  List<Expression> arguments = argumentList.arguments;
  if (arguments.isEmpty) {
    throw WithDefaultsRequiredDefineProps();
  }
  Identifier first = arguments.first as Identifier;
  bool matched = CodegenHelpers.isDefineProps(first.name);
  if (!matched) throw WithDefaultsRequiredDefineProps();
  return true;
}

bool isVueMarcoCall(Expression expression) {
  Identifier? identifier = vueMarco(expression);
  if (identifier == null) return false;
  return CodegenHelpers.isVueMacroIdentifier(identifier);
}

Identifier? vueMarco(Expression expression) {
  Identifier? identifier;
  if (expression is FunctionCallExpression) {
    identifier = expression.methodName;
  } else if (expression is VariableDeclaration) {
    final init = expression.init;
    if (init is FunctionCallExpression) identifier = init.methodName;
  }
  return identifier;
}
