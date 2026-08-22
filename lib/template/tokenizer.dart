// Verbatim port of @vue/compiler-core Tokenizer state machine.
// State numbers and char codes match the official implementation.

import 'tmpl_ast.dart';

// Parse modes.
const modeBase = 0;
const modeHtml = 1;
const modeSfc = 2;

abstract final class Seq {
  static const cdata = [67, 68, 65, 84, 65, 91]; // CDATA[
  static const cdataEnd = [93, 93, 62]; // ]]>
  static const commentEnd = [45, 45, 62]; // -->
  static const scriptEnd = [60, 47, 115, 99, 114, 105, 112, 116]; // </script
  static const styleEnd = [60, 47, 115, 116, 121, 108, 101]; // </style
  static const titleEnd = [60, 47, 116, 105, 116, 108, 101]; // </title
  static const textareaEnd = [
    60, 47, 116, 101, 120, 116, 97, 114, 101, 97
  ]; // </textarea
}

// Shared identity constants (official compares sequences by reference).
final seqCdataEnd = List<int>.unmodifiable(Seq.cdataEnd);
final seqCommentEnd = List<int>.unmodifiable(Seq.commentEnd);
final seqScriptEnd = List<int>.unmodifiable(Seq.scriptEnd);
final seqStyleEnd = List<int>.unmodifiable(Seq.styleEnd);
final seqTitleEnd = List<int>.unmodifiable(Seq.titleEnd);
final seqTextareaEnd = List<int>.unmodifiable(Seq.textareaEnd);

bool isTagStartChar(int c) => c >= 97 && c <= 122 || c >= 65 && c <= 90;
bool isWhitespaceCode(int c) =>
    c == 32 || c == 10 || c == 9 || c == 12 || c == 13;
bool isEndOfTagSection(int c) => c == 47 || c == 62 || isWhitespaceCode(c);

List<int> toCharCodes(String s) =>
    [for (var i = 0; i < s.length; i++) s.codeUnitAt(i)];

abstract class TokenizerCallbacks {
  void onerr(int code, int index);
  void ontext(int start, int end);
  void ontextentity(String char, int start, int end);
  void oninterpolation(int start, int end);
  void onopentagname(int start, int end);
  void onopentagend(int end);
  void onclosetag(int start, int end);
  void onselfclosingtag(int end);
  void onattribname(int start, int end);
  void onattribnameend(int end);
  void onattribdata(int start, int end);
  void onattribentity(String char, int start, int end);
  void onattribend(int quote, int end);
  void ondirname(int start, int end);
  void ondirarg(int start, int end);
  void ondirmodifier(int start, int end);
  void oncomment(int start, int end);
  void oncdata(int start, int end);
  void onprocessinginstruction(int start, int end);
  void onend();
}

final class Tokenizer {
  final List<ElementNode> stack;
  final TokenizerCallbacks cbs;
  int state = 1;
  String buffer = '';
  int sectionStart = 0;
  int index = 0;
  int entityStart = 0;
  int baseState = 1;
  bool inRCDATA = false;
  bool inXML = false;
  bool inVPre = false;
  final List<int> newlines = [];
  int mode = modeBase;
  List<int> delimiterOpen = toCharCodes('{{');
  List<int> delimiterClose = toCharCodes('}}');
  int delimiterIndex = -1;
  List<int>? currentSequence;
  int sequenceIndex = 0;

  Tokenizer(this.stack, this.cbs);

  bool get inSFCRoot => mode == modeSfc && stack.isEmpty;

  void reset() {
    state = 1;
    mode = modeBase;
    buffer = '';
    sectionStart = 0;
    index = 0;
    baseState = 1;
    inRCDATA = false;
    currentSequence = null;
    newlines.clear();
    delimiterOpen = toCharCodes('{{');
    delimiterClose = toCharCodes('}}');
  }

