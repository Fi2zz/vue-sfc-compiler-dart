// Port of entities@4.5.0 decode.js EntityDecoder — the named/numeric
// character-reference decoder used by @vue/compiler-core's tokenizer.
// The decode trie lives in entity_decode_data.dart (generated).

/// Entities in text nodes may end without a semicolon (legacy set); only
/// semicolon-terminated entities decode in strict mode; attribute values have
/// ending-character restrictions.
enum DecodingMode { legacy, strict, attribute }

const int _kValueLength = 49152; // top 2 bits of node header
const int _kBranchLength = 16256; // middle 7 bits
const int _kJumpTable = 127; // low 7 bits
const int _kToLowerBit = 32;

bool _isNumber(int code) => code >= 48 && code <= 57;

bool _isHexDigit(int code) =>
    (code >= 48 && code <= 57) ||
    (code >= 65 && code <= 70) ||
    (code >= 97 && code <= 102);

bool _isAsciiAlphaNumeric(int code) =>
    (code >= 48 && code <= 57) ||
    (code >= 65 && code <= 90) ||
    (code >= 97 && code <= 122);

/// Attribute values that aren't properly terminated don't parse as entities.
bool _invalidAttributeEnd(int code) =>
    code == 61 || _isAsciiAlphaNumeric(code);

int _digitValue(int code) {
  if (code >= 48 && code <= 57) return code - 48;
  if (code >= 65 && code <= 70) return code - 55;
  if (code >= 97 && code <= 102) return code - 87;
  return -1;
}

/// Trie branch resolution: jump-table single branch, jump-table range, or
/// binary-searched dictionary. Returns next node index or -1.
int determineBranch(List<int> tree, int current, int nodeIdx, int char) {
  final branchCount = (current & _kBranchLength) >> 7;
  final jumpOffset = current & _kJumpTable;
  if (branchCount == 0) {
    return jumpOffset != 0 && char == jumpOffset ? nodeIdx : -1;
  }
  if (jumpOffset != 0) {
    final value = char - jumpOffset;
    if (value < 0 || value >= branchCount) return -1;
    return tree[nodeIdx + value] - 1;
  }
  var lo = nodeIdx;
  var hi = lo + branchCount - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >>> 1;
    final midVal = tree[mid];
    if (midVal < char) {
      lo = mid + 1;
    } else if (midVal > char) {
      hi = mid - 1;
    } else {
      return tree[mid + branchCount];
    }
  }
  return -1;
}

/// HTML-spec C1 control replacements plus invalid-code-point mapping,
/// mirroring entities' replaceCodePoint.
double replaceCodePoint(num codePoint) {
  const replacements = {
    0: 65533, 128: 8364, 130: 8218, 131: 402, 132: 8222, 133: 8230,
    134: 8224, 135: 8225, 136: 710, 137: 8240, 138: 352, 139: 8249,
    140: 338, 142: 381, 145: 8216, 146: 8217, 147: 8220, 148: 8221,
    149: 8226, 150: 8211, 151: 8212, 152: 732, 153: 8482, 154: 353,
    155: 8250, 156: 339, 158: 382, 159: 376,
  };
  final cp = codePoint.toDouble();
  if ((cp >= 0xd800 && cp <= 0xdfff) || cp > 0x10ffff) {
    return 0xfffd;
  }
  final hit = replacements[cp.toInt()];
  return hit?.toDouble() ?? cp;
}

final class EntityDecoder {
  final List<int> decodeTree;
  final void Function(int codepoint, int consumed) emitCodePoint;

  int _state = 0; // 0 entityStart 1 numericStart 2 dec 3 hex 4 named
  int consumed = 1;
  num result = 0; // numeric codepoint accumulator, or named trie index
  int treeIndex = 0;
  int excess = 1;
  DecodingMode decodeMode = DecodingMode.strict;

  EntityDecoder(this.decodeTree, this.emitCodePoint);

  void startEntity(DecodingMode mode) {
    decodeMode = mode;
    _state = 0;
    result = 0;
    treeIndex = 0;
    excess = 1;
    consumed = 1;
  }

  /// Decodes starting at [offset] (the char after '&'). Returns consumed
  /// length (including '&'), 0 when not an entity, -1 when buffer ended
  /// mid-entity.
  int write(String str, int offset) {
    switch (_state) {
      case 0:
        if (offset < str.length && str.codeUnitAt(offset) == 35) {
          _state = 1;
          consumed += 1;
          return _numericStart(str, offset + 1);
        }
        _state = 4;
        return _namedEntity(str, offset);
      case 1:
        return _numericStart(str, offset);
      case 2:
        return _numericDecimal(str, offset);
      case 3:
        return _numericHex(str, offset);
      default:
        return _namedEntity(str, offset);
    }
  }

