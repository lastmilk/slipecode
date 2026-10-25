import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipecode/editor/highlight_theme.dart';
import 'package:slipecode/editor/syntax_highlighter.dart';
import 'package:slipecode/editor/token.dart';

void main() {
  group('Dart 词法高亮', () {
    test('所有 token 拼回原文', () {
      const source = '''
// 计数器示例
class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

/* 多行
   注释 */
final text = r'raw\\string';
final triple = """hello
world""";
final hex = 0xFF;
''';
      final tokens = SyntaxHighlighter.tokenize(source, 'dart');
      expect(tokens.map((token) => token.text).join(), source);
    });

    test('识别关键字、类型、字符串、数字、注释、注解与函数', () {
      const source = '''
// 注释
@override
Widget build(BuildContext context) {
  final int count = 42;
  final String label = 'counter';
  return Text(label);
}
''';
      final tokens = SyntaxHighlighter.tokenize(source, 'dart');

      TokenType typeOf(String text) =>
          tokens.firstWhere((token) => token.text == text).type;

      expect(typeOf('Widget'), TokenType.type);
      expect(typeOf('final'), TokenType.keyword);
      expect(typeOf('int'), TokenType.type);
      expect(typeOf('42'), TokenType.number);
      expect(typeOf("'counter'"), TokenType.string);
      expect(typeOf('@override'), TokenType.annotation);
      expect(typeOf('build'), TokenType.function);
      expect(typeOf('return'), TokenType.keyword);
      expect(
        tokens.any((token) => token.type == TokenType.comment),
        isTrue,
      );
    });

    test('不会把字符串中的注释记号当成注释', () {
      const source = "final url = 'https://example.com'; // 真正的注释";
      final tokens = SyntaxHighlighter.tokenize(source, 'dart');
      final strings =
          tokens.where((token) => token.type == TokenType.string).toList();
      expect(strings, hasLength(1));
      expect(strings.single.text, contains('https://example.com'));
      expect(
        tokens.any((token) => token.type == TokenType.comment),
        isTrue,
      );
    });
  });

  group('其他语言', () {
    test('YAML 键与注释', () {
      const source = 'name: slipecode\n# 注释\nversion: 1.0.0\n';
      final tokens = SyntaxHighlighter.tokenize(source, 'yaml');
      expect(
        tokens.any(
          (token) => token.type == TokenType.type && token.text == 'name',
        ),
        isTrue,
      );
      expect(
        tokens.any((token) => token.type == TokenType.comment),
        isTrue,
      );
    });

    test('JSON 键与布尔值', () {
      const source = '{"enabled": true, "count": 3}';
      final tokens = SyntaxHighlighter.tokenize(source, 'json');
      expect(
        tokens.any(
          (token) => token.type == TokenType.type && token.text == '"enabled"',
        ),
        isTrue,
      );
      expect(
        tokens.any(
          (token) => token.type == TokenType.keyword && token.text == 'true',
        ),
        isTrue,
      );
      expect(
        tokens.map((token) => token.text).join(),
        source,
      );
    });

    test('Markdown 标题与代码块', () {
      const source = '# 标题\n\n```dart\nvoid main() {}\n```\n';
      final tokens = SyntaxHighlighter.tokenize(source, 'markdown');
      expect(
        tokens.any((token) => token.type == TokenType.keyword),
        isTrue,
      );
      expect(
        tokens.any((token) => token.type == TokenType.string),
        isTrue,
      );
    });

    test('纯文本语言仍可识别字符串与注释', () {
      const source = 'key = "value" // note';
      final tokens = SyntaxHighlighter.tokenize(source, 'plain');
      expect(
        tokens.any((token) => token.type == TokenType.string),
        isTrue,
      );
      expect(
        tokens.any((token) => token.type == TokenType.comment),
        isTrue,
      );
    });
  });

  group('TextSpan 构建', () {
    test('关键字使用主题色', () {
      const source = 'final int answer = 42;';
      final span = SyntaxHighlighter.buildSpan(
        text: source,
        language: 'dart',
        theme: HighlightTheme.dark,
      );

      final children = span.children!.cast<TextSpan>();
      final keyword = children.firstWhere((child) => child.text == 'final');
      expect(keyword.style?.color, HighlightTheme.dark.keyword);

      final plain = children.firstWhere(
        (child) => (child.text ?? '').contains('answer'),
      );
      expect(plain.style?.color, HighlightTheme.dark.plain);
    });

    test('空文本返回空 span 列表', () {
      final span = SyntaxHighlighter.buildSpan(
        text: '',
        language: 'dart',
        theme: HighlightTheme.dark,
      );
      expect(span.children, isEmpty);
      expect(span.style?.color, HighlightTheme.dark.plain);
    });
  });
}