  TmplPosition getPos(int index) {
    var line = 1;
    var column = index + 1;
    for (var i = newlines.length - 1; i >= 0; i--) {
      final newlineIndex = newlines[i];
      if (index > newlineIndex) {
        line = i + 2;
        column = index - newlineIndex;
        break;
      }
    }
    return TmplPosition(index, line, column);
  }

  int peek() => index + 1 < buffer.length ? buffer.codeUnitAt(index + 1) : -1;

  void stateText(int c) {
    if (c == 60) {
      if (index > sectionStart) cbs.ontext(sectionStart, index);
      state = 5;
      sectionStart = index;
    } else if (c == 38) {
      startEntity();
    } else if (!inVPre && c == delimiterOpen[0]) {
      state = 2;
      delimiterIndex = 0;
      stateInterpolationOpen(c);
    }
  }

  void stateInterpolationOpen(int c) {
    if (c == delimiterOpen[delimiterIndex]) {
      if (delimiterIndex == delimiterOpen.length - 1) {
        final start = index + 1 - delimiterOpen.length;
        if (start > sectionStart) cbs.ontext(sectionStart, start);
        state = 3;
        sectionStart = start;
      } else {
        delimiterIndex++;
      }
    } else if (inRCDATA) {
      state = 32;
      stateInRCDATA(c);
    } else {
      state = 1;
      stateText(c);
    }
  }

  void stateInterpolation(int c) {
    if (c == delimiterClose[0]) {
      state = 4;
      delimiterIndex = 0;
      stateInterpolationClose(c);
    }
  }

  void stateInterpolationClose(int c) {
    if (c == delimiterClose[delimiterIndex]) {
      if (delimiterIndex == delimiterClose.length - 1) {
        cbs.oninterpolation(sectionStart, index + 1);
        state = inRCDATA ? 32 : 1;
        sectionStart = index + 1;
      } else {
        delimiterIndex++;
      }
    } else {
      state = 3;
      stateInterpolation(c);
    }
  }

  void stateSpecialStartSequence(int c) {
    final seq = currentSequence!;
    final atEnd = sequenceIndex == seq.length;
    final matched = atEnd ? isEndOfTagSection(c) : (c | 32) == seq[sequenceIndex];
    if (!matched) {
      inRCDATA = false;
    } else if (!atEnd) {
      sequenceIndex++;
      return;
    }
    sequenceIndex = 0;
    state = 6;
    stateInTagName(c);
  }

  void stateInRCDATA(int c) {
    final seq = currentSequence!;
    if (sequenceIndex == seq.length) {
      if (c == 62 || isWhitespaceCode(c)) {
        final endOfText = index - seq.length;
        if (sectionStart < endOfText) {
          final actualIndex = index;
          index = endOfText;
          cbs.ontext(sectionStart, endOfText);
          index = actualIndex;
        }
        sectionStart = endOfText + 2;
        stateInClosingTagName(c);
        inRCDATA = false;
        return;
      }
      sequenceIndex = 0;
    }
    if ((c | 32) == seq[sequenceIndex]) {
      sequenceIndex += 1;
    } else if (sequenceIndex == 0) {
      final titleSeq = identical(seq, seqTitleEnd);
      final textareaSeq = identical(seq, seqTextareaEnd) && !inSFCRoot;
      if (titleSeq || textareaSeq) {
        if (c == 38) {
          startEntity();
        } else if (!inVPre && c == delimiterOpen[0]) {
          state = 2;
          delimiterIndex = 0;
          stateInterpolationOpen(c);
        }
      } else if (fastForwardTo(60)) {
        sequenceIndex = 1;
      }
    } else {
      sequenceIndex = c == 60 ? 1 : 0;
    }
  }

  void stateCDATASequence(int c) {
    if (c == Seq.cdata[sequenceIndex]) {
      sequenceIndex++;
      if (sequenceIndex == Seq.cdata.length) {
        state = 28;
        currentSequence = seqCdataEnd;
        sequenceIndex = 0;
        sectionStart = index + 1;
      }
    } else {
      sequenceIndex = 0;
      state = 23;
      stateInDeclaration(c);
    }
  }