  int _numericStart(String str, int offset) {
    if (offset >= str.length) return -1;
    if ((str.codeUnitAt(offset) | _kToLowerBit) == 120) {
      _state = 3;
      consumed += 1;
      return _numericHex(str, offset + 1);
    }
    _state = 2;
    return _numericDecimal(str, offset);
  }

  /// JS accumulates via doubles (`result * base^digits + parseInt(chunk)`),
  /// overflowing past 2^53 silently — mirror with double arithmetic so
  /// pathological inputs land in the same U+FFFD bucket.
  void _addDigits(String str, int start, int end, int base) {
    for (var i = start; i < end; i++) {
      final d = _digitValue(str.codeUnitAt(i));
      if (d < 0) return;
      result = result.toDouble() * base + d;
      consumed += 1;
    }
  }

  int _numericHex(String str, int offset) {
    final start = offset;
    while (offset < str.length) {
      final char = str.codeUnitAt(offset);
      if (_isNumber(char) || _isHexDigit(char)) {
        offset += 1;
      } else {
        _addDigits(str, start, offset, 16);
        return _emitNumericEntity(char, 3);
      }
    }
    _addDigits(str, start, offset, 16);
    return -1;
  }

  int _numericDecimal(String str, int offset) {
    final start = offset;
    while (offset < str.length) {
      final char = str.codeUnitAt(offset);
      if (char >= 48 && char <= 57) {
        offset += 1;
      } else {
        _addDigits(str, start, offset, 10);
        return _emitNumericEntity(char, 2);
      }
    }
    _addDigits(str, start, offset, 10);
    return -1;
  }

  int _emitNumericEntity(int lastCp, int expectedLength) {
    // Ensure we consumed at least one digit.
    if (consumed <= expectedLength) return 0;
    if (lastCp == 59) {
      consumed += 1;
    } else if (decodeMode == DecodingMode.strict) {
      return 0;
    }
    emitCodePoint(replaceCodePoint(result).toInt(), consumed);
    return consumed;
  }

  int _namedEntity(String str, int offset) {
    var current = decodeTree[treeIndex];
    var valueLength = (current & _kValueLength) >> 14;
    for (; offset < str.length; offset++, excess++) {
      final char = str.codeUnitAt(offset);
      final step = treeIndex + (1 > valueLength ? 1 : valueLength);
      treeIndex = determineBranch(decodeTree, current, step, char);
      if (treeIndex < 0) {
        return result == 0 ||
                (decodeMode == DecodingMode.attribute &&
                    (valueLength == 0 || _invalidAttributeEnd(char)))
            ? 0
            : _emitNotTerminatedNamedEntity();
      }
      current = decodeTree[treeIndex];
      valueLength = (current & _kValueLength) >> 14;
      if (valueLength == 0) continue;
      if (char == 59) {
        return _emitNamedEntityData(treeIndex, valueLength, consumed + excess);
      }
      // Non-terminated (legacy) entity: remember the longest match.
      if (decodeMode != DecodingMode.strict) {
        result = treeIndex;
        consumed += excess;
        excess = 0;
      }
    }
    return -1;
  }

  int _emitNotTerminatedNamedEntity() {
    final node = result as int;
    final valueLength = (decodeTree[node] & _kValueLength) >> 14;
    _emitNamedEntityData(node, valueLength, consumed);
    return consumed;
  }

  int _emitNamedEntityData(int node, int valueLength, int totalConsumed) {
    emitCodePoint(
        valueLength == 1
            ? decodeTree[node] & ~_kValueLength
            : decodeTree[node + 1],
        totalConsumed);
    if (valueLength == 3) {
      // Multi-codepoint values emit a second character.
      emitCodePoint(decodeTree[node + 2], totalConsumed);
    }
    return totalConsumed;
  }

  /// Flushes a partially-written entity at end of input. Only meaningful for
  /// streaming callers; the compiler tokenizer feeds whole buffers and lets
  /// trailing data flow through ontext instead.
  int end() {
    switch (_state) {
      case 4:
        return result != 0 &&
                (decodeMode != DecodingMode.attribute || result == treeIndex)
            ? _emitNotTerminatedNamedEntity()
            : 0;
      case 2:
        return _emitNumericEntity(0, 2);
      case 3:
        return _emitNumericEntity(0, 3);
      default:
        return 0;
    }
  }
}
