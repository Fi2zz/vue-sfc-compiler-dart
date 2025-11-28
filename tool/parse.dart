import 'package:vue_sfc_parser/logger.dart';
import 'package:vue_sfc_parser/parse_script.dart';
import 'package:vue_sfc_parser/ast.dart';
import 'package:vue_sfc_parser/code_printer.dart';
// ignore: unused_import
import 'package:vue_sfc_parser/sfc_script_codegen.dart';
// ignore: unused_import
import 'package:vue_sfc_parser/sfc_script_codegen_helpers.dart';

String source = """
const object = {
  world: "world",
  fn1() {},
  fn2: () => {},
  fn3(param1) {},
  fn4(param1, ...more) {},
  fn5({param1}){},
  fn6({param1} ={param1:1}){},
  fn7([]){},
  fn8([param1] =['hello']){},
};
""";

void main(List<String> args) {
  final result = parseScript(source, language: 'ts');

  final unit = result.unit;

  for (final st in unit.statements) {
    // print(st.e
    // xpression);

    Expression exp = st.expression;
    if (exp is VariableDeclaration) {
      Expression? init = exp.init;
      print(init);
      print(init.runtimeType);
      if (init is ObjectExpression) {
        print('props: \'${init.properties.length}\'');
        for (final p in init.properties) {
          if (p is ObjectProperty) {
            final k = p.key is Identifier
                ? (p.key as Identifier).name
                : (p.key is StringLiteral)
                ? (p.key as StringLiteral).stringValue
                : '';
            print('prop:${k}');
          } else if (p is ObjectMethod) {
            final k = p.key is Identifier ? (p.key as Identifier).name : '';
            print('method:${k}:${p.kind} ${p.params}');
          }
        }
      }
      // logger.log(CodePrinter.print(init));

      // print(object)
    }

    if (exp is FunctionCallExpression) {
      logger.log(CodePrinter.print(exp));
    }
  }

  // logger.log(message)
  // result.unit
  // print(result.unit.statements);
}
