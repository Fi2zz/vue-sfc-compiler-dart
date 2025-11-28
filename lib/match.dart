// ==========================================
// 手动解构框架
// ==========================================
typedef Guard<T> = bool Function(T);
typedef MatchFn<T, R> = R Function(T);

class Pattern<T, R> {
  final Map<String, dynamic> _shape; // 要抽取的字段
  final Guard<Map>? _guard; // 额外条件
  final MatchFn<Map, R> _then; // 匹配成功后的计算

  const Pattern(this._shape, this._then, [this._guard]);

  bool _matches(Map input) {
    // 1. 字段存在且类型一致
    for (final e in _shape.entries) {
      final v = input[e.key];
      if (v == null || (e.value != dynamic && v.runtimeType != e.value)) {
        return false;
      }
    }
    // 2. guard 通过
    return _guard?.call(input) ?? true;
  }
}

R match<T extends Map, R>(T input, List<Pattern<T, R>> patterns) {
  for (final p in patterns) {
    if (p._matches(input)) {
      return p._then(input);
    }
  }
  throw StateError('no pattern matched');
}

// ==========================================
// 业务使用示例
// ==========================================
void main() {
  final persons = [
    {
      'name': 'Andrew',
      'age': 26,
      'tags': ['vip', 'coder'],
    },
    {'name': 'Lisa', 'age': 17},
    {'name': 'Bob', 'age': 30},
  ];

  for (final p in persons) {
    final result = match(
      p,
      [
        // 1. 成年人且 name 是 Andrew
        Pattern(
          {'name': String, 'age': int},
          (m) => 'hello adult Andrew, age=${m['age']}',
          (m) => m['name'] == 'Andrew' && m['age'] >= 18,
        ),
        // 2. 任意成年人
        Pattern(
          {'age': int},
          (m) => 'adult ${m['name'] ?? 'unknown'}',
          (m) => m['age'] >= 18,
        ),
        // 3. 默认
        Pattern({}, (m) => 'minor'),
      ].cast<Pattern<Map<String, Object>, dynamic>>(),
    );
    print(result);
  }
}
