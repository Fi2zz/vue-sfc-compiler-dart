// English comments per ~/REPO rule.
// Smoke tests for the oxc FFI bindings (lib/ts_syntax/oxc_ffi.dart).

import 'package:test/test.dart';
import 'package:vue_sfc_parser/ts_syntax/oxc_ffi.dart';

void main() {
  late OxcFFI oxc;

  setUpAll(() {
    oxc = OxcFFI.load();
  });

  test('parses a const declaration with byte offsets', () {
    final payload = oxc.parseJson('const a = 1;', 'ts');
    final body = payload['program']['body'] as List;
    final decl = body.single as Map<String, dynamic>;
    expect(decl['type'], 'VariableDeclaration');
    expect(decl['start'], 0);
    expect(decl['end'], 12);
  });

  test('parses TS type syntax', () {
    final payload = oxc.parseJson(
      "interface P { readonly x?: string[] }",
      'ts',
    );
    final body = payload['program']['body'] as List;
    expect((body.single as Map)['type'], 'TSInterfaceDeclaration');
  });

  test('parses TSX when language is tsx', () {
    final payload = oxc.parseJson('const x = <div a={1}/>;', 'tsx');
    expect(payload['ok'], true);
  });

  test('emits comments alongside the program', () {
    final payload = oxc.parseJson('const a = 1; // hi', 'ts');
    final comments = payload['comments'] as List;
    expect(comments, hasLength(1));
    expect((comments.single as Map)['kind'], 'line');
  });

  test('throws OxcParseException when the parser panics', () {
    expect(
      () => oxc.parseJson('const = ;', 'ts'),
      throwsA(
        isA<OxcParseException>()
            .having((e) => e.start, 'start', 6)
            .having((e) => e.message, 'message', isNotEmpty),
      ),
    );
  });

  test('tolerates semantic errors like duplicate default exports', () {
    const code = 'export default {}\nexport default {}';
    final payload = oxc.parseJson(code, 'js');
    expect(payload['ok'], true);
    final body = payload['program']['body'] as List;
    expect(body, hasLength(2));
    final diagnostics = payload['diagnostics'] as List;
    expect(diagnostics, isNotEmpty);
    expect((diagnostics.first as Map)['error'], isNotEmpty);
  });
}
