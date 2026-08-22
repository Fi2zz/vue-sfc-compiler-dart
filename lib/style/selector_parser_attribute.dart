// Part of selector_parser.dart: attribute `[...]` parsing.
part of 'selector_parser.dart';

/// Mutable accumulator for the attribute token loop (the plain JS `node`
/// object the official parser builds before constructing the Attribute).
final class _AttrState {
  String? attribute;
  Object? namespace; // null | true | String
  String? operator;
  String? value;
  String? quoteMark;
  bool insensitive = false;
  String? lastAdded;
  bool spaceAfterMeaningfulToken = false;
  String spaceBefore = '';
  String commentBefore = '';
  final Map<String, Map<String, String>> spaces = {};
  final Map<String, Map<String, String>> rawsSpaces = {};
  final Map<String, String> rawsStrings = {};

  bool get hasNamespace => !_falsy(namespace);
  bool get hasAttribute => !_falsy(attribute);
  bool get hasOperator => !_falsy(operator);
  bool get hasValue => value != null;

  Map<String, String> spacesFor(String part) => spaces.putIfAbsent(part, () => {});
  Map<String, String> rawsFor(String part) => rawsSpaces.putIfAbsent(part, () => {});
}

bool _falsy(Object? o) => o == null || o == '' || o == false;

extension on SelParser {
  void _attribute() {
    final attr = <SelTok>[];
    position++;
    while (position < tokens.length && currToken.type != tkCloseSquare) {
      attr.add(currToken);
      position++;
    }
    if (position >= tokens.length) {
      throw SelSyntaxError('Expected a closing square bracket.');
    }
    if (attr.length == 1 && attr[0].type != tkWord) {
      throw SelSyntaxError('Expected an attribute.');
    }
    final st = _AttrState();
    for (var pos = 0; pos < attr.length; pos++) {
      _attributeToken(st, attr, pos);
    }
    newNode(_buildAttribute(st));
    position++;
  }

  void _attributeToken(_AttrState st, List<SelTok> attr, int pos) {
    final token = attr[pos];
    final c = content(token);
    final next = pos + 1 < attr.length ? attr[pos + 1] : null;
    switch (token.type) {
      case tkSpace:
        _attrSpace(st, c);
      case tkAsterisk:
        _attrAsterisk(st, c, next);
      case tkDollar:
        if (!_attrDollar(st, next)) _attrCaret(st, c, next);
      case tkCaret:
        _attrCaret(st, c, next);
      case tkCombinator:
        _attrCombinator(st, c, next);
      case tkWord:
        _attrWord(st, attr, pos, c, next);
      case tkStr:
        _attrString(st, c);
      case tkEquals:
        _attrEquals(st, c);
      case tkComment:
        _attrComment(st, c, next);
      default:
        throw SelSyntaxError('Unexpected "$c" found.');
    }
  }

  void _attrSpace(_AttrState st, String c) {
    st.spaceAfterMeaningfulToken = true;
    final last = st.lastAdded;
    if (last != null) {
      final sp = st.spacesFor(last);
      sp['after'] = (sp['after'] ?? '') + c;
      final existing = st.rawsSpaces[last]?['after'];
      if (existing != null) st.rawsFor(last)['after'] = existing + c;
    } else {
      st.spaceBefore += c;
      st.commentBefore += c;
    }
  }

  void _attrAsterisk(_AttrState st, String c, SelTok? next) {
    if (next != null && next.type == tkEquals) {
      st.operator = c;
      st.lastAdded = 'operator';
    } else if ((!st.hasNamespace ||
            (st.lastAdded == 'namespace' && !st.spaceAfterMeaningfulToken)) &&
        next != null) {
      _flushSpaceBefore(st);
      st.namespace = ((st.namespace is String) ? st.namespace as String : '') + c;
      final raw = st.rawsStrings['namespace'];
      if (raw != null) st.rawsStrings['namespace'] = raw + c;
      st.lastAdded = 'namespace';
    }
    st.spaceAfterMeaningfulToken = false;
  }

