// Port of postcss-selector-parser node model (lossless subset) used by the
// scoped plugin. Positions/source indexes are omitted; they only feed error
// messages, never the stringified output.

/// spaces.before/after shared by all nodes.
final class SelSpaces {
  String before;
  String after;
  SelSpaces({this.before = '', this.after = ''});
}

/// raws bag: value/namespace/attribute/insensitiveFlag raw strings plus
/// raws.spaces.before/after for plain nodes and per-part spaces for
/// attribute nodes (raws.spaces.attribute/operator/value/insensitive).
final class SelRaws {
  String? value;
  String? namespace;
  String? attribute;
  String? insensitiveFlag;
  final Map<String, String> spaces = {};
  final Map<String, Map<String, String>> partSpaces = {};
}

/// raws[name] || node[name] semantics (JS falsy: null and '' fall through).
String? _truthy(String? raw) => raw != null && raw.isNotEmpty ? raw : null;

sealed class SelNode {
  SelNode({this.value = ''});

  String get type;
  String value;
  final SelSpaces spaces = SelSpaces();
  SelRaws? raws;
  SelContainer? parent;

  SelRaws ensureRaws() => raws ??= SelRaws();

  String get rawSpaceBefore => raws?.spaces['before'] ?? spaces.before;
  String get rawSpaceAfter => raws?.spaces['after'] ?? spaces.after;
  set rawSpaceBefore(String v) => ensureRaws().spaces['before'] = v;
  set rawSpaceAfter(String v) => ensureRaws().spaces['after'] = v;

  /// JS: this.raws && this.raws.value || this.value
  String valueToString() => _truthy(raws?.value) ?? value;

  /// appendToPropertyAndEscape('value', v, v): value += v; raws.value =
  /// (raws.value || oldValue) + v when raws.value existed.
  void appendValueAndEscape(String v) {
    final oldValue = value;
    final oldRaw = raws?.value;
    value = oldValue + v;
    if (oldRaw != null) ensureRaws().value = oldRaw + v;
  }

  void remove() {
    parent?.removeChild(this);
    parent = null;
  }

  /// replaceWith(other): insert other before this, then remove this.
  void replaceWith(SelNode other) {
    parent?.insertBefore(this, other);
    remove();
  }

  /// JS replaceWith(...nodes): replace this with several siblings in order.
  /// Must use the insertBefore chain (matching the official node.replaceWith)
  /// so the container's each-iterator index lands past the last replacement
  /// — an insertAfter chain would make an in-progress iteration revisit the
  /// newly inserted nodes.
  void replaceWithMany(List<SelNode> replacements) {
    final p = parent;
    if (p == null) return;
    for (final r in replacements) {
      p.insertBefore(this, r);
    }
    remove();
  }

  /// Deep structural copy: value, spaces, raws (part-space maps copied) and
  /// children recursively; the clone is detached (parent = null).
  SelNode deepClone() {
    final SelNode copy = switch (this) {
      SelAttribute() => SelAttribute(),
      SelClassName() => SelClassName(),
      SelCombinator() => SelCombinator(),
      SelComment() => SelComment(),
      SelId() => SelId(),
      SelNesting() => SelNesting(),
      SelPseudo() => SelPseudo(value: value),
      SelRoot() => SelRoot(),
      SelSelector() => SelSelector(),
      SelStringNode() => SelStringNode(value: value),
      SelTag() => SelTag(value: value),
      SelUniversal() => SelUniversal(value: value),
      SelNamespaceNode() ||
      SelContainer() => throw StateError('unreachable'),
    };
    copy.value = value;
    copy.spaces
      ..before = spaces.before
      ..after = spaces.after;
    if (raws != null) {
      copy.raws = SelRaws()
        ..value = raws!.value
        ..namespace = raws!.namespace
        ..attribute = raws!.attribute
        ..insensitiveFlag = raws!.insensitiveFlag;
      copy.raws!.spaces.addAll(raws!.spaces);
      raws!.partSpaces.forEach((k, v) => copy.raws!.partSpaces[k] = Map.of(v));
    }
    if (this is SelNamespaceNode) {
      (copy as SelNamespaceNode).namespace =
          (this as SelNamespaceNode).namespace;
    }
    if (copy is SelAttribute) {
      final src = this as SelAttribute;
      copy
        ..attribute = src.attribute
        ..operator = src.operator
        ..attrValue = src.attrValue
        ..quoteMark = src.quoteMark
        ..insensitive = src.insensitive;
      src.partSpaces.forEach((k, v) => copy.partSpaces[k] = Map.of(v));
    }
    if (copy is SelRoot) {
      copy.trailingComma = (this as SelRoot).trailingComma;
    }
    if (this is SelContainer) {
      for (final child in (this as SelContainer).nodes) {
        (copy as SelContainer).appendChild(child.deepClone());
      }
    }
    return copy;
  }

