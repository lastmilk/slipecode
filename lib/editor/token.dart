/// 高亮后的语法单元类型。
enum TokenType {
  plain,
  keyword,
  type,
  string,
  comment,
  number,
  annotation,
  function,
  punctuation,
  operator,
}

/// 一段被归类后的源码文本。
class Token {
  const Token(this.type, this.text);

  final TokenType type;
  final String text;

  @override
  String toString() => '${type.name}(${text.length})';
}