  bool _attrDollar(_AttrState st, SelTok? next) {
    if (st.lastAdded != 'value') return false;
    st.value = (st.value ?? '') + '\$';
    final raw = st.rawsStrings['value'];
    if (raw != null) st.rawsStrings['value'] = raw + '\$';
    return true;
  }

  void _attrCaret(_AttrState st, String c, SelTok? next) {
    if (next != null && next.type == tkEquals) {
      st.operator = c;
      st.lastAdded = 'operator';
    }
    st.spaceAfterMeaningfulToken = false;
  }

  void _attrCombinator(_AttrState st, String c, SelTok? next) {
    if (c == '~' && next != null && next.type == tkEquals) {
      st.operator = c;
      st.lastAdded = 'operator';
    }
    if (c != '|') {
      st.spaceAfterMeaningfulToken = false;
      return;
    }
    if (next != null && next.type == tkEquals) {
      st.operator = c;
      st.lastAdded = 'operator';
    } else if (!st.hasNamespace && !st.hasAttribute) {
      st.namespace = true;
    }
    st.spaceAfterMeaningfulToken = false;
  }

  void _attrWord(
      _AttrState st, List<SelTok> attr, int pos, String c, SelTok? next) {
    if (next != null &&
        content(next) == '|' &&
        pos + 2 < attr.length &&
        attr[pos + 2].type != tkEquals &&
        !st.hasOperator &&
        !st.hasNamespace) {
      st.namespace = c;
      st.lastAdded = 'namespace';
    } else if (!st.hasAttribute ||
        (st.lastAdded == 'attribute' && !st.spaceAfterMeaningfulToken)) {
      _flushSpaceBefore(st);
      st.attribute = (st.attribute ?? '') + c;
      final raw = st.rawsStrings['attribute'];
      if (raw != null) st.rawsStrings['attribute'] = raw + c;
      st.lastAdded = 'attribute';
    } else {
      _attrWordValue(st, c);
    }
    st.spaceAfterMeaningfulToken = false;
  }

  void _attrWordValue(_AttrState st, String c) {
    final appendValue = st.value == null ||
        (st.lastAdded == 'value' &&
            !(st.spaceAfterMeaningfulToken || st.quoteMark != null));
    if (appendValue) {
      _appendValueWord(st, c);
    } else if (st.hasValue &&
        (st.quoteMark != null || st.spaceAfterMeaningfulToken)) {
      _insensitiveWord(st, c);
    } else if (st.hasValue) {
      st.lastAdded = 'value';
      st.value = st.value! + c;
      final raw = st.rawsStrings['value'];
      if (raw != null) st.rawsStrings['value'] = raw + c;
    }
  }

  void _appendValueWord(_AttrState st, String c) {
    final unescaped = unescSel(c);
    final oldRaw = st.rawsStrings['value'] ?? '';
    final oldValue = st.value ?? '';
    st.value = oldValue + unescaped;
    st.quoteMark = null;
    if (unescaped != c || oldRaw.isNotEmpty) {
      st.rawsStrings['value'] =
          (oldRaw.isNotEmpty ? oldRaw : oldValue) + c;
    }
    st.lastAdded = 'value';
  }

  void _insensitiveWord(_AttrState st, String c) {
    final insensitive = c == 'i' || c == 'I';
    st.insensitive = insensitive;
    if (!insensitive || c == 'I') st.rawsStrings['insensitiveFlag'] = c;
    st.lastAdded = 'insensitive';
    if (st.spaceBefore.isNotEmpty) {
      st.spacesFor('insensitive')['before'] = st.spaceBefore;
      st.spaceBefore = '';
    }
    if (st.commentBefore.isNotEmpty) {
      st.rawsFor('insensitive')['before'] = st.commentBefore;
      st.commentBefore = '';
    }
  }

