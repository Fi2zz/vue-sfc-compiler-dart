// Mini re-implementation of the MagicString operations used by the official
// @vue/compiler-sfc compileScript: remove/overwrite/move/prependLeft/
// appendRight/prepend. All offsets are Dart string (UTF-16 code unit) offsets.

final class _Edit {
  final int start;
  final int end;
  final String replacement;
  _Edit(this.start, this.end, this.replacement);
}

final class MiniMagic {
  final String source;
  final List<_Edit> _edits = [];
  final List<_Edit> _moves = [];
  final Map<int, List<String>> _prependLeft = {};
  final Map<int, List<String>> _appendRight = {};
  final List<String> _prepends = [];

  MiniMagic(this.source);

  void remove(int start, int end) {
    if (end > start) _edits.add(_Edit(start, end, ''));
  }

  void overwrite(int start, int end, String content) {
    _edits.add(_Edit(start, end, content));
  }

  /// Move [start, end) to the front of the output, after previously moved
  /// chunks (mirrors s.move(start, end, 0) call-order behavior).
  void moveToFront(int start, int end) {
    if (end > start) _moves.add(_Edit(start, end, ''));
  }

  void prependLeft(int offset, String content) {
    _prependLeft.putIfAbsent(offset, () => []).add(content);
  }

  void appendRight(int offset, String content) {
    _appendRight.putIfAbsent(offset, () => []).add(content);
  }

  void prepend(String content) {
    _prepends.insert(0, content);
  }

  String _insertionsAt(int offset) {
    final buf = StringBuffer();
    for (final t in _prependLeft[offset] ?? const <String>[]) {
      buf.write(t);
    }
    for (final t in _appendRight[offset] ?? const <String>[]) {
      buf.write(t);
    }
    return buf.toString();
  }

  String _renderMoves() {
    final buf = StringBuffer();
    for (final m in _moves) {
      buf.write(_renderRange(m.start, m.end));
    }
    return buf.toString();
  }

  /// Render [from, to) with non-move edits applied (used for moved chunks).
  String _renderRange(int from, int to) {
    final buf = StringBuffer();
    var cursor = from;
    for (final e in _edits) {
      if (e.end <= from || e.start >= to) continue;
      if (e.start > cursor) buf.write(source.substring(cursor, e.start));
      if (e.start >= cursor) {
        buf.write(e.replacement);
        cursor = e.end;
      }
    }
    if (cursor < to) buf.write(source.substring(cursor, to));
    return buf.toString();
  }

  bool _coveredByMove(int offset) {
    for (final m in _moves) {
      if (offset >= m.start && offset < m.end) return true;
    }
    return false;
  }

  String toString() {
    final edits = [..._edits]
      ..sort((a, b) {
        final c = a.start.compareTo(b.start);
        return c != 0 ? c : a.end.compareTo(b.end);
      });
    final buf = StringBuffer();
    for (final p in _prepends) {
      buf.write(p);
    }
    buf.write(_renderMoves());
    var cursor = 0;
    for (final e in edits) {
      if (e.start < cursor) continue; // overlapping edits: first wins
      _appendRange(buf, cursor, e.start);
      buf.write(_insertionsAt(e.start));
      buf.write(e.replacement);
      cursor = e.end;
    }
    _appendRange(buf, cursor, source.length);
    return buf.toString();
  }

  void _appendRange(StringBuffer buf, int from, int to) {
    var i = from;
    while (i < to) {
      if (_coveredByMove(i)) {
        i++;
        continue;
      }
      // Find next special boundary: insertion point or move-covered offset.
      var j = i;
      while (j < to && !_coveredByMove(j) && !_hasInsertion(j)) {
        j++;
      }
      buf.write(source.substring(i, j));
      if (j < to && _hasInsertion(j)) buf.write(_insertionsAt(j));
      i = j == i ? j + 1 : j;
    }
  }

  bool _hasInsertion(int offset) {
    return _prependLeft.containsKey(offset) || _appendRight.containsKey(offset);
  }
}