  bool fastForwardTo(int c) {
    while (++index < buffer.length) {
      final cc = buffer.codeUnitAt(index);
      if (cc == 10) newlines.add(index);
      if (cc == c) return true;
    }
    index = buffer.length - 1;
    return false;
  }

  void stateInCommentLike(int c) {
    final seq = currentSequence!;
    if (c == seq[sequenceIndex]) {
      sequenceIndex++;
      if (sequenceIndex == seq.length) {
        if (identical(seq, seqCdataEnd)) {
          cbs.oncdata(sectionStart, index - 2);
        } else {
          cbs.oncomment(sectionStart, index - 2);
        }
        sequenceIndex = 0;
        sectionStart = index + 1;
        state = 1;
      }
    } else if (sequenceIndex == 0) {
      if (fastForwardTo(seq[0])) sequenceIndex = 1;
    } else if (c != seq[sequenceIndex - 1]) {
      sequenceIndex = 0;
    }
  }

  void startSpecial(List<int> sequence, int offset) {
    enterRCDATA(sequence, offset);
    state = 31;
  }

  void enterRCDATA(List<int> sequence, int offset) {
    inRCDATA = true;
    currentSequence = sequence;
    sequenceIndex = offset;
  }

  void stateBeforeTagName(int c) {
    if (c == 33) {
      state = 22;
      sectionStart = index + 1;
    } else if (c == 63) {
      state = 24;
      sectionStart = index + 1;
    } else if (isTagStartChar(c)) {
      sectionStart = index;
      if (mode == modeBase) {
        state = 6;
      } else if (inSFCRoot) {
        state = 34;
      } else if (!inXML) {
        if (c == 116) {
          state = 30;
        } else {
          state = c == 115 ? 29 : 6;
        }
      } else {
        state = 6;
      }
    } else if (c == 47) {
      state = 8;
    } else {
      state = 1;
      stateText(c);
    }
  }

  void stateInTagName(int c) {
    if (isEndOfTagSection(c)) handleTagName(c);
  }

  void stateInSFCRootTagName(int c) {
    if (isEndOfTagSection(c)) {
      final tag = buffer.substring(sectionStart, index);
      if (tag != 'template') {
        enterRCDATA(toCharCodes('</$tag'), 0);
      }
      handleTagName(c);
    }
  }

  void handleTagName(int c) {
    cbs.onopentagname(sectionStart, index);
    sectionStart = -1;
    state = 11;
    stateBeforeAttrName(c);
  }

  void stateBeforeClosingTagName(int c) {
    if (isWhitespaceCode(c)) {
      // ignore
    } else if (c == 62) {
      cbs.onerr(14, index);
      state = 1;
      sectionStart = index + 1;
    } else {
      state = isTagStartChar(c) ? 9 : 27;
      sectionStart = index;
    }
  }

  void stateInClosingTagName(int c) {
    if (c == 62 || isWhitespaceCode(c)) {
      cbs.onclosetag(sectionStart, index);
      sectionStart = -1;
      state = 10;
      stateAfterClosingTagName(c);
    }
  }

  void stateAfterClosingTagName(int c) {
    if (c == 62) {
      state = 1;
      sectionStart = index + 1;
    }
  }

  void stateBeforeAttrName(int c) {
    if (c == 62) {
      cbs.onopentagend(index);
      state = inRCDATA ? 32 : 1;
      sectionStart = index + 1;
    } else if (c == 47) {
      state = 7;
      if (peek() != 62) cbs.onerr(22, index);
    } else if (c == 60 && peek() == 47) {
      cbs.onopentagend(index);
      state = 5;
      sectionStart = index;
    } else if (!isWhitespaceCode(c)) {
      if (c == 61) cbs.onerr(19, index);
      handleAttrStart(c);
    }
  }