  void _attrString(_AttrState st, String c) {
    if (!st.hasAttribute || !st.hasOperator) {
      throw SelSyntaxError(
          'Expected an attribute followed by an operator preceding the string.');
    }
    final m = RegExp(r"""^('|")([\s\S]*)\1$""").firstMatch(c);
    st.quoteMark = m?[1];
    st.value = unescSel(m != null ? m[2]! : c);
    st.lastAdded = 'value';
    st.rawsStrings['value'] = c;
    st.spaceAfterMeaningfulToken = false;
  }

  void _attrEquals(_AttrState st, String c) {
    if (!st.hasAttribute) throw SelSyntaxError('Expected an attribute.');
    if (st.value != null && st.value!.isNotEmpty) {
      throw SelSyntaxError(
          'Unexpected "=" found; an operator was already defined.');
    }
    st.operator = st.hasOperator ? st.operator! + c : c;
    st.lastAdded = 'operator';
    st.spaceAfterMeaningfulToken = false;
  }

  void _attrComment(_AttrState st, String c, SelTok? next) {
    final last = st.lastAdded;
    if (last == null) {
      st.commentBefore += c;
      return;
    }
    final afterComment = st.spaceAfterMeaningfulToken ||
        (next != null && next.type == tkSpace) ||
        last == 'insensitive';
    if (afterComment) {
      final lastSpace = st.spaces[last]?['after'] ?? '';
      final raw = st.rawsSpaces[last]?['after'] ?? lastSpace;
      st.rawsFor(last)['after'] = raw + c;
    } else {
      final lastValue = _attrPartValue(st, last);
      final raw = st.rawsStrings[last] ?? lastValue;
      st.rawsStrings[last] = raw + c;
    }
  }

  String _attrPartValue(_AttrState st, String part) => switch (part) {
        'namespace' => st.namespace is String ? st.namespace as String : '',
        'attribute' => st.attribute ?? '',
        'operator' => st.operator ?? '',
        'value' => st.value ?? '',
        _ => '',
      };

  void _flushSpaceBefore(_AttrState st) {
    if (st.spaceBefore.isNotEmpty) {
      st.spacesFor('attribute')['before'] = st.spaceBefore;
      st.spaceBefore = '';
    }
    if (st.commentBefore.isNotEmpty) {
      // JS quirk: raws.spaces.attribute.before takes spaceBefore, which was
      // just reset to '' when both branches fire.
      st.rawsFor('attribute')['before'] = st.spaceBefore;
      st.commentBefore = '';
    }
  }

  SelAttribute _buildAttribute(_AttrState st) {
    final node = SelAttribute();
    node.attribute = _unescapePart(st, 'attribute', st.attribute ?? '');
    node.namespace = _unescapeNamespacePart(st);
    node.operator = st.operator;
    node.attrValue = st.value;
    node.quoteMark = st.quoteMark;
    node.insensitive = st.insensitive;
    st.spaces.forEach((k, v) => node.partSpaces[k] = v);
    final raws = node.ensureRaws();
    st.rawsSpaces.forEach((k, v) => raws.partSpaces[k] = v);
    _transferRaws(st, raws);
    return node;
  }

  void _transferRaws(_AttrState st, SelRaws raws) {
    st.rawsStrings.forEach((k, v) {
      switch (k) {
        case 'value':
          raws.value = v;
        case 'namespace':
          raws.namespace = v;
        case 'attribute':
          raws.attribute = v;
        case 'insensitiveFlag':
          raws.insensitiveFlag = v;
      }
    });
  }

  String _unescapePart(_AttrState st, String part, String value) {
    if (!value.contains('\\')) return value;
    st.rawsStrings.putIfAbsent(part, () => value);
    return unescSel(value);
  }

  Object? _unescapeNamespacePart(_AttrState st) {
    final ns = st.namespace;
    if (ns is String && ns.contains('\\')) {
      st.rawsStrings.putIfAbsent('namespace', () => ns);
      return unescSel(ns);
    }
    return ns;
  }
}
