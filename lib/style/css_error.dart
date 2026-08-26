// Port of postcss Input offset<->line/column math and
// CssSyntaxError toString()/showSourceCode(color: false) rendering.
import 'dart:math' as math;

import 'css_tokenize.dart';

/// node path.resolve(opts.from): keep absolute/URL, else join with cwd
/// and normalize (collapse '.', '..', duplicate slashes).
String resolveStyleFilename(String from, String cwd) {
  if (RegExp(r'^\w+://').hasMatch(from) || from.startsWith('/')) return from;
  final parts = <String>[];
  for (final seg in '$cwd/$from'.split('/')) {
    if (seg == '' || seg == '.') continue;
    if (seg == '..' && parts.isNotEmpty) {
      parts.removeLast();
    } else if (seg != '..') {
      parts.add(seg);
    }
  }
  return '/${parts.join('/')}';
}

List<int> _lineStarts(String css) {
  final lines = css.split('\n');
  final starts = List<int>.filled(lines.length, 0);
  var prev = 0;
  for (var i = 0; i < lines.length; i++) {
    starts[i] = prev;
    prev += lines[i].length + 1;
  }
  return starts;
}

/// postcss Input.fromOffset: binary search over line starts.
(int, int) cssOffsetToLineCol(String css, int offset) {
  final starts = _lineStarts(css);
  var min = 0;
  if (offset >= starts[starts.length - 1]) {
    min = starts.length - 1;
  } else {
    var max = starts.length - 2;
    while (min < max) {
      final mid = min + ((max - min) >> 1);
      if (offset < starts[mid]) {
        max = mid - 1;
      } else if (offset >= starts[mid + 1]) {
        min = mid + 1;
      } else {
        min = mid;
        break;
      }
    }
  }
  return (min + 1, offset - starts[min] + 1);
}

/// Full byte-exact `String(CssSyntaxError)` for a parse of [css].
String formatCssSyntaxError(String css, String file, CssSyntaxError e) {
  final (line, column) = cssOffsetToLineCol(css, e.offset);
  final endColumn = e.endOffset == null
      ? null
      : cssOffsetToLineCol(css, e.endOffset!).$2;
  final message = '$file:$line:$column: ${e.reason}';
  final frame = _showSourceCode(css, line, column, endColumn);
  return frame.isEmpty
      ? 'CssSyntaxError: $message'
      : 'CssSyntaxError: $message\n\n$frame\n';
}

final class _FramePos {
  final int line;
  final int column;
  final int? endColumn;
  const _FramePos(this.line, this.column, this.endColumn);
}

String _showSourceCode(String css, int line, int column, int? endColumn) {
  final lines = css.split(RegExp(r'\r?\n'));
  final start = math.max(line - 3, 0);
  final end = math.min(line + 2, lines.length);
  final maxWidth = '$end'.length;
  final pos = _FramePos(line, column, endColumn);
  final rendered = <String>[];
  for (var i = start; i < end; i++) {
    rendered.add(_frameLine(lines[i], i + 1, maxWidth, pos));
  }
  return rendered.join('\n');
}

String _frameLine(String line, int number, int maxWidth, _FramePos pos) {
  final padded = ' $number';
  final gutter = ' ${padded.substring(padded.length - maxWidth)} | ';
  if (number != pos.line) return ' $gutter$line';
  if (line.length > 160) return _longLineFrame(line, gutter, pos);
  final blank = gutter.replaceAll(RegExp(r'\d'), ' ');
  final lead = line
      .substring(0, pos.column - 1)
      .replaceAll(RegExp(r'[^\t]'), ' ');
  return '>$gutter$line\n $blank$lead^';
}

String _longLineFrame(String line, String gutter, _FramePos pos) {
  const padding = 20;
  final subStart = math.max(0, pos.column - padding);
  final subEnd = _jsMax(
    (pos.column + padding).toDouble(),
    pos.endColumn == null ? double.nan : (pos.endColumn! + padding) * 1.0,
  );
  final subLine = _jsSlice(line, subStart, subEnd);
  final leadEnd = math.min(pos.column - 1, padding - 1);
  final lead = line.substring(0, leadEnd).replaceAll(RegExp(r'[^\t]'), ' ');
  final blank = gutter.replaceAll(RegExp(r'\d'), ' ');
  return '>$gutter$subLine\n $blank$lead^';
}

double _jsMax(double a, double b) =>
    (a.isNaN || b.isNaN) ? double.nan : math.max(a, b);

/// JS String.prototype.slice(start, end) for non-negative start:
/// NaN end coerces to 0, end clamps to length, empty when end <= start.
String _jsSlice(String s, int start, double end) {
  if (end.isNaN) return '';
  final e = end > s.length ? s.length : end.toInt();
  return e <= start ? '' : s.substring(start, e);
}