  void handleAttrStart(int c) {
    if (c == 118 && peek() == 45) {
      state = 13;
      sectionStart = index;
    } else if (c == 46 || c == 58 || c == 64 || c == 35) {
      cbs.ondirname(index, index + 1);
      state = 14;
      sectionStart = index + 1;
    } else {
      state = 12;
      sectionStart = index;
    }
  }

  void stateInSelfClosingTag(int c) {
    if (c == 62) {
      cbs.onselfclosingtag(index);
      state = 1;
      sectionStart = index + 1;
      inRCDATA = false;
    } else if (!isWhitespaceCode(c)) {
      state = 11;
      stateBeforeAttrName(c);
    }
  }

  void stateInAttrName(int c) {
    if (c == 61 || isEndOfTagSection(c)) {
      cbs.onattribname(sectionStart, index);
      handleAttrNameEnd(c);
    } else if (c == 34 || c == 39 || c == 60) {
      cbs.onerr(17, index);
    }
  }

  void stateInDirName(int c) {
    if (c == 61 || isEndOfTagSection(c)) {
      cbs.ondirname(sectionStart, index);
      handleAttrNameEnd(c);
    } else if (c == 58) {
      cbs.ondirname(sectionStart, index);
      state = 14;
      sectionStart = index + 1;
    } else if (c == 46) {
      cbs.ondirname(sectionStart, index);
      state = 16;
      sectionStart = index + 1;
    }
  }

  void stateInDirArg(int c) {
    if (c == 61 || isEndOfTagSection(c)) {
      cbs.ondirarg(sectionStart, index);
      handleAttrNameEnd(c);
    } else if (c == 91) {
      state = 15;
    } else if (c == 46) {
      cbs.ondirarg(sectionStart, index);
      state = 16;
      sectionStart = index + 1;
    }
  }

  void stateInDynamicDirArg(int c) {
    if (c == 93) {
      state = 14;
    } else if (c == 61 || isEndOfTagSection(c)) {
      cbs.ondirarg(sectionStart, index + 1);
      handleAttrNameEnd(c);
      cbs.onerr(27, index);
    }
  }

  void stateInDirModifier(int c) {
    if (c == 61 || isEndOfTagSection(c)) {
      cbs.ondirmodifier(sectionStart, index);
      handleAttrNameEnd(c);
    } else if (c == 46) {
      cbs.ondirmodifier(sectionStart, index);
      sectionStart = index + 1;
    }
  }

  void handleAttrNameEnd(int c) {
    sectionStart = index;
    state = 17;
    cbs.onattribnameend(index);
    stateAfterAttrName(c);
  }

  void stateAfterAttrName(int c) {
    if (c == 61) {
      state = 18;
    } else if (c == 47 || c == 62) {
      cbs.onattribend(0, sectionStart);
      sectionStart = -1;
      state = 11;
      stateBeforeAttrName(c);
    } else if (!isWhitespaceCode(c)) {
      cbs.onattribend(0, sectionStart);
      handleAttrStart(c);
    }
  }

  void stateBeforeAttrValue(int c) {
    if (c == 34) {
      state = 19;
      sectionStart = index + 1;
    } else if (c == 39) {
      state = 20;
      sectionStart = index + 1;
    } else if (!isWhitespaceCode(c)) {
      sectionStart = index;
      state = 21;
      stateInAttrValueNoQuotes(c);
    }
  }

  void handleInAttrValue(int c, int quote) {
    if (c == quote) {
      cbs.onattribdata(sectionStart, index);
      sectionStart = -1;
      cbs.onattribend(quote == 34 ? 3 : 2, index + 1);
      state = 11;
    } else if (c == 38) {
      startEntity();
    }
  }

