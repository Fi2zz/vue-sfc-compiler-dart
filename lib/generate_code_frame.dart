List<String> generateCodeFrame(String src, int start, int end) {
  int lineStartIdx = src.lastIndexOf('\n', start - 1);
  if (lineStartIdx == -1) {
    lineStartIdx = 0;
  } else {
    lineStartIdx += 1;
  }
  int lineEndIdx = src.indexOf('\n', end);
  if (lineEndIdx == -1) lineEndIdx = src.length;

  int prevStartIdx = src.lastIndexOf('\n', lineStartIdx - 2);
  if (prevStartIdx == -1) {
    prevStartIdx = 0;
  } else {
    prevStartIdx += 1;
  }
  int prevEndIdx = src.indexOf('\n', prevStartIdx);
  if (prevEndIdx == -1) prevEndIdx = src.length;

  int nextStartIdx = lineEndIdx + 1;
  int nextEndIdx = src.indexOf('\n', nextStartIdx);
  if (nextEndIdx == -1) nextEndIdx = src.length;

  final before = src.substring(0, lineStartIdx);
  final currLineNum = '\n'.allMatches(before).length + 1;
  final prevLineNum = currLineNum - 1;
  final nextLineNum = currLineNum + 1;

  final prevLine = src.substring(prevStartIdx, prevEndIdx);
  final currLine = src.substring(lineStartIdx, lineEndIdx);
  final nextLine = src.substring(nextStartIdx, nextEndIdx);
  final caretStartCol = start - lineStartIdx;
  final caret = '|  ${' ' * caretStartCol}^';

  final l1 = '$prevLineNum  |  ${prevLine.trimRight()}';
  final c1 = '|  ';
  final l2 = '$currLineNum  |  ${currLine.trimRight()}';
  final c2 = caret;
  final l3 = '$nextLineNum  |  ${nextLine.trimRight()}';
  return [l1, c1, l2, c2, l3];
}

// Compute 1-based line and column from a byte/char offset in source.
List<int> computeLineCol(String src, int start) {
  int lineStartIdx = src.lastIndexOf('\n', start - 1);
  if (lineStartIdx == -1) {
    lineStartIdx = 0;
  } else {
    lineStartIdx += 1;
  }
  final before = src.substring(0, lineStartIdx);
  final line = '\n'.allMatches(before).length + 1;
  final column = start - lineStartIdx + 1; // 1-based column
  return [line, column];
}
