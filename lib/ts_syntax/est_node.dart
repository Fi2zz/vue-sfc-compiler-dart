// Typed input contract for OxcMapper, replacing raw Map<String, dynamic>
// payloads so JSON and binary transports share one mapper surface.
//
// EstNode keeps the bracket-access vocabulary (`node[key]`) on purpose: the
// three mapper files read ~80 distinct ESTree fields across ~400 sites and
// staying bracket-compatible makes the transport swap a pure signature
// refactor with the compiler catching every straggler. Implementations:
//   JsonEstNode - wraps an already-decoded Map (transport A / fallback)
//   BinEstNode  - cursor-backed lazy view over oxc_parse_batch_bin
//                 (keys/values resolved through interned tables, no text
//                 parsing and no materialized intermediate maps)

abstract class EstNode {
  /// Universal ESTree fields.
  String get typeName;
  int get at;
  int get endAt;

  /// Generic field read; returns null when absent.
  dynamic operator [](String key);

  bool flag(String key) => this[key] == true;

  bool has(String key) => this[key] != null;

  String str(String key) => this[key] as String;

  /// Adapts a decoded scalar/list entry back into a node view.
  EstNode nodeOf(Object? v);
}

/// JSON-backed implementation (transport A).
class JsonEstNode implements EstNode {
  final Map<String, dynamic> map;

  JsonEstNode(this.map);

  static final Map<Map<String, dynamic>, EstNode> _canonical = {};

  @override
  String get typeName => map['type'] as String;
  @override
  int get at => map['start'] as int;
  @override
  int get endAt => map['end'] as int;

  @override
  dynamic operator [](String key) {
    final v = map[key];
    // Wrap child objects so nested navigation stays on the interface.
    if (v is Map<String, dynamic>) return wrap(v);
    return v;
  }

  static EstNode wrap(Map<String, dynamic> m) =>
      _canonical[m] ??= JsonEstNode(m);

  @override
  bool flag(String key) => map[key] == true;

  @override
  bool has(String key) => map[key] != null;

  @override
  String str(String key) => map[key] as String;

  @override
  EstNode nodeOf(Object? v) {
    if (v is EstNode) return v;
    return wrap(v as Map<String, dynamic>);
  }
}

/// Adapts a legacy/scalar entry into a node view.
EstNode estOf(Object? v) {
  if (v is EstNode) return v;
  return JsonEstNode.wrap(v as Map<String, dynamic>);
}