  void stateInAttrValueNoQuotes(int c) {
    if (isWhitespaceCode(c) || c == 62) {
      cbs.onattribdata(sectionStart, index);
      sectionStart = -1;
      cbs.onattribend(1, index);
      state = 11;
      stateBeforeAttrName(c);
    } else if (c == 34 || c == 39 || c == 60 || c == 61 || c == 96) {
      cbs.onerr(18, index);
    } else if (c == 38) {
      startEntity();
    }
  }

  void stateBeforeDeclaration(int c) {
    if (c == 91) {
      state = 26;
      sequenceIndex = 0;
    } else {
      state = c == 45 ? 25 : 23;
    }
  }

  void stateInDeclaration(int c) {
    if (c == 62 || fastForwardTo(62)) {
      state = 1;
      sectionStart = index + 1;
    }
  }

  void stateInProcessingInstruction(int c) {
    if (c == 62 || fastForwardTo(62)) {
      cbs.onprocessinginstruction(sectionStart, index);
      state = 1;
      sectionStart = index + 1;
    }
  }

  void stateBeforeComment(int c) {
    if (c == 45) {
      state = 28;
      currentSequence = seqCommentEnd;
      sequenceIndex = 2;
      sectionStart = index + 1;
    } else {
      state = 23;
    }
  }

  void stateInSpecialComment(int c) {
    if (c == 62 || fastForwardTo(62)) {
      cbs.oncomment(sectionStart, index);
      state = 1;
      sectionStart = index + 1;
    }
  }

  void stateBeforeSpecialS(int c) {
    if (c == Seq.scriptEnd[3]) {
      startSpecial(seqScriptEnd, 4);
    } else if (c == Seq.styleEnd[3]) {
      startSpecial(seqStyleEnd, 4);
    } else {
      state = 6;
      stateInTagName(c);
    }
  }

  void stateBeforeSpecialT(int c) {
    if (c == Seq.titleEnd[3]) {
      startSpecial(seqTitleEnd, 4);
    } else if (c == Seq.textareaEnd[3]) {
      startSpecial(seqTextareaEnd, 4);
    } else {
      state = 6;
      stateInTagName(c);
    }
  }

  void startEntity() {
    baseState = state;
    state = 33;
    entityStart = index;
  }

  void stateInEntity() {
    final length = decodeEntityAt(buffer, entityStart,
        attribute: baseState != 1 && baseState != 32,
        onEmit: emitCodePoint);
    if (length >= 0) {
      state = baseState;
      if (length == 0) index = entityStart;
    } else {
      index = buffer.length - 1;
    }
  }

  void parse(String input) {
    buffer = input;
    while (index < buffer.length) {
      final c = buffer.codeUnitAt(index);
      if (c == 10 && state != 33) newlines.add(index);
      _dispatch(c);
      index++;
    }
    _cleanup();
    _finish();
  }

  void _cleanup() {
    if (sectionStart != index) {
      if (state == 1 || state == 32 && sequenceIndex == 0) {
        cbs.ontext(sectionStart, index);
        sectionStart = index;
      } else if (state == 19 || state == 20 || state == 21) {
        cbs.onattribdata(sectionStart, index);
        sectionStart = index;
      }
    }
  }

  void _finish() {
    if (state == 33) state = baseState;
    _handleTrailingData();
    cbs.onend();
  }

  void _handleTrailingData() {
    final endIndex = buffer.length;
    if (sectionStart >= endIndex) return;
    if (state == 28) {
      if (identical(currentSequence, seqCdataEnd)) {
        cbs.oncdata(sectionStart, endIndex);
      } else {
        cbs.oncomment(sectionStart, endIndex);
      }
    } else if (_nonTextTrailingState()) {
      // no trailing text for tag/attr states
    } else {
      cbs.ontext(sectionStart, endIndex);
    }
  }

