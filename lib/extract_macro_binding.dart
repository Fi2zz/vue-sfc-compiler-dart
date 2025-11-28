import 'package:vue_sfc_parser/ast.dart';
// import 'package:vue_sfc_parser/code_printer.dart';
import 'package:vue_sfc_parser/errors.dart';
import 'package:vue_sfc_parser/sfc_script_codegen_helpers.dart';
import 'package:vue_sfc_parser/sfc_script_codegen.dart';

String props = 'props';
String emits = 'emits';
String expose = 'expose';
String slots = 'slots';
List<String> notAllowedInDefineOptions = [props, emits, expose, slots];

List<Expression> extractDefineOptions(CompilationUnit unit) {
  List<Expression> arguments = [];

  for (final st in unit.statements) {
    final exp = st.expression;
    if (exp is FunctionCallExpression &&
        CodegenHelpers.isDefineOptions(exp.methodName.name)) {
      arguments = exp.argumentList.arguments;
      break;
    }
  }

  if (arguments.isNotEmpty) {
    for (Expression arg in arguments) {
      if (arg is SetOrMapLiteral) {
        final node = arg;
        final found = node.elements.where((test) {
          return notAllowedInDefineOptions.any((key) => test.keyText == key);
        }).firstOrNull;
        if (found != null) {
          throw DefineOptionsError(type: found.keyText);
        }
      }
    }
  }
  return arguments;
}

DefinedModels extractDefineModel(CompilationUnit unit) {
  DefinedModels defines = DefinedModels(models: [], events: [], bindings: {});

  return defines;
}
