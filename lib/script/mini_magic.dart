// Mini re-implementation of the MagicString operations used by the official
// @vue/compiler-sfc compileScript: remove/overwrite/move/prependLeft/
// appendLeft/appendRight/prepend. Offsets are Dart string (UTF-16) offsets.
//
// Attachment semantics mirror MagicString chunks:
// - prependLeft(x) / appendLeft(x): attach to the chunk ENDING at x; render
//   after the content preceding x; travel with a moved range ending at x.
//   Outro order: prependLeft puts content before earlier outros, appendLeft
//   after.
// - appendRight(x): attaches to the chunk STARTING at x; renders before the
//   content following x, in call order; travels with a moved range
//   starting at x.

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
  final Map<int, List<String>> _outroLeft = {}; // prependLeft (reversed)
  final Map<int, List<String>> _outroRight = {}; // appendLeft (call order)
  final Map<int, List<String>> _introRight = {}; // appendRight (call order)
  final List<String> _prepends = [];
  final Set<int> _consumedOutro = {};
  final Set<int> _consumedIntro = {};

  MiniMagic(this.source);

  void remove(int start, int end) {
    if (end > start) _edits.add(_Edit(start, end, ''));
  }

  void overwrite(int start, int end, String content) {
    _edits.add(_Edit(start, end, content));
  }

  /// Move [start, end) to the front of the output, after previously moved
  /// chunks (mirrors successive s.move(start, end, 0) call order).
  void moveToFront(int start, int end) {
    if (end > start) _moves.add(_Edit(start, end, ''));
  }

  void prependLeft(int offset, String content) {
    _outroLeft.putIfAbsent(offset, () => []).add(content);
  }

  void appendLeft(int offset, String content) {
    _outroRight.putIfAbsent(offset, () => []).add(content);
  }

  void appendRight(int offset, String content) {
    _introRight.putIfAbsent(offset, () => []).add(content);
  }

  void prepend(String content) {
    _prepends.insert(0, content);
  }

  String _takeOutro(int offset) {
    if (_consumedOutro.contains(offset)) return '';
    _consumedOutro.add(offset);
    final buf = StringBuffer();
    for (final t in _outroLeft[offset]?.reversed ?? const <String>[]) {
      buf.write(t);
    }
    for (final t in _outroRight[offset] ?? const <String>[]) {
      buf.write(t);
    }
    return buf.toString();
  }

  String _takeIntro(int offset) {
    if (_consumedIntro.contains(offset)) return '';
    _consumedIntro.add(offset);
    final buf = StringBuffer();
    for (final t in _introRight[offset] ?? const <String>[]) {
      buf.write(t);
    }
    return buf.toString();
  }

  bool _hasInsertion(int offset) {
    final outro =
        !_consumedOutro.contains(offset) &&
        (_outroLeft.containsKey(offset) || _outroRight.containsKey(offset));
    final intro =
        !_consumedIntro.contains(offset) && _introRight.containsKey(offset);
    return outro || intro;
  }

  String _renderMoves() {
    final buf = StringBuffer();
    for (final m in _moves) {
      buf.write(_renderRange(m.start, m.end));
    }
    return buf.toString();
  }

  /// Render moved chunk [from, to): intro of the chunk starting at `from`,
  /// edited content (with every interior insertion traveling along), then the
  /// outro of the chunk ending at `to`. Outro/left attachments at `from`
  /// belong to the chunk ENDING at `from` (outside the move) and are rendered
  /// in place by the main pass, not here.
  String _renderRange(int from, int to) {
    final buf = StringBuffer();
    buf.write(_takeIntro(from));
    var cursor = from;
    for (final e in _sortedEdits()) {
      if (e.end <= from || e.start >= to) continue;
      if (e.start < cursor) continue; // overlapping edits: first wins
      _emitTraveling(buf, cursor, e.start);
      buf.write(_takeOutro(e.start));
      buf.write(_takeIntro(e.start));
      _dropInsertionsBetween(e.start, e.end);
      buf.write(e.replacement);
      cursor = e.end;
    }
    if (cursor < to) _emitTraveling(buf, cursor, to);
    buf.write(_takeOutro(to));
    return buf.toString();
  }

  /// Emit source[from, to) verbatim, consuming pending insertions at any
  /// interior offset as they are reached (everything inside a moved chunk
  /// travels with it).
  void _emitTraveling(StringBuffer buf, int from, int to) {
    var i = from;
    while (i < to) {
      if (_hasInsertion(i)) {
        buf.write(_takeOutro(i));
        buf.write(_takeIntro(i));
        continue;
      }
      var j = i;
      while (j < to && !_hasInsertion(j)) {
        j++;
      }
      buf.write(source.substring(i, j));
      i = j;
    }
  }

  /// Mark insertions attached at offsets in [start, end) as consumed without
  /// rendering: overwrite/remove wipes the covered source, and magic-string
  /// drops the chunks (and their attachments) inside an overwritten span.
  void _dropInsertionsBetween(int start, int end) {
    for (final map in [_outroLeft, _outroRight, _introRight]) {
      for (final offset in map.keys) {
        if (offset > start && offset < end) {
          _consumedOutro.add(offset);
          _consumedIntro.add(offset);
        }
      }
    }
  }

  List<_Edit> _sortedEdits() {
    return [..._edits]..sort((a, b) {
      final c = a.start.compareTo(b.start);
      return c != 0 ? c : a.end.compareTo(b.end);
    });
  }

  bool _coveredByMove(int offset) {
    for (final m in _moves) {
      if (offset >= m.start && offset < m.end) return true;
    }
    return false;
  }

  bool _isMoveStart(int offset) {
    for (final m in _moves) {
      if (offset == m.start) return true;
    }
    return false;
  }

  @override
  String toString() {
    final buf = StringBuffer();
    for (final p in _prepends) {
      buf.write(p);
    }
    buf.write(_renderMoves());
    _renderMain(buf);
    return buf.toString();
  }

  void _renderMain(StringBuffer buf) {
    final edits = _sortedEdits();
    var cursor = 0;
    for (final e in edits) {
      if (e.start < cursor) {
        // Overlapping edits: the earlier-starting (outer) span wins and the
        // inner edit dies with the replaced content, matching magic-string's
        // chunk replacement semantics.
        continue;
      }
      if (_coveredByMove(e.start)) continue; // rendered with its moved chunk
      _appendRange(buf, cursor, e.start);
      buf.write(_takeOutro(e.start));
      buf.write(_takeIntro(e.start));
      _dropInsertionsBetween(e.start, e.end);
      buf.write(e.replacement);
      cursor = e.end;
    }
    _appendRange(buf, cursor, source.length);
  }

  void _appendRange(StringBuffer buf, int from, int to) {
    var i = from;
    while (i < to) {
      if (_coveredByMove(i)) {
        // Left attachments at a move's start offset belong to the chunk
        // ending there (outside the move) and render in place, before the
        // hole left by the moved content. Everything else inside the move
        // either traveled with the chunk or was dropped with it.
        if (_isMoveStart(i)) buf.write(_takeOutro(i));
        i++;
        continue;
      }
      var j = i;
      while (j < to && !_coveredByMove(j) && !_hasInsertion(j)) {
        j++;
      }
      buf.write(source.substring(i, j));
      if (j < to && !_coveredByMove(j) && _hasInsertion(j)) {
        buf.write(_takeOutro(j));
        buf.write(_takeIntro(j));
      }
      i = j; // insertions at j consumed above, so scanning makes progress
    }
  }
}