  bool _nonTextTrailingState() {
    const states = [6, 7, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
    return states.contains(state);
  }

  void emitCodePoint(int cp, int consumed) {
    final char = String.fromCharCodes([cp]);
    if (baseState != 1 && baseState != 32) {
      if (sectionStart < entityStart) {
        cbs.onattribdata(sectionStart, entityStart);
      }
      sectionStart = entityStart + consumed;
      index = sectionStart - 1;
      cbs.onattribentity(char, entityStart, sectionStart);
    } else {
      if (sectionStart < entityStart) {
        cbs.ontext(sectionStart, entityStart);
      }
      sectionStart = entityStart + consumed;
      index = sectionStart - 1;
      cbs.ontextentity(char, entityStart, sectionStart);
    }
  }

  void _dispatch(int c) {
    switch (state) {
      case 1: stateText(c);
      case 2: stateInterpolationOpen(c);
      case 3: stateInterpolation(c);
      case 4: stateInterpolationClose(c);
      case 31: stateSpecialStartSequence(c);
      case 32: stateInRCDATA(c);
      case 26: stateCDATASequence(c);
      case 19: handleInAttrValue(c, 34);
      case 12: stateInAttrName(c);
      case 13: stateInDirName(c);
      case 14: stateInDirArg(c);
      case 15: stateInDynamicDirArg(c);
      case 16: stateInDirModifier(c);
      case 28: stateInCommentLike(c);
      case 27: stateInSpecialComment(c);
      case 11: stateBeforeAttrName(c);
      case 6: stateInTagName(c);
      case 34: stateInSFCRootTagName(c);
      case 9: stateInClosingTagName(c);
      case 5: stateBeforeTagName(c);
      case 17: stateAfterAttrName(c);
      case 20: handleInAttrValue(c, 39);
      case 18: stateBeforeAttrValue(c);
      case 8: stateBeforeClosingTagName(c);
      case 10: stateAfterClosingTagName(c);
      case 29: stateBeforeSpecialS(c);
      case 30: stateBeforeSpecialT(c);
      case 21: stateInAttrValueNoQuotes(c);
      case 7: stateInSelfClosingTag(c);
      case 23: stateInDeclaration(c);
      case 22: stateBeforeDeclaration(c);
      case 25: stateBeforeComment(c);
      case 24: stateInProcessingInstruction(c);
      case 33: stateInEntity();
    }
  }
}

/// Minimal entity decoder (subset of html-decode-tree): numeric entities plus
/// common named entities. Returns consumed length, 0 when the sequence is not
/// a decodable entity, -1 when the buffer ended mid-entity (full-buffer input
/// makes that equivalent to 0, handled by caller semantics).
int decodeEntityAt(
  String buffer,
  int entityStart, {
  required bool attribute,
  required void Function(int cp, int consumed) onEmit,
}) {
  // buffer[entityStart] == '&'
  var i = entityStart + 1;
  if (i >= buffer.length) return -1;
  if (buffer.codeUnitAt(i) == 35) {
    return _decodeNumeric(buffer, i, onEmit);
  }
  return _decodeNamed(buffer, i, attribute, onEmit);
}

int _decodeNumeric(
    String buffer, int i, void Function(int cp, int consumed) onEmit) {
  var j = i + 1;
  var hex = false;
  if (j < buffer.length &&
      (buffer.codeUnitAt(j) == 120 || buffer.codeUnitAt(j) == 88)) {
    hex = true;
    j++;
  }
  final digitStart = j;
  while (j < buffer.length) {
    final c = buffer.codeUnitAt(j);
    final digit = hex
        ? (c >= 48 && c <= 57 || c >= 65 && c <= 70 || c >= 97 && c <= 102)
        : c >= 48 && c <= 57;
    if (!digit) break;
    j++;
  }
  if (j == digitStart) return 0;
  final semi = j < buffer.length && buffer.codeUnitAt(j) == 59;
  final text = buffer.substring(digitStart, j);
  final cp = int.tryParse(text, radix: hex ? 16 : 10);
  if (cp == null) return 0;
  final total = (j - (i - 1)) + (semi ? 1 : 0);
  onEmit(_replaceCodePoint(cp), total);
  return total;
}

int _decodeNamed(String buffer, int i, bool attribute,
    void Function(int cp, int consumed) onEmit) {
  final start = i;
  while (i < buffer.length) {
    final c = buffer.codeUnitAt(i);
    final alnum = c >= 48 && c <= 57 || c >= 65 && c <= 90 || c >= 97 && c <= 122;
    if (!alnum) break;
    i++;
  }
  final semi = i < buffer.length && buffer.codeUnitAt(i) == 59;
  if (!semi) {
    // Legacy mode (text only): some named entities work without semicolon.
    if (attribute) return 0;
    final name = buffer.substring(start, i);
    final cp = legacyNamedEntities[name];
    if (cp == null) return 0;
    onEmit(cp, i - start + 1);
    return i - start + 1;
  }
  final name = buffer.substring(start, i);
  final cp = namedEntities[name];
  if (cp == null) return 0;
  onEmit(cp, i - start + 2);
  return i - start + 2;
}

// Numeric character reference replacements per HTML spec (subset: C1 controls).
int _replaceCodePoint(int cp) {
  const replacements = {
    0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026,
    0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160,
    0x8B: 0x2039, 0x8C: 0x0152, 0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019,
    0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
    0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153,
    0x9E: 0x017E, 0x9F: 0x0178,
  };
  if (cp == 0 || cp > 0x10FFFF) return 0xFFFD;
  return replacements[cp] ?? cp;
}

/// Named entities requiring a semicolon (common subset).
const namedEntities = {
  'amp': 38, 'lt': 60, 'gt': 62, 'quot': 34, 'apos': 39, 'nbsp': 160,
  'copy': 169, 'reg': 174, 'trade': 8482, 'hellip': 8230, 'mdash': 8212,
  'ndash': 8211, 'times': 215, 'divide': 247, 'laquo': 171, 'raquo': 187,
  'middot': 183, 'bull': 8226, 'deg': 176, 'plusmn': 177, 'para': 182,
  'sect': 167, 'micro': 181, 'acute': 180, 'cedil': 184, 'iexcl': 161,
  'iquest': 191, 'cent': 162, 'pound': 163, 'yen': 165, 'euro': 8364,
  'brvbar': 166, 'uml': 168, 'ordf': 170, 'ordm': 186, 'shy': 173,
  'macr': 175, 'sup1': 185, 'sup2': 178, 'sup3': 179, 'frac14': 188,
  'frac12': 189, 'frac34': 190, 'lsquo': 8216, 'rsquo': 8217,
  'ldquo': 8220, 'rdquo': 8221, 'dagger': 8224, 'Dagger': 8225,
  'permil': 8240, 'prime': 8242, 'Prime': 8243, 'lsaquo': 8249,
  'rsaquo': 8250, 'oline': 8254, 'frasl': 8260, 'spades': 9824,
  'clubs': 9827, 'hearts': 9829, 'diams': 9830, 'aacute': 225,
  'eacute': 233, 'iacute': 237, 'oacute': 243, 'uacute': 250,
  'agrave': 224, 'egrave': 232, 'igrave': 236, 'ograve': 242,
  'ugrave': 249, 'ccedil': 231, 'ntilde': 241, 'auml': 228, 'ouml': 246,
  'uuml': 252, 'Auml': 196, 'Ouml': 214, 'Uuml': 220, 'szlig': 223,
};

/// Legacy named entities that decode without a semicolon in text.
const legacyNamedEntities = {
  'amp': 38, 'lt': 60, 'gt': 62, 'quot': 34, 'nbsp': 160, 'copy': 169,
  'reg': 174, 'AMP': 38, 'LT': 60, 'GT': 62, 'QUOT': 34, 'COPY': 169,
  'REG': 174,
};
