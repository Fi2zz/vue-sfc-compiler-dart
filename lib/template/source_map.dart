// Source map V3 support: Base64-VLQ codec + a minimal SourceMapGenerator
// mirroring source-map-js semantics (per-line segment groups, names index).
import 'dart:convert';

const base64Chars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

int _charToInt(String c) => base64Chars.indexOf(c);

/// VLQ 编码一个数值（有符号，zigzag 变长）。
String encodeVlq(int value) {
  var vlq = value < 0 ? ((-value) << 1) | 1 : value << 1;
  final out = StringBuffer();
  do {
    var digit = vlq & 0x1f;
    vlq >>= 5;
    if (vlq > 0) digit |= 0x20;
    out.write(base64Chars[digit]);
  } while (vlq > 0);
  return out.toString();
}

/// 解码一段 VLQ 字符串为数值列表（用于测试与比对工具）。
List<int> decodeVlq(String input) {
  final values = <int>[];
  var shift = 0;
  var value = 0;
  for (var i = 0; i < input.length; i++) {
    final digit = _charToInt(input[i]);
    if (digit < 0) throw FormatException('invalid base64 char: ${input[i]}');
    final cont = (digit & 0x20) != 0;
    value += (digit & 0x1f) << shift;
    if (cont) {
      shift += 5;
    } else {
      final negative = value & 1 != 0;
      value >>= 1;
      values.add(negative ? -value : value);
      value = 0;
      shift = 0;
    }
  }
  return values;
}

class SourceMapMapping {
  final int originalLine; // 1-based（与官方 addMapping 一致）
  final int originalColumn; // 0-based
  final int generatedLine; // 1-based
  final int generatedColumn; // 0-based
  final String source;
  final String? name;
  SourceMapMapping({
    required this.originalLine,
    required this.originalColumn,
    required this.generatedLine,
    required this.generatedColumn,
    required this.source,
    this.name,
  });
}

/// 最小 SourceMapGenerator：仅覆盖 compiler-sfc 用到的能力
/// （addMapping / setSourceContent / toJSON）。
class SourceMapGenerator {
  final List<SourceMapMapping> _mappings = [];
  final Set<String> _names = {};
  final Map<String, String> _sourcesContent = {};

  void setSourceContent(String source, String content) {
    _sourcesContent[source] = content;
  }

  void addMapping(SourceMapMapping m) => _mappings.add(m);

  /// 序列化为 V3 JSON（mappings 按 generatedLine 分组、段内差分编码）。
  Map<String, Object?> toJSON({required String file}) {
    _mappings.sort((a, b) {
      if (a.generatedLine != b.generatedLine) {
        return a.generatedLine - b.generatedLine;
      }
      return a.generatedColumn - b.generatedColumn;
    });
    final sources = _sourcesContent.keys.toList();
    final sourceIndex = {
      for (var i = 0; i < sources.length; i++) sources[i]: i,
    };
    final nameList = _names.toList();
    final nameIndex = {
      for (var i = 0; i < nameList.length; i++) nameList[i]: i,
    };

    final buf = StringBuffer();
    var prevGenLine = 1;
    var prevGenCol = 0;
    var prevSrcIdx = 0;
    var prevOrigLine = 0;
    var prevOrigCol = 0;
    var prevNameIdx = 0;
    for (final m in _mappings) {
      while (prevGenLine < m.generatedLine) {
        buf.write(';');
        prevGenLine++;
        prevGenCol = 0;
      }
      if (buf.isNotEmpty && !buf.toString().endsWith(';')) buf.write(',');
      buf.write(encodeVlq(m.generatedColumn - prevGenCol));
      prevGenCol = m.generatedColumn;
      final srcIdx = sourceIndex[m.source] ?? 0;
      buf.write(encodeVlq(srcIdx - prevSrcIdx));
      buf.write(encodeVlq((m.originalLine - 1) - prevOrigLine));
      buf.write(encodeVlq(m.originalColumn - prevOrigCol));
      prevSrcIdx = srcIdx;
      prevOrigLine = m.originalLine - 1;
      prevOrigCol = m.originalColumn;
      final nm = m.name;
      if (nm != null) {
        final idx = nameIndex.putIfAbsent(nm, () {
          nameList.add(nm);
          return nameList.length - 1;
        });
        buf.write(encodeVlq(idx - prevNameIdx));
        prevNameIdx = idx;
      }
    }
    return {
      'version': 3,
      'file': file,
      'sources': sources,
      'sourcesContent': sources.map((s) => _sourcesContent[s]).toList(),
      'names': nameList,
      'mappings': buf.toString(),
    };
  }
}

/// 解码 V3 mappings 字符串为绝对段 [[genLine, genCol, srcIdx, origLine,
/// origCol, nameIdx?]...]（行号转 1-based 便于语义比对）。
List<List<int>> decodeMappings(String mappings) {
  final segments = <List<int>>[];
  var genLine = 1;
  var genCol = 0;
  var srcIdx = 0;
  var origLine = 0;
  var origCol = 0;
  var nameIdx = 0;
  for (final lineStr in mappings.split(';')) {
    genCol = 0;
    if (lineStr.isEmpty) {
      genLine++;
      continue;
    }
    for (final segStr in lineStr.split(',')) {
      if (segStr.isEmpty) continue;
      final nums = decodeVlq(segStr);
      genCol += nums[0];
      if (nums.length >= 4) {
        srcIdx += nums[1];
        origLine += nums[2];
        origCol += nums[3];
        final seg = [genLine, genCol, srcIdx, origLine + 1, origCol];
        if (nums.length >= 5) {
          nameIdx += nums[4];
          seg.add(nameIdx);
        }
        segments.add(seg);
      } else {
        segments.add([genLine, genCol]);
      }
    }
    genLine++;
  }
  return segments;
}

String encodeJson(Map<String, Object?> map) => jsonEncode(map);
