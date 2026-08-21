// Error type + code frame rendering matching the committed samples/ format.
//
// Frame rules (derived from committed samples):
// - show lines [errLine-2 .. errLine+1] clamped to the file, as `<n> | <text>`
// - after line errLine-1: `| ^` iff the error node starts at column 0
// - after errLine: `| ` + '^' * nodeTextLength
final class ScriptCompileError implements Exception {
  final String reason; // official message without prefix
  final String filename;
  final String source; // full SFC source
  final int nodeStart; // char offsets in full source
  final int nodeEnd;

  ScriptCompileError({
    required this.reason,
    required this.filename,
    required this.source,
    required this.nodeStart,
    required this.nodeEnd,
  });

  @override
  String toString() {
    return 'Vue Compile Error: [@vue/compiler-sfc] $reason\n\n'
        '$filename\n${renderFrame()}';
  }

  String renderFrame() {
    final lines = source.split('\n');
    final errLine = _lineOf(nodeStart);
    final col = _columnOf(nodeStart, errLine);
    final span = _singleLineSpan(errLine);
    final from = errLine - 2 < 1 ? 1 : errLine - 2;
    final to = errLine + 1 > lines.length ? lines.length : errLine + 1;
    final buf = StringBuffer();
    for (var n = from; n <= to; n++) {
      buf.writeln('$n | ${lines[n - 1]}');
      if (n == errLine - 1 && col == 0) buf.writeln('| ^');
      if (n == errLine) buf.writeln('| ${'^' * span}');
    }
    return buf.toString().trimRight();
  }

  int _lineOf(int offset) {
    var line = 1;
    for (var i = 0; i < offset && i < source.length; i++) {
      if (source.codeUnitAt(i) == 0x0A) line++;
    }
    return line;
  }

  int _columnOf(int offset, int line) {
    var start = offset;
    while (start > 0 && source.codeUnitAt(start - 1) != 0x0A) {
      start--;
    }
    return offset - start;
  }

  int _singleLineSpan(int errLine) {
    final lines = source.split('\n');
    if (errLine > lines.length) return 1;
    final lineStart = _columnOf(nodeStart, errLine);
    final lineText = lines[errLine - 1];
    final onLine = nodeEnd - nodeStart;
    final available = lineText.length - lineStart;
    if (onLine <= 0) return 1;
    return onLine <= available ? onLine : lineText.length;
  }
}

/// Emits-mixed error is thrown deep inside type extraction.
void throwEmitsMixed(context, node) {
  // Replaced by a proper implementation in macro_process via callback.
  throw StateError('unwired throwEmitsMixed');
}
