List<String> renderErrorThreeLines(String src, String focusLine) {
  final l1 = '1 | <script setup lang="ts">';
  final c1 = '| ^';
  String line2 = '2 | $focusLine';
  String c2 = '| ${'^' * focusLine.length}';
  final l3 = '3 | </script>';
  return [l1, c1, line2, c2, l3];
}
