// postcss AST node model: Root / Rule / AtRule / Declaration / Comment,
// with the raws bag used by the stringifier for byte-exact round-trips.

/// raws[prop] entries storing {raw, value} when the clean value differs
/// from the raw source slice (postcss Node.raws selector/params/value).
final class CssRawValue {
  final String raw;
  final String value;
  CssRawValue(this.raw, this.value);
}

final class CssRaws {
  String? before;
  String? after;
  String? between;
  String? afterName;
  String? left;
  String? right;
  String? important;
  String? ownSemicolon;
  String? indent;
  bool? semicolon;
  final Map<String, CssRawValue> values = {};

  bool has(String name) => switch (name) {
        'before' => before != null,
        'after' => after != null,
        'between' => between != null,
        'afterName' => afterName != null,
        'left' => left != null,
        'right' => right != null,
        'important' => important != null,
        'ownSemicolon' => ownSemicolon != null,
        'indent' => indent != null,
        'semicolon' => semicolon != null,
        _ => values.containsKey(name),
      };

  Object? get(String name) => switch (name) {
        'before' => before,
        'after' => after,
        'between' => between,
        'afterName' => afterName,
        'left' => left,
        'right' => right,
        'important' => important,
        'ownSemicolon' => ownSemicolon,
        'indent' => indent,
        'semicolon' => semicolon,
        _ => values[name],
      };

  void set(String name, Object? v) {
    switch (name) {
      case 'before':
        before = v as String?;
      case 'after':
        after = v as String?;
      case 'between':
        between = v as String?;
      case 'afterName':
        afterName = v as String?;
      case 'left':
        left = v as String?;
      case 'right':
        right = v as String?;
      case 'important':
        important = v as String?;
      case 'ownSemicolon':
        ownSemicolon = v as String?;
      case 'indent':
        indent = v as String?;
      case 'semicolon':
        semicolon = v as bool?;
      default:
        if (v == null) {
          values.remove(name);
        } else {
          values[name] = v as CssRawValue;
        }
    }
  }
}

sealed class CssNode {
  String get type;
  CssContainer? parent;
  final CssRaws raws = CssRaws();
  /// postcss source.start.offset — only feeds error positions.
  int sourceStart = 0;

  CssRoot root() {
    CssNode node = this;
    while (node.parent != null) {
      node = node.parent!;
    }
    return node as CssRoot;
  }
}

abstract class CssContainer extends CssNode {
  /// Null for body-less at-rules (`@import x;`), empty list otherwise.
  List<CssNode>? nodes = [];

  CssNode? get first => nodes == null || nodes!.isEmpty ? null : nodes!.first;
  CssNode? get last => nodes == null || nodes!.isEmpty ? null : nodes!.last;

  void push(CssNode child) {
    child.parent = this;
    nodes!.add(child);
  }

  void prepend(CssNode child) {
    child.parent = this;
    nodes!.insert(0, child);
  }

  void removeChild(CssNode child) {
    nodes!.remove(child);
    child.parent = null;
  }

  int indexOf(CssNode child) => nodes!.indexOf(child);

  void insertAfter(CssNode existing, CssNode child) {
    final i = nodes!.indexOf(existing);
    child.parent = this;
    nodes!.insert(i + 1, child);
  }

  void insertBefore(CssNode existing, CssNode child) {
    final i = nodes!.indexOf(existing);
    child.parent = this;
    nodes!.insert(i, child);
  }

  void walk(bool Function(CssNode node) visitor) {
    if (nodes == null) return;
    for (final child in List<CssNode>.of(nodes!)) {
      if (visitor(child) == false) continue;
      if (child is CssContainer) child.walk(visitor);
    }
  }

  void walkDecls(void Function(CssDecl decl) visitor) {
    walk((node) {
      if (node is CssDecl) visitor(node);
      return true;
    });
  }

  void walkComments(void Function(CssComment c) visitor) {
    walk((node) {
      if (node is CssComment) visitor(node);
      return true;
    });
  }
}

final class CssRoot extends CssContainer {
  @override
  String get type => 'root';
  final Map<String, String> rawCache = {};
}

final class CssRule extends CssContainer {
  @override
  String get type => 'rule';
  String selector = '';
  bool deep = false; // rule.__deep marker used by the scoped plugin
  CssRule({this.selector = ''});
}

final class CssAtRule extends CssContainer {
  @override
  String get type => 'atrule';
  String name = '';
  String params = '';
  CssAtRule({this.name = '', this.params = ''});
}

final class CssDecl extends CssNode {
  @override
  String get type => 'decl';
  String prop;
  String value;
  bool important = false;
  CssDecl({this.prop = '', this.value = ''});
}

final class CssComment extends CssNode {
  @override
  String get type => 'comment';
  String text = '';
  CssComment({this.text = ''});
}
