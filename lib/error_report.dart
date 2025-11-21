class ErrorPos {
  final int line;
  final int column;
  const ErrorPos(this.line, this.column);
}

class ErrorReportConfig {
  final int contextLines;
  final bool verbose;
  const ErrorReportConfig({this.contextLines = 3, this.verbose = false});
}

class DeclarationParseError {
  final String filename;
  final String message;
  final List<ErrorPos> positions;
  final int contextLines;
  final String kind; // 'import' | 'export' | 'parse'
  const DeclarationParseError({
    required this.filename,
    required this.message,
    required this.positions,
    this.contextLines = 3,
    this.kind = 'parse',
  });
}

class ErrorRenderer {
  static String render(
    DeclarationParseError err,
    String src, {
    ErrorReportConfig config = const ErrorReportConfig(),
  }) {
    final lines = _splitLines(src);
    final buf = StringBuffer();
    buf.writeln('```');
    buf.writeln('${err.filename}:${_posSummary(err.positions)}');
    buf.writeln(err.message);
    for (final p in err.positions) {
      final block = _contextBlock(lines, p.line, err.contextLines);
      for (int i = 0; i < block.length; i++) {
        final lineNo = block[i].$1;
        final text = block[i].$2;
        buf.writeln(text);
        if (lineNo == p.line) {
          final caret = ' ' * p.column + '^';
          buf.writeln(caret);
          if (text.contains('//@ts-ignore')) {
            buf.writeln('// ignored by //@ts-ignore');
          }
        }
      }
    }

    buf.writeln('```');
    return buf.toString();
  }

  static List<(int, String)> _contextBlock(
    List<String> lines,
    int line,
    int ctx,
  ) {
    final start = (line - 1 - ctx).clamp(0, lines.length - 1);
    final end = (line - 1 + ctx).clamp(0, lines.length - 1);
    final out = <(int, String)>[];
    for (int i = start; i <= end; i++) {
      out.add((i + 1, lines[i]));
    }
    return out;
  }

  static List<String> _splitLines(String s) {
    return s.split('\n');
  }

  static String _posSummary(List<ErrorPos> ps) {
    return ps.map((p) => '${p.line}:${p.column}').join(', ');
  }
}