  String stringify() => '$rawSpaceBefore${valueToString()}$rawSpaceAfter';

  @override
  String toString() => stringify();
}

/// Nodes with an optional namespace: Tag, Universal, Attribute.
/// namespace: null (none) | true (universal ns `|`) | String name.
abstract class SelNamespaceNode extends SelNode {
  SelNamespaceNode({super.value});

  Object? namespace;

  String get namespaceString {
    final ns = namespace;
    if (ns == null || ns == true) return '';
    return _truthy(raws?.namespace) ?? ns as String;
  }

  String qualifiedName(String v) =>
      namespace != null ? '$namespaceString|$v' : v;

  @override
  String valueToString() => qualifiedName(super.valueToString());
}

final class SelTag extends SelNamespaceNode {
  SelTag({super.value});
  @override
  String get type => 'tag';
}

final class SelUniversal extends SelNamespaceNode {
  SelUniversal({super.value});
  @override
  String get type => 'universal';
}

final class SelClassName extends SelNode {
  SelClassName({super.value});
  @override
  String get type => 'className';
  @override
  String stringify() => '$rawSpaceBefore.${valueToString()}$rawSpaceAfter';
}

final class SelId extends SelNode {
  SelId({super.value});
  @override
  String get type => 'id';
  @override
  String stringify() => '$rawSpaceBefore#${valueToString()}$rawSpaceAfter';
}

final class SelStringNode extends SelNode {
  SelStringNode({super.value});
  @override
  String get type => 'string';
}

final class SelCombinator extends SelNode {
  SelCombinator({super.value});
  @override
  String get type => 'combinator';
}

final class SelComment extends SelNode {
  SelComment({super.value});
  @override
  String get type => 'comment';
}

final class SelNesting extends SelNode {
  SelNesting({super.value});
  @override
  String get type => 'nesting';
}

/// Container base: Selector, Pseudo, Root. `each` mirrors the JS index
/// bookkeeping so mutations (insert/remove) during iteration behave the same.
abstract class SelContainer extends SelNode {
  SelContainer({super.value});

  final List<SelNode> nodes = [];
  int _lastEach = 0;
  final Map<int, int> _indexes = {};

  SelNode? get first => nodes.isEmpty ? null : nodes.first;
  SelNode? get last => nodes.isEmpty ? null : nodes.last;
  int get length => nodes.length;

  void appendChild(SelNode child) {
    child.parent = this;
    nodes.add(child);
  }

  void append(SelNode child) {
    child.parent = this;
    nodes.add(child);
  }

  /// JS removeAll(): detach every child.
  void removeAll() {
    for (final n in nodes) {
      n.parent = null;
    }
    nodes.clear();
    _indexes.clear();
  }

  void prepend(SelNode child) {
    child.parent = this;
    nodes.insert(0, child);
    for (final id in _indexes.keys.toList()) {
      _indexes[id] = _indexes[id]! + 1;
    }
  }

  /// JS at(): out-of-range and -1 yield undefined.
  SelNode? at(int i) => i < 0 || i >= nodes.length ? null : nodes[i];

  /// JS index(): missing node yields -1.
  int index(SelNode? child) => child == null ? -1 : nodes.indexOf(child);

  void removeChild(SelNode child) {
    final i = index(child);
    if (i < 0) return;
    nodes[i].parent = null;
    nodes.removeAt(i);
    for (final id in _indexes.keys.toList()) {
      final idx = _indexes[id]!;
      if (idx >= i) _indexes[id] = idx - 1;
    }
  }

  /// insertAfter(oldNode, newNode); oldNode null -> index -1 -> prepend.
  void insertAfter(SelNode? oldNode, SelNode newNode) {
    newNode.parent = this;
    final oldIndex = index(oldNode);
    nodes.insert(oldIndex + 1, newNode);
    for (final id in _indexes.keys.toList()) {
      final idx = _indexes[id]!;
      if (oldIndex < idx) _indexes[id] = idx + 1;
    }
  }

