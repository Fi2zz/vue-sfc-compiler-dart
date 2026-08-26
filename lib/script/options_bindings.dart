// Port of compiler-sfc analyzeScriptBindings / analyzeBindingsFromOptions:
// bindings for a normal-only <script> (no <script setup>). The resulting
// map carries __isScriptSetup = 'false' when a default-exported options
// object exists, which disables setup-reference resolution in the template.
import '../ts_parser.dart';

import 'src_view.dart';

/// Analyze a normal <script> body; returns {} when no default-exported
/// options object is present (mirrors analyzeScriptBindings).
Map<String, String> analyzeScriptBindings(String content, String lang) {
  final parser = TSParser();
  final root = parser.parse(code: content, language: lang);
  final view = SrcView(content);
  for (final node in root.children) {
    if (node.type != 'export_statement') continue;
    final obj = childOfType(node, 'object');
    if (obj == null) continue;
    return _bindingsFromOptions(obj, view);
  }
  return {};
}

Map<String, String> _bindingsFromOptions(AstNode obj, SrcView view) {
  final bindings = <String, String>{};
  for (final property in obj.children) {
    if (property.type == 'pair') {
      _analyzeOptionPair(property, view, bindings);
    } else if (property.type == 'method_definition') {
      _analyzeOptionMethod(property, view, bindings);
    }
  }
  bindings['__isScriptSetup'] = 'false';
  return bindings;
}

void _analyzeOptionPair(
    AstNode pair, SrcView view, Map<String, String> out) {
  final key = pair.children.isEmpty ? null : pair.children.first;
  final value = pair.children.length < 2 ? null : pair.children.last;
  if (key == null || value == null || key.type != 'property_identifier') {
    return;
  }
  final name = view.textOf(key);
  if (name == 'props' || name == 'inject') {
    final type = name == 'props' ? 'props' : 'options';
    for (final k in _objectOrArrayKeys(value, view)) {
      out[k] = type;
    }
  } else if ((name == 'computed' || name == 'methods') &&
      value.type == 'object') {
    for (final k in _objectKeys(value, view)) {
      out[k] = 'options';
    }
  }
}

void _analyzeOptionMethod(
    AstNode method, SrcView view, Map<String, String> out) {
  final key = method.children.isEmpty ? null : method.children.first;
  if (key == null || key.type != 'property_identifier') return;
  final name = view.textOf(key);
  if (name != 'setup' && name != 'data') return;
  final body = childOfType(method, 'statement_block');
  if (body == null) return;
  final type = name == 'setup' ? 'setup-maybe-ref' : 'data';
  for (final item in body.children) {
    if (item.type != 'return_statement') continue;
    final obj = childOfType(item, 'object');
    if (obj == null) continue;
    for (final k in _objectKeys(obj, view)) {
      out[k] = type;
    }
  }
}

/// Port of getObjectOrArrayExpressionKeys.
List<String> _objectOrArrayKeys(AstNode node, SrcView view) {
  if (node.type == 'array') return _arrayKeys(node, view);
  if (node.type == 'object') return _objectKeys(node, view);
  return const [];
}

List<String> _arrayKeys(AstNode node, SrcView view) => [
      for (final e in node.children)
        if (e.type == 'string') _stringText(e, view),
    ];

/// Port of getObjectExpressionKeys: pair + method keys, spread/computed
/// skipped.
List<String> _objectKeys(AstNode node, SrcView view) {
  final keys = <String>[];
  for (final p in node.children) {
    final k = switch (p.type) {
      'pair' => _pairKeyText(p, view),
      'method_definition' => _methodKeyText(p, view),
      _ => null,
    };
    if (k != null) keys.add(k);
  }
  return keys;
}

String? _methodKeyText(AstNode method, SrcView view) {
  if (method.children.isEmpty) return null;
  final key = method.children.first;
  return switch (key.type) {
    'property_identifier' => view.textOf(key),
    'string' => _stringText(key, view),
    _ => null,
  };
}

String? _pairKeyText(AstNode pair, SrcView view) {
  if (pair.children.isEmpty) return null;
  final key = pair.children.first;
  return switch (key.type) {
    'property_identifier' => view.textOf(key),
    'string' => _stringText(key, view),
    'number' => view.textOf(key),
    _ => null, // computed_property_name 等
  };
}

String _stringText(AstNode stringNode, SrcView view) {
  final frag = childOfType(stringNode, 'string_fragment');
  return frag == null ? view.textOf(stringNode) : view.textOf(frag);
}
