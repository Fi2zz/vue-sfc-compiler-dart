import 'package:test/test.dart';
import 'package:vue_sfc_parser/ast.dart';

void main() {
  group('comments placement', () {
    test('readComments preserves placement', () {
      final xs = [
        {
          'type': 'CommentLine',
          'value': 'a',
          'start': 0,
          'end': 10,
          'placement': 'leading',
        },
        {
          'type': 'CommentBlock',
          'value': 'b',
          'start': 20,
          'end': 30,
          'placement': 'inner',
        },
      ];
      final cs = readComments(xs)!;
      expect(cs.length, 2);
      expect(cs[0].placement, 'leading');
      expect(cs[1].placement, 'inner');
    });

    test('normalizeProgramJson writes placement and hoists', () {
      final m = {
        'type': 'Program',
        'body': [
          {
            'type': 'ExpressionStatement',
            'expression': {'type': 'Identifier', 'name': 'x'},
            'start': 100,
            'end': 200,
            'leadingComments': [
              {'type': 'CommentLine', 'value': 'l', 'start': 0, 'end': 50},
            ],
            'trailingComments': [
              {'type': 'CommentLine', 'value': 't', 'start': 300, 'end': 350},
            ],
          },
        ],
      };
      normalizeProgramJson(m);
      final cs = (m['comments'] as List).cast<Map<String, dynamic>>();
      expect(cs.length, 2);
      final placements = cs.map((e) => e['placement']).toList();
      expect(placements.toSet(), equals({'leading', 'trailing'}));
      final st = (m['body'] as List).first as Map<String, dynamic>;
      expect(st.containsKey('leadingComments'), isFalse);
      expect(st.containsKey('trailingComments'), isFalse);
    });
  });
}
