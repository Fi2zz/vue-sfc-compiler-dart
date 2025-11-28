import 'package:vue_sfc_parser/code_printer.dart';
import 'package:vue_sfc_parser/extract_macro_binding.dart';
import 'package:vue_sfc_parser/logger.dart';
import 'package:vue_sfc_parser/ast.dart';
import 'package:vue_sfc_parser/sfc_compiler.dart';
import 'package:vue_sfc_parser/errors.dart';
import 'package:vue_sfc_parser/sfc_script_codegen_helpers.dart';
import 'any_macros.dart';

class DefinedModels {
  final List<String> models;
  final List<String> events;
  final Map<String, String> bindings;
  final _seen = <String>{};
  final List<String> modifers = [];

  // final List<String> =[];
  bool get isNotEmpty => models.isNotEmpty || events.isNotEmpty;
  String get modelUpdateEvents =>
      events.isNotEmpty ? "[${events.join(', ')}]" : '[]';
  void addModel(String modelName, String propEntry) {
    if (!_seen.contains(modelName)) {
      _seen.add(modelName);
      final modiferKey = CodegenHelpers.getModelModifiersName(modelName);
      final eventKey = CodegenHelpers.getModelUpdateEventName(modelName);
      models.add(propEntry);
      events.add(eventKey);
      models.add('$modiferKey: {}');
    }
  }

  void addBinding(String modelName, String? bound) {
    //  const modelName = defineModel()
    if (bound != null && bound.isNotEmpty) bindings[bound] = modelName;
  }

  DefinedModels({
    required this.models,
    required this.events,
    required this.bindings,
  });
}

SetOrMapLiteral? firstObjectArg(FunctionCallExpression call) {
  for (final a in call.argumentList.arguments) {
    if (a is SetOrMapLiteral) return a;
  }
  return null;
}

String? firstStringArg(FunctionCallExpression call) {
  for (final a in call.argumentList.arguments) {
    if (a is StringLiteral) return '"${a.stringValue}"';
  }
  return null;
}

String normalizeObjectText(String text) {
  var t = text.trim();
  t = t.replaceAll("'", '"');
  t = t.split('\n').map((l) => l.trimLeft()).join('\n');
  return t;
}

