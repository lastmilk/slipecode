/// 光标位置（从 1 开始计数）。
class CursorInfo {
  const CursorInfo(this.line, this.column);

  final int line;
  final int column;
}

CursorInfo cursorInfoOf(String text, int offset) {
  final target = offset.clamp(0, text.length);
  var line = 1;
  var lineStart = 0;
  for (var i = 0; i < target; i++) {
    if (text.codeUnitAt(i) == 10) {
      line++;
      lineStart = i + 1;
    }
  }
  return CursorInfo(line, target - lineStart + 1);
}

int lineCountOf(String text) {
  var count = 1;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 10) count++;
  }
  return count;
}
