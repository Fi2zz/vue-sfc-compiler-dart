// Verbatim port of postcss lib/stringifier.js.
import 'css_ast.dart';

const _defaultRaw = <String, Object>{
  'after': '\n',
  'beforeClose': '\n',
  'beforeComment': '\n',
  'beforeDecl': '\n',
  'beforeOpen': ' ',
  'beforeRule': '\n',
  'colon': ': ',
  'commentLeft': ' ',
  'commentRight': ' ',
  'emptyBody': '',
  'indent': '    ',
  'semicolon': false,
};

class CssStringifier {
  final StringBuffer out;

  CssStringifier(this.out);

  void stringifyNode(CssNode node, [bool semicolon = true]) {
    switch (node) {
      case CssRoot n:
        _root(n);
      case CssRule n:
        _rule(n);
      case CssAtRule n:
        _atrule(n, semicolon);
      case CssDecl n:
        _decl(n, semicolon);
      case CssComment n:
        _comment(n);
      case CssContainer _:
        break; // unreachable: CssContainer is abstract
    }
  }

  void _atrule(CssAtRule node, bool semicolon) {
    var name = '@${node.name}';
    final params = node.params.isNotEmpty ? _rawValue(node, 'params') : '';

    if (node.raws.afterName != null) {
      name += node.raws.afterName!;
    } else if (params.isNotEmpty) {
      name += ' ';
    }

    if (node.nodes != null) {
      _block(node, name + params);
    } else {
      final end = (node.raws.between ?? '') + (semicolon ? ';' : '');
      out.write(name + params + end);
    }
  }

  String _beforeAfter(CssNode node, String detect) {
    String value;
    if (node.type == 'decl') {
      value = _raw(node, null, 'beforeDecl');
    } else if (node.type == 'comment') {
      value = _raw(node, null, 'beforeComment');
    } else if (detect == 'before') {
      value = _raw(node, null, 'beforeRule');
    } else {
      value = _raw(node, null, 'beforeClose');
    }

    var buf = node.parent;
    var depth = 0;
    while (buf != null && buf.type != 'root') {
      depth += 1;
      buf = buf.parent;
    }

    if (value.contains('\n')) {
      final indent = _raw(node, null, 'indent');
      if (indent.isNotEmpty) {
        for (var step = 0; step < depth; step++) {
          value += indent;
        }
      }
    }

    return value;
  }

  void _block(CssContainer node, String start) {
    final between = _raw(node, 'between', 'beforeOpen');
    out.write('$start$between{');

    String after;
    if (node.nodes != null && node.nodes!.isNotEmpty) {
      _body(node);
      after = _raw(node, 'after');
    } else {
      after = _raw(node, 'after', 'emptyBody');
    }

    if (after.isNotEmpty) out.write(after);
    out.write('}');
  }

  void _body(CssContainer node) {
    final nodes = node.nodes!;
    var last = nodes.length - 1;
    while (last > 0) {
      if (nodes[last].type != 'comment') break;
      last -= 1;
    }

    final semicolon = _rawSemicolonValue(node);
    for (var i = 0; i < nodes.length; i++) {
      final child = nodes[i];
      final before = _raw(child, 'before');
      if (before.isNotEmpty) out.write(before);
      stringifyNode(child, last != i || semicolon);
    }
  }

  bool _rawSemicolonValue(CssContainer node) {
    final own = node.raws.semicolon;
    if (own != null) return own;
    final parent = node.parent;
    if (parent == null) return _defaultRaw['semicolon'] as bool;
    final root = node.root();
    if (root.rawCache.containsKey('semicolon')) {
      return root.rawCache['semicolon'] == 'true';
    }
    String? value;
    root.walk((i) {
      if (i is CssContainer && i.nodes != null && i.nodes!.isNotEmpty) {
        final lastNode = i.nodes!.last;
        if (lastNode is CssDecl && i.raws.semicolon != null) {
          value = i.raws.semicolon! ? 'true' : 'false';
          return false;
        }
      }
      return true;
    });
    value ??= 'false';
    root.rawCache['semicolon'] = value!;
    return value == 'true';
  }

  void _comment(CssComment node) {
    final left = _raw(node, 'left', 'commentLeft');
    final right = _raw(node, 'right', 'commentRight');
    out.write('/*$left${node.text}$right*/');
  }

  void _decl(CssDecl node, bool semicolon) {
    final between = _raw(node, 'between', 'colon');
    var string = node.prop + between + _rawValue(node, 'value');

    if (node.important) {
      string += node.raws.important ?? ' !important';
    }

    if (semicolon) string += ';';
    out.write(string);
  }

  // node.raws[own] if set; otherwise style detection per postcss.
  String _raw(CssNode node, String? own, [String? detect]) {
    detect ??= own!;
    if (own != null) {
      final value = node.raws.get(own);
      if (value is String) return value;
      if (value is bool) return value ? 'true' : 'false';
    }

    final parent = node.parent;

    if (detect == 'before') {
      if (parent == null ||
          (parent.type == 'root' && identical(parent.first, node))) {
        return '';
      }
      if (parent.type == 'document') return '';
    }

    if (parent == null) return _defaultRaw[detect] as String? ?? '';

    final root = node.root();
    if (root.rawCache.containsKey(detect)) {
      return root.rawCache[detect]!;
    }

    String? value;
    if (detect == 'before' || detect == 'after') {
      return _beforeAfter(node, detect);
    } else {
      value = switch (detect) {
        'beforeClose' => _rawBeforeClose(root),
        'beforeComment' => _rawBeforeComment(root, node),
        'beforeDecl' => _rawBeforeDecl(root, node),
        'beforeOpen' => _rawBeforeOpen(root),
        'beforeRule' => _rawBeforeRule(root),
        'colon' => _rawColon(root),
        'emptyBody' => _rawEmptyBody(root),
        'indent' => _rawIndent(root),
        _ => _rawWalkFallback(root, own),
      };
    }

    value ??= _defaultRaw[detect] as String?;
    value ??= '';
    root.rawCache[detect] = value;
    return value;
  }