final class ScriptCodegen {
  static String generate({required Prepared prepared}) {
    final generated = <String>[];
    final setupBody = <String>[];
    final unit = prepared.setup;
    if (unit.exported.isNotEmpty) throw SetupExportError();
    final models = extractDefineModel(unit);
    // ignore: unused_local_variable
    final slots = CodegenHelpers.walkDefineSlots(unit);
    final emits = CodegenHelpers.walkDefineEmits(unit);
    // ignore: unused_local_variable
    final exposes = CodegenHelpers.walkDefineExposes(unit);

    AnyMacros macros = anyVueMarcos(unit);

    final hasDefineExpose = macros.defineExpose;
    final hasDefineEmits = macros.defineEmits;
    final hasDefineModels = macros.defineModel;
    final hasDefineProps = macros.defineProps;
    print(macros);

    final setupUnits = prepared.setup;
    final List<String> aliases = <String>[];
    final needsMergeModels =
        hasDefineModels && hasDefineProps || hasDefineEmits;
    if (hasDefineModels) aliases.add(CodegenHelpers.useModel);
    final hasSlots = CodegenHelpers.walkDefineSlots(setupUnits).isNotEmpty;
    if (hasSlots) aliases.add(CodegenHelpers.useSlots);
    if (needsMergeModels) aliases.add(CodegenHelpers.mergeModels);
    if (prepared.isTypescript) aliases.add(CodegenHelpers.defineComponent);
    generated.add(CodegenHelpers.importFromVue(aliases));
    for (final line in prepared.setup.imported) {
      generated.add(CodePrinter.print(line));
    }

    String? normalScript;
    if (prepared.normal != null) {
      final normal = prepared.normal!;
      for (final line in normal.imported) {
        generated.add(CodePrinter.print(line));
      }

      for (final node in normal.statements) {
        if (node.declaration != null &&
            node.declaration is ExportDefaultDeclaration) {
          normalScript = CodePrinter.print(
            node,
          ).toString().replaceAll('export default', '').trim();
          generated.add(CodegenHelpers.defineNormalScriptDefault(normalScript));
          setupBody.add('...${CodegenHelpers.normalScriptDefault},');
        } else {
          final t = node.text;
          if (t.trim().isNotEmpty) {
            generated.add(t);
          } else {
            generated.add(CodePrinter.print(node));
          }
        }
      }
    }

    // normal default export embedding
    if (normalScript != null && normalScript.isNotEmpty) {}

    // options
    if (macros.defineOptions) {
      final defineOptions = extractDefineOptions(unit);
      logger.warn(CodePrinter.print(ArgumentList(arguments: defineOptions)));

      setupBody.add(
        "...${CodePrinter.print(ArgumentList(arguments: defineOptions))},",
      );
    }

    // props
    final propsMerge = <String>[];
    if (hasDefineProps) {
      final props = CodegenHelpers.extractDefineProps(unit);
      if (props != null) propsMerge.add(props.substring(1, props.length - 1));
    }
    if (hasDefineModels) propsMerge.add(models.models.join(', '));
    logger.warn('[propsMerge] $propsMerge');

    if (propsMerge.isNotEmpty) {
      setupBody.add(CodegenHelpers.mergeProps(propsMerge));
    }
    if (hasDefineModels) {
      // setupBody.add(
      //   CodegenHelpers.mergeEmits([emits.join(','), models.modelUpdateEvents]),
      // );
    } else if (emits.isNotEmpty) {
      setupBody.add(CodegenHelpers.mergeEmits([emits.join(',')]));
    }

    setupBody.add(
      CodegenHelpers.setupStart(prepared.isTypescript, hasDefineEmits),
    );
    if (!hasDefineExpose) setupBody.add(CodegenHelpers.expose(null));
    if (propsMerge.isNotEmpty) {
      // setupBody.add(CodegenHelpers.setupProps)
    }

    final ordered = <String>[];
    Set<String> pushed = {};
    for (final node in setupUnits.statements) {
      if (canPrint(node)) {
        if (node.expression is FunctionCallExpression) {
          // printArgNames(node);
          logger.warn(
            CodePrinter.print(
              ArgumentList(
                arguments: (node.expression as FunctionCallExpression)
                    .argumentList
                    .arguments,
              ),
            ),
          );
        }

        if (!isVueMarcoCall(node.expression)) {
          setupBody.add(CodePrinter.print(node));
          if (node.declaration != null) {
            if (node.declaration is VariableDeclaration) {
              String varName = CodePrinter.print(
                (node.declaration as VariableDeclaration).name,
              );
              if (!pushed.contains(varName)) {
                ordered.add(varName);
                pushed.add(varName);
              }
            }

            // if (node.declaration is FunctionDeclaration) {
            //   String varName = CodePrinter.print(
            //     (node.expression as FunctionDeclaration).id!,
            //   );
            //   if (!pushed.contains(varName)) {
            //     ordered.add(varName);
            //     pushed.add(varName);
            //   }
            // }
          } else if (node.expression is FunctionDeclaration) {
            String varName = CodePrinter.print(
              (node.expression as FunctionDeclaration).id!,
            );

            logger.error('varName $varName');
            // if (!pushed.contains(varName)) {
            ordered.add(varName);
            pushed.add(varName);
            // }
            // logger.warn(
            //   '[setup node] ${node.expression} ${node.declaration} ${CodePrinter.print(node)}',
            // );
          }
        } else {
          // logger.warn(CodePrinter.print(node));
          // FunctionCallExpression exp =
          // node.expression as FunctionCallExpression;

          // exp.argumentList.arguments.forEach((node) {
          //   if (node is SetOrMapLiteral) {
          //     for (final n in node.elements) {
          //       print(n.keyText );
          //     }
          //     // print(node.elements);
          //   }
          // });
          // print(exp.argumentList),;
        }
      }
    }

    // return '';

    // returns
    for (final s in CodegenHelpers.returns(ordered)) {
      setupBody.add(s);
    }
    for (final s in CodegenHelpers.defineProperty()) {
      setupBody.add(s);
    }
    setupBody.add(CodegenHelpers.setupReturns);
    generated.add(CodegenHelpers.component(prepared.isTypescript, setupBody));
    return generated.join('\n');
  }
}

String formaltLine(String kind, String id, String bound) {
  return "$kind $id = $bound;\n";
}

bool canPrint(ExpressionStatement node) {
  Expression expression = node.expression;
  return expression is! ExportAllDeclartion &&
      expression is! ExportDefaultDeclaration &&
      expression is! ExportNamedDeclaration &&
      expression is! ImportExpression &&
      expression is! ImportDeclaration;
}

String? extractPropsBinding(ExpressionStatement node) {
  Expression expression = node.expression;

  if (expression is FunctionCallExpression) {
    return null;
  }
  if (expression is VariableDeclaration) {
    Expression? expInit = expression.init;
    if (expInit is FunctionCallExpression) {
      String name = CodePrinter.print(expInit);
      logger.warn('isWithDefaults $name');
    }
  }

  return null;
}
