import 'package:flutter/material.dart';

import 'highlight_theme.dart';
import 'syntax_highlighter.dart';

/// 带语法高亮的文本控制器。
class CodeController extends TextEditingController {
  CodeController({
    super.text,
    required this.language,
    this.theme = HighlightTheme.dark,
  });

  final String language;
  final HighlightTheme theme;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return SyntaxHighlighter.buildSpan(
      text: text,
      language: language,
      theme: theme,
      baseStyle: style ?? const TextStyle(),
    );
  }
}
