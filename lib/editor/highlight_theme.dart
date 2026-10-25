import 'package:flutter/material.dart';

import 'token.dart';

/// 编辑器的配色（编辑器始终使用深色画布）。
class HighlightTheme {
  const HighlightTheme({
    required this.background,
    required this.toolbar,
    required this.border,
    required this.gutter,
    required this.muted,
    required this.accent,
    required this.selection,
    required this.cursor,
    required this.plain,
    required this.keyword,
    required this.type,
    required this.string,
    required this.comment,
    required this.number,
    required this.annotation,
    required this.function,
    required this.punctuation,
    required this.operator,
  });

  final Color background;
  final Color toolbar;
  final Color border;
  final Color gutter;
  final Color muted;
  final Color accent;
  final Color selection;
  final Color cursor;

  final Color plain;
  final Color keyword;
  final Color type;
  final Color string;
  final Color comment;
  final Color number;
  final Color annotation;
  final Color function;
  final Color punctuation;
  final Color operator;

  static const dark = HighlightTheme(
    background: Color(0xFF12141C),
    toolbar: Color(0xFF191C26),
    border: Color(0xFF262A38),
    gutter: Color(0xFF4D5668),
    muted: Color(0xFF7D879C),
    accent: Color(0xFF8B7DFF),
    selection: Color(0x408B7DFF),
    cursor: Color(0xFF8B7DFF),
    plain: Color(0xFFC7D0E4),
    keyword: Color(0xFFC792EA),
    type: Color(0xFFFFCB6B),
    string: Color(0xFFC3E88D),
    comment: Color(0xFF67738A),
    number: Color(0xFFF78C6C),
    annotation: Color(0xFFFFCB6B),
    function: Color(0xFF82AAFF),
    punctuation: Color(0xFFA6ACCD),
    operator: Color(0xFF89DDFF),
  );

  Color colorFor(TokenType type) {
    switch (type) {
      case TokenType.keyword:
        return keyword;
      case TokenType.type:
        return this.type;
      case TokenType.string:
        return string;
      case TokenType.comment:
        return comment;
      case TokenType.number:
        return number;
      case TokenType.annotation:
        return annotation;
      case TokenType.function:
        return function;
      case TokenType.punctuation:
        return punctuation;
      case TokenType.operator:
        return operator;
      case TokenType.plain:
        return plain;
    }
  }
}
