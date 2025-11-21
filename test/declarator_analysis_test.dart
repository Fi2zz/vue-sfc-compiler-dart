import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_ast.dart' as ts;
import 'package:vue_sfc_parser/swc_ast.dart' as swc;

void main() {
  group('TS Declarator Analysis', () {
    test('function call init', () {
      final call = ts.FunctionCallExpression(
        startByte: 0,
        endByte: 10,
        text: 'defineProps()',
        methodName: ts.Identifier(
          startByte: 0,
          endByte: 12,
          text: 'defineProps()',
        ),
        argumentList: ts.ArgumentList(
          startByte: 0,
          endByte: 12,
          text: '()',
          arguments: const [],
        ),
      );
      final decl = ts.VariableDeclaration(
        call,
        startByte: 0,
        endByte: 12,
        text: 'const props = defineProps()',
        name: ts.Identifier(startByte: 0, endByte: 5, text: 'props'),
      );
      final unit = ts.CompilationUnit(
        startByte: 0,
        endByte: 12,
        text: decl.text,
        statements: [
          ts.ExpressionStatement(
            startByte: 0,
            endByte: 12,
            text: decl.text,
            expression: decl,
          ),
        ],
      );
      final res = ts.analyzeTsDeclarators(unit);
      expect(res.length, 1);
      expect(res.first.declarationType, 'call');
      expect(res.first.initDetails['callee'], 'defineProps');
    });

    test('function expression init', () {
      final inv = ts.FunctionExpressionInvocation(
        startByte: 0,
        endByte: 10,
        text: '(x)=>x',
        functionText: '(x)=>x',
        argumentList: ts.ArgumentList(
          startByte: 0,
          endByte: 10,
          text: '',
          arguments: const [],
        ),
      );
      final decl = ts.VariableDeclaration(
        inv,
        startByte: 0,
        endByte: 10,
        text: 'const f = (x)=>x',
        name: ts.Identifier(startByte: 0, endByte: 1, text: 'f'),
      );
      final unit = ts.CompilationUnit(
        startByte: 0,
        endByte: 10,
        text: decl.text,
        statements: [
          ts.ExpressionStatement(
            startByte: 0,
            endByte: 10,
            text: decl.text,
            expression: decl,
          ),
        ],
      );
      final res = ts.analyzeTsDeclarators(unit);
      expect(res.first.declarationType, 'function_expression');
    });

    test('variable literal init', () {
      final lit = ts.StringLiteral(
        startByte: 0,
        endByte: 5,
        text: '"hi"',
        stringValue: 'hi',
      );
      final decl = ts.VariableDeclaration(
        lit,
        startByte: 0,
        endByte: 5,
        text: 'const s = "hi"',
        name: ts.Identifier(startByte: 0, endByte: 1, text: 's'),
      );
      final unit = ts.CompilationUnit(
        startByte: 0,
        endByte: 5,
        text: decl.text,
        statements: [
          ts.ExpressionStatement(
            startByte: 0,
            endByte: 5,
            text: decl.text,
            expression: decl,
          ),
        ],
      );
      final res = ts.analyzeTsDeclarators(unit);
      expect(res.first.declarationType, 'variable');
      expect(res.first.initDetails['valueType'], 'String');
    });
  });

  group('SWC Declarator Analysis', () {
    test('call init from callee_ident', () {
      final json = {
        'body': [
          {
            'type': 'VarDecl',
            'span': {
              'start': 0,
              'end': 20,
              'loc_start': {'line': 1, 'column': 0},
              'loc_end': {'line': 1, 'column': 20},
            },
            'decl_kind': 'const',
            'name': 'props',
            'name_span': {
              'start': 0,
              'end': 5,
              'loc_start': {'line': 1, 'column': 0},
              'loc_end': {'line': 1, 'column': 5},
            },
            'names': ['props'],
            'inited': true,
            'init_text': 'defineProps()',
            'init_callee_ident': 'defineProps',
            'init_type_args': null,
          },
        ],
      };
      final m = swc.swcModuleFromJson(json);
      final res = swc.analyzeSwcDeclarators(m);
      expect(res.length, 1);
      expect(res.first.declarationType, 'call');
      expect(res.first.initDetails['callee'], 'defineProps');
    });

    test('function expression via text', () {
      final json = {
        'body': [
          {
            'type': 'VarDecl',
            'span': {
              'start': 0,
              'end': 12,
              'loc_start': {'line': 1, 'column': 0},
              'loc_end': {'line': 1, 'column': 12},
            },
            'decl_kind': 'const',
            'name': 'fn',
            'name_span': {
              'start': 0,
              'end': 2,
              'loc_start': {'line': 1, 'column': 0},
              'loc_end': {'line': 1, 'column': 2},
            },
            'names': ['fn'],
            'inited': true,
            'init_text': '(x)=>x',
          },
        ],
      };
      final m = swc.swcModuleFromJson(json);
      final res = swc.analyzeSwcDeclarators(m);
      expect(res.first.declarationType, 'function_expression');
    });

    test('variable literal type', () {
      final json = {
        'body': [
          {
            'type': 'VarDecl',
            'span': {
              'start': 0,
              'end': 12,
              'loc_start': {'line': 1, 'column': 0},
              'loc_end': {'line': 1, 'column': 12},
            },
            'decl_kind': 'const',
            'name': 'x',
            'name_span': {
              'start': 0,
              'end': 1,
              'loc_start': {'line': 1, 'column': 0},
              'loc_end': {'line': 1, 'column': 1},
            },
            'names': ['x'],
            'inited': true,
            'init_text': '"hi"',
          },
        ],
      };
      final m = swc.swcModuleFromJson(json);
      final res = swc.analyzeSwcDeclarators(m);
      expect(res.first.declarationType, 'variable');
      expect(res.first.initDetails['valueType'], 'String');
    });
  });
}