  String? _rawWalkFallback(CssRoot root, String? own) {
    String? value;
    root.walk((i) {
      final v = i.raws.get(own ?? '');
      if (v is String) {
        value = v;
        return false;
      }
      return true;
    });
    return value;
  }

  String? _rawBeforeClose(CssRoot root) {
    String? value;
    root.walk((i) {
      if (i is CssContainer && i.nodes != null && i.nodes!.isNotEmpty) {
        final after = i.raws.after;
        if (after != null) {
          value = after;
          if (value!.contains('\n')) {
            value = value!.replaceAll(RegExp(r'[^\n]+$'), '');
          }
          return false;
        }
      }
      return true;
    });
    if (value != null) value = value!.replaceAll(RegExp(r'\S'), '');
    return value;
  }

  String? _rawBeforeComment(CssRoot root, CssNode node) {
    return _firstCommentBefore(root) ?? _fallbackCommentBefore(root, node);
  }

  String? _firstCommentBefore(CssRoot root) {
    String? value;
    var found = false;
    root.walk((i) {
      if (found) return false;
      if (i is CssComment && i.raws.before != null) {
        value = i.raws.before!;
        if (value!.contains('\n')) {
          value = value!.replaceAll(RegExp(r'[^\n]+$'), '');
        }
        found = true;
        return false;
      }
      return true;
    });
    if (value == null) return null;
    return value!.replaceAll(RegExp(r'\S'), '');
  }

  String? _fallbackCommentBefore(CssRoot root, CssNode node) {
    // postcss: value = this.raw(node, null, 'beforeDecl') when no comment raw
    return _rawBeforeDecl(root, node) ?? _defaultRaw['beforeComment'] as String;
  }

  String? _rawBeforeDecl(CssRoot root, CssNode node) {
    String? value;
    var found = false;
    root.walk((i) {
      if (found) return false;
      if (i is CssDecl && i.raws.before != null) {
        value = i.raws.before!;
        if (value!.contains('\n')) {
          value = value!.replaceAll(RegExp(r'[^\n]+$'), '');
        }
        found = true;
        return false;
      }
      return true;
    });
    if (value == null) {
      return _rawBeforeRule(node.root());
    }
    return value!.replaceAll(RegExp(r'\S'), '');
  }

  String? _rawBeforeOpen(CssRoot root) {
    String? value;
    var found = false;
    root.walk((i) {
      if (found) return false;
      if (i.type != 'decl') {
        final between = i.raws.between;
        if (between != null) {
          value = between;
          found = true;
          return false;
        }
      }
      return true;
    });
    return value;
  }

  String? _rawBeforeRule(CssRoot root) {
    String? value;
    var found = false;
    root.walk((i) {
      if (found) return false;
      if (i is CssContainer &&
          i.nodes != null &&
          !(identical(i.parent, root) && identical(root.first, i))) {
        if (i.raws.before != null) {
          value = i.raws.before!;
          if (value!.contains('\n')) {
            value = value!.replaceAll(RegExp(r'[^\n]+$'), '');
          }
          found = true;
          return false;
        }
      }
      return true;
    });
    if (value == null) return null;
    return value!.replaceAll(RegExp(r'\S'), '');
  }

  String? _rawColon(CssRoot root) {
    String? value;
    var found = false;
    root.walk((i) {
      if (found) return false;
      if (i is CssDecl && i.raws.between != null) {
        value = i.raws.between!.replaceAll(RegExp(r'[^\s:]'), '');
        found = true;
        return false;
      }
      return true;
    });
    return value;
  }

  String? _rawEmptyBody(CssRoot root) {
    String? value;
    var found = false;
    root.walk((i) {
      if (found) return false;
      if (i is CssContainer && i.nodes != null && i.nodes!.isEmpty) {
        final after = i.raws.after;
        if (after != null) {
          value = after;
          found = true;
          return false;
        }
      }
      return true;
    });
    return value;
  }

  String? _rawIndent(CssRoot root) {
    if (root.raws.indent != null) return root.raws.indent!;
    String? value;
    var found = false;
    root.walk((i) {
      if (found) return false;
      final p = i.parent;
      if (p != null &&
          !identical(p, root) &&
          p.parent != null &&
          identical(p.parent, root)) {
        if (i.raws.before != null) {
          final parts = i.raws.before!.split('\n');
          value = parts[parts.length - 1].replaceAll(RegExp(r'\S'), '');
          found = true;
          return false;
        }
      }
      return true;
    });
    return value;
  }

  String _rawValue(CssNode node, String prop) {
    final value = switch (node) {
      CssRule n when prop == 'selector' => n.selector,
      CssAtRule n when prop == 'params' => n.params,
      CssDecl n when prop == 'value' => n.value,
      _ => '',
    };
    final raw = node.raws.values[prop];
    if (raw != null && raw.value == value) {
      return raw.raw;
    }
    return value;
  }

  void _root(CssRoot node) {
    _body(node);
    final after = node.raws.after;
    if (after != null) out.write(after);
  }

  void _rule(CssRule node) {
    _block(node, _rawValue(node, 'selector'));
    final ownSemicolon = node.raws.ownSemicolon;
    if (ownSemicolon != null) {
      out.write(ownSemicolon);
    }
  }
}

/// postcss stringify(): root -> css text.
String stringifyCss(CssRoot root) {
  final out = StringBuffer();
  CssStringifier(out)._root(root);
  return out.toString();
}
