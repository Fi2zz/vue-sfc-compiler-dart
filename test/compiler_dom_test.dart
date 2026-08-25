// English comments per ~/REPO rule.
// Smoke tests for the compiler-dom compatibility layer (lib/compiler_dom.dart):
// default-option shape and the user nodeTransforms/directiveTransforms hooks
// (official merge order: presets first, user transforms appended/overriding).

import 'package:test/test.dart';
import 'package:vue_sfc_parser/compiler_dom.dart';
import 'package:vue_sfc_parser/template/js_nodes.dart';
import 'package:vue_sfc_parser/template/transform_context.dart';
import 'package:vue_sfc_parser/template/tmpl_ast.dart';

void main() {
  test('defaults mirror compiler-dom: function mode with with-block', () {
    final r = compile('<div>hi</div>');
    expect(r.code, contains('function render'));
    expect(r.code, contains('with (_ctx)'));
    expect(r.code, contains('createElementBlock("div"'));
  });

  test('user nodeTransforms run while presets stay active', () {
    final tags = <String>[];
    final r = compile(
      '<div v-if="ok">a</div>',
      DomCompileOptions()
        ..nodeTransforms = [
          (node, ctx) {
            if (node is ElementNode) tags.add(node.tag);
            return null;
          },
        ],
    );
    expect(tags, contains('div'));
    expect(r.code, contains('ok'), reason: 'transformIf preset must still run');
  });

  test('user directiveTransforms override the DOM default', () {
    final r = compile(
      '<p v-show="x"/>',
      DomCompileOptions()
        ..directiveTransforms = {
          'show': (dir, node, ctx) => DirTransformResult([
            createObjectProp(
              createSimpleExp('data-shown', true),
              createSimpleExp('1', true),
            ),
          ]),
        },
    );
    expect(r.code, isNot(contains('vShow')), reason: 'DOM default replaced');
    expect(r.code, contains('"data-shown": "1"'));
  });

  test('scopeId is rejected outside module mode (error 50)', () {
    const msg = '"scopeId" option is only supported in module mode.';
    expect(
      () => compile('<div/>', DomCompileOptions()..scopeId = 'data-v-test'),
      throwsA(
        isA<TmplCompileError>()
            .having((e) => e.code, 'code', 50)
            .having((e) => e.message, 'message', msg),
      ),
    );
  });

  test('scopeId compiles in module mode like the official dead plumbing', () {
    final scoped = compile(
      '<Child><template #a><p/></template></Child>',
      DomCompileOptions()
        ..mode = 'module'
        ..scopeId = 'data-v-test',
    );
    final plain = compile(
      '<Child><template #a><p/></template></Child>',
      DomCompileOptions()..mode = 'module',
    );
    // genScopeId is unused in official 3.5 codegen; only the error gate and
    // transform-context plumbing exist, so output must be identical.
    expect(scoped.code, plain.code);
    expect(scoped.code, contains('withCtx'));
  });

  test('custom delimiters rebind interpolation parsing', () {
    final r = compile(
      '{{ msg }}[[ msg ]]',
      DomCompileOptions()
        ..mode = 'module'
        ..delimiters = ('[[', ']]'),
    );
    expect(r.code, contains('{{ msg }}'), reason: 'default sign now literal');
    expect(r.code, contains('_ctx.msg'));
  });

  test('unclosed custom-delim interpolation raises error 25', () {
    expect(
      () => compile('[[ msg', DomCompileOptions()..delimiters = ('[[', ']]')),
      throwsA(
        isA<TmplCompileError>()
            .having((e) => e.code, 'code', 25)
            .having(
              (e) => e.message,
              'message',
              'Interpolation end sign was not found.',
            ),
      ),
    );
  });
}
