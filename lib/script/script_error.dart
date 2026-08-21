// Error type + code frame rendering matching the committed samples/ format.
//
// samples/ were produced by running the official compiler and formatting the
// resulting markdown with prettier. To reproduce them byte-exactly we emit
// the RAW official frame (a verbatim port of @vue/shared generateCodeFrame)
// and let the samples_dart pipeline run prettier over the markdown files.

/// Verbatim port of @vue/shared generateCodeFrame (range = 2).
/// [start]/[end] are char offsets into [source] (UTF-16 units, like JS).
String generateCodeFrame(String source, int start, int end) {
  const range = 2;
  start = start.clamp(0, source.length);
  end = end.clamp(0, source.length);
  if (start > end) return '';
  // Note: unlike JS String.split with a capturing group, Dart discards the
  // separators, so split lines/newlines explicitly.
  final lines = <String>[];
  final newlines = <String>[]; // newline sequence after each line ('' if eof)
  var last = 0;
  for (final m in RegExp(r'\r?\n').allMatches(source)) {
    lines.add(source.substring(last, m.start));
    newlines.add(m.group(0)!);
    last = m.end;
  }
  lines.add(source.substring(last));
  newlines.add('');
  String newlineAt(int i) => i < newlines.length ? newlines[i] : '';
  var count = 0;
  final res = <String>[];
  for (var i = 0; i < lines.length; i++) {
    count += lines[i].length + newlineAt(i).length;
    if (count >= start) {
      for (var j = i - range; j <= i + range || end > count; j++) {
        if (j < 0 || j >= lines.length) continue;
        final line = j + 1;
        final padNo = ' ' * (3 - '$line'.length).clamp(0, 3);
        res.add('$line$padNo|  ${lines[j]}');
        final lineLength = lines[j].length;
        final newLineSeqLength = newlineAt(j).length;
        if (j == i) {
          final pad = start - (count - (lineLength + newLineSeqLength));
          final length = end > count
              ? (lineLength - pad < 1 ? 1 : lineLength - pad)
              : (end - start < 1 ? 1 : end - start);
          res.add('   |  ${' ' * pad}${'^' * length}');
        } else if (j > i) {
          if (end > count) {
            final len0 = end - count;
            final length = (len0 < lineLength ? len0 : lineLength) < 1
                ? 1
                : (len0 < lineLength ? len0 : lineLength);
            res.add('   |  ${'^' * length}');
          }
          count += lineLength + newLineSeqLength;
        }
      }
      break;
    }
  }
  return res.join('\n');
}

/// Compile error with an official-style code frame over the full SFC source.
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
        '$filename\n${generateCodeFrame(source, nodeStart, nodeEnd)}';
  }
}