  /// insertBefore(oldNode, newNode); index -1 -> JS splice(-1,0,x).
  void insertBefore(SelNode? oldNode, SelNode newNode) {
    newNode.parent = this;
    final oldIndex = index(oldNode);
    nodes.insert(oldIndex < 0 ? nodes.length - 1 : oldIndex, newNode);
    for (final id in _indexes.keys.toList()) {
      final idx = _indexes[id]!;
      if (idx >= oldIndex) _indexes[id] = idx + 1;
    }
  }

  /// Return false from the callback to stop; null/true continues.
  void each(bool? Function(SelNode node) callback) {
    _lastEach++;
    final id = _lastEach;
    _indexes[id] = 0;
    if (nodes.isNotEmpty) {
      bool? result;
      while (_indexes[id]! < nodes.length) {
        final i = _indexes[id]!;
        result = callback(nodes[i]);
        if (result == false) break;
        _indexes[id] = _indexes[id]! + 1; // JS indexes[id] += 1 (post-adjust)
      }
    }
    _indexes.remove(id);
  }

  void walk(bool? Function(SelNode node) callback) {
    each((node) {
      final result = callback(node);
      if (result != false && node is SelContainer && node.nodes.isNotEmpty) {
        node.walk(callback);
      }
      return result;
    });
  }

  @override
  String stringify() => nodes.map((n) => n.stringify()).join();
}

final class SelSelector extends SelContainer {
  @override
  String get type => 'selector';
}

final class SelPseudo extends SelContainer {
  SelPseudo({super.value});
  @override
  String get type => 'pseudo';

  @override
  String stringify() {
    final params = nodes.isEmpty
        ? ''
        : '(${nodes.map((n) => n.stringify()).join(',')})';
    return '$rawSpaceBefore${valueToString()}$params$rawSpaceAfter';
  }
}

final class SelRoot extends SelContainer {
  bool trailingComma = false;
  @override
  String get type => 'root';

  @override
  String stringify() {
    final str = nodes.map((n) => n.stringify()).join(',');
    return trailingComma ? '$str,' : str;
  }
}

/// Attribute node: `[ns|attr OP value i]` with per-part spaces.
final class SelAttribute extends SelNamespaceNode {
  SelAttribute();

  @override
  String get type => 'attribute';

  String attribute = '';
  String? operator;
  String? attrValue; // unescaped; null when the attribute has no value
  String? quoteMark; // '"' | "'" | null (unquoted) | null-unknown
  bool insensitive = false;

  /// spaces.attribute/operator/value/insensitive -> {before, after}
  final Map<String, Map<String, String>> partSpaces = {};

  bool get quoted => quoteMark == "'" || quoteMark == '"';
  String get insensitiveFlag => insensitive ? 'i' : '';
  String get qualifiedAttribute =>
      qualifiedName(_truthy(raws?.attribute) ?? attribute);

  Map<String, String> _spacesFor(String name) {
    final result = <String, String>{'before': '', 'after': ''};
    partSpaces[name]?.forEach((k, v) => result[k] = v);
    raws?.partSpaces[name]?.forEach((k, v) => result[k] = v);
    return result;
  }

  String _stringifyPart(String name, String spaceName) {
    final sp = _spacesFor(spaceName);
    return '${sp['before']}${_partValue(name)}${sp['after']}';
  }

  String _partValue(String name) => switch (name) {
    'qualifiedAttribute' => qualifiedAttribute,
    'operator' => operator ?? '',
    'value' => _truthy(raws?.value) ?? attrValue ?? '',
    'insensitiveFlag' => _truthy(raws?.insensitiveFlag) ?? insensitiveFlag,
    _ => '',
  };

  String _insensitiveString() {
    final sp = _spacesFor('insensitive');
    var before = sp['before']!;
    final flag = _partValue('insensitiveFlag');
    final valueAfter = partSpaces['value']?['after'];
    if (flag.isNotEmpty &&
        !quoted &&
        before.isEmpty &&
        (valueAfter == null || valueAfter.isEmpty)) {
      before = ' ';
    }
    return '$before$flag${sp['after']}';
  }

  @override
  String stringify() {
    final sb = StringBuffer('$rawSpaceBefore[');
    sb.write(_stringifyPart('qualifiedAttribute', 'attribute'));
    if (operator != null && operator!.isNotEmpty && attrValue != null) {
      sb.write(_stringifyPart('operator', 'operator'));
      sb.write(_stringifyPart('value', 'value'));
      sb.write(_insensitiveString());
    }
    sb.write(']$rawSpaceAfter');
    return sb.toString();
  }
}
