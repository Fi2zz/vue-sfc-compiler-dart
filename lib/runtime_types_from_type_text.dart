List<String> runtimeTypesFromTypeText(String t) {
  final parts = t
      .split('|')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  String mapType(String s) {
    if (RegExp(r'\w+\[\]').hasMatch(s)) return 'Array';
    switch (s) {
      case 'string':
        return 'String';
      case 'number':
        return 'Number';
      case 'boolean':
        return 'Boolean';
      case 'object':
        return 'Object';
      default:
        return 'Object';
    }
  }

  final mapped = parts.map(mapType).toList();
  // dedupe
  final out = <String>[];
  for (final m in mapped) {
    if (!out.contains(m)) out.add(m);
  }
  return out;
}
