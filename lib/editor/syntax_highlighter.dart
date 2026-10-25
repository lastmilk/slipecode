import 'package:flutter/material.dart';

import 'highlight_theme.dart';
import 'token.dart';

/// 轻量语法高亮器：把源码切成 token，再转换为 [TextSpan]。
class SyntaxHighlighter {
  const SyntaxHighlighter._();

  static TextSpan buildSpan({
    required String text,
    required String language,
    required HighlightTheme theme,
    TextStyle baseStyle = const TextStyle(),
  }) {
    final tokens = tokenize(text, language);
    final children = <TextSpan>[];
    for (final token in tokens) {
      children.add(TextSpan(
        text: token.text,
        style: baseStyle.copyWith(color: theme.colorFor(token.type)),
      ));
    }
    return TextSpan(
      style: baseStyle.copyWith(color: theme.colorFor(TokenType.plain)),
      children: children,
    );
  }

  static List<Token> tokenize(String source, String language) {
    if (source.isEmpty) return const [];
    final List<Token> tokens;
    switch (language) {
      case 'dart':
        tokens = _tokenizeDart(source);
        break;
      case 'yaml':
        tokens = _tokenizeYaml(source);
        break;
      case 'json':
        tokens = _tokenizeJson(source);
        break;
      case 'markdown':
        tokens = _tokenizeMarkdown(source);
        break;
      default:
        tokens = _tokenizePlain(source);
    }
    return _compact(tokens);
  }

  // ---------------------------------------------------------------------------
  // Dart
  // ---------------------------------------------------------------------------

  static const _dartKeywords = <String>{
    'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case',
    'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
    'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
    'external', 'factory', 'false', 'final', 'finally', 'for', 'Function',
    'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is',
    'late', 'library', 'mixin', 'new', 'null', 'on', 'operator', 'part',
    'required', 'rethrow', 'return', 'sealed', 'set', 'show', 'static',
    'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'typedef',
    'var', 'void', 'when', 'while', 'with', 'yield',
  };

  static const _dartTypes = <String>{
    'int', 'double', 'num', 'String', 'bool', 'List', 'Map', 'Set', 'Future',
    'FutureOr', 'Stream', 'Iterable', 'Object', 'Never', 'Duration',
    'DateTime', 'Symbol', 'Type', 'Record',
  };

  static bool _isLetter(int code) =>
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      code == 95 ||
      code == 36 ||
      code > 127;

  static bool _isDigit(int code) => code >= 48 && code <= 57;

  static bool _isIdent(int code) => _isLetter(code) || _isDigit(code);

  static bool _isSpace(int code) =>
      code == 32 || code == 9 || code == 10 || code == 13;

  static bool _isHex(int code) =>
      _isDigit(code) ||
      (code >= 65 && code <= 70) ||
      (code >= 97 && code <= 102);

  static List<Token> _tokenizeDart(String src) {
    final tokens = <Token>[];
    final length = src.length;
    var i = 0;

    void emit(TokenType type, String text) {
      if (text.isEmpty) return;
      tokens.add(Token(type, text));
    }

    while (i < length) {
      final code = src.codeUnitAt(i);
      final char = src[i];

      if (_isSpace(code)) {
        var end = i + 1;
        while (end < length && _isSpace(src.codeUnitAt(end))) {
          end++;
        }
        emit(TokenType.plain, src.substring(i, end));
        i = end;
        continue;
      }

      // 注释
      if (char == '/' && i + 1 < length) {
        final next = src[i + 1];
        if (next == '/') {
          var end = i + 2;
          while (end < length && src[end] != '\n') {
            end++;
          }
          emit(TokenType.comment, src.substring(i, end));
          i = end;
          continue;
        }
        if (next == '*') {
          var end = i + 2;
          var depth = 1;
          while (end < length && depth > 0) {
            if (src[end] == '/' && end + 1 < length && src[end + 1] == '*') {
              depth++;
              end += 2;
            } else if (src[end] == '*' &&
                end + 1 < length &&
                src[end + 1] == '/') {
              depth--;
              end += 2;
            } else {
              end++;
            }
          }
          emit(TokenType.comment, src.substring(i, end));
          i = end;
          continue;
        }
      }

      // 字符串（含 raw 前缀）
      if (char == 'r' &&
          i + 1 < length &&
          (src[i + 1] == "'" || src[i + 1] == '"')) {
        final end = _scanDartString(src, i + 1, raw: true);
        emit(TokenType.string, src.substring(i, end));
        i = end;
        continue;
      }
      if (char == "'" || char == '"') {
        final end = _scanDartString(src, i);
        emit(TokenType.string, src.substring(i, end));
        i = end;
        continue;
      }

      // 注解
      if (char == '@' && i + 1 < length && _isLetter(src.codeUnitAt(i + 1))) {
        var end = i + 1;
        while (end < length && _isIdent(src.codeUnitAt(end))) {
          end++;
        }
        emit(TokenType.annotation, src.substring(i, end));
        i = end;
        continue;
      }

      // 数字
      if (_isDigit(code) ||
          (char == '.' &&
              i + 1 < length &&
              _isDigit(src.codeUnitAt(i + 1)))) {
        var end = i;
        if (src[end] == '0' &&
            end + 1 < length &&
            (src[end + 1] == 'x' || src[end + 1] == 'X')) {
          end += 2;
          while (end < length && _isHex(src.codeUnitAt(end))) {
            end++;
          }
        } else {
          while (end < length && _isDigit(src.codeUnitAt(end))) {
            end++;
          }
          if (end + 1 < length &&
              src[end] == '.' &&
              _isDigit(src.codeUnitAt(end + 1))) {
            end++;
            while (end < length && _isDigit(src.codeUnitAt(end))) {
              end++;
            }
          }
          if (end < length && (src[end] == 'e' || src[end] == 'E')) {
            var probe = end + 1;
            if (probe < length && (src[probe] == '+' || src[probe] == '-')) {
              probe++;
            }
            if (probe < length && _isDigit(src.codeUnitAt(probe))) {
              probe++;
              while (probe < length && _isDigit(src.codeUnitAt(probe))) {
                probe++;
              }
              end = probe;
            }
          }
        }
        emit(TokenType.number, src.substring(i, end));
        i = end;
        continue;
      }

      // 标识符 / 关键字
      if (_isLetter(code)) {
        var end = i + 1;
        while (end < length && _isIdent(src.codeUnitAt(end))) {
          end++;
        }
        final word = src.substring(i, end);
        if (_dartKeywords.contains(word)) {
          emit(TokenType.keyword, word);
        } else if (_dartTypes.contains(word)) {
          emit(TokenType.type, word);
        } else {
          var probe = end;
          while (probe < length && _isSpace(src.codeUnitAt(probe))) {
            probe++;
          }
          final isCall = probe < length && src[probe] == '(';
          final isTypeName = word.codeUnitAt(0) >= 65 && word.codeUnitAt(0) <= 90;
          if (isCall) {
            emit(TokenType.function, word);
          } else if (isTypeName) {
            emit(TokenType.type, word);
          } else {
            emit(TokenType.plain, word);
          }
        }
        i = end;
        continue;
      }

      if ('{}()[];,.:'.contains(char)) {
        emit(TokenType.punctuation, char);
        i++;
        continue;
      }

      if ('+-*/%=<>!&|^~?'.contains(char)) {
        var end = i + 1;
        while (end < length && '+-*/%=<>!&|^~?'.contains(src[end])) {
          end++;
        }
        emit(TokenType.operator, src.substring(i, end));
        i = end;
        continue;
      }

      emit(TokenType.plain, char);
      i++;
    }

    return tokens;
  }

  /// 返回字符串结束位置（不含）。
  static int _scanDartString(String src, int quoteIndex, {bool raw = false}) {
    final length = src.length;
    final quote = src[quoteIndex];
    final triple = quoteIndex + 2 < length &&
        src[quoteIndex + 1] == quote &&
        src[quoteIndex + 2] == quote;
    var i = quoteIndex + (triple ? 3 : 1);

    while (i < length) {
      final char = src[i];
      if (!raw && char == '\\') {
        i += 2;
        continue;
      }
      if (triple) {
        if (char == quote &&
            i + 2 < length &&
            src[i + 1] == quote &&
            src[i + 2] == quote) {
          return i + 3;
        }
        i++;
      } else {
        if (char == quote) return i + 1;
        if (char == '\n') return i;
        i++;
      }
    }
    return length;
  }

  // ---------------------------------------------------------------------------
  // YAML
  // ---------------------------------------------------------------------------

  static List<Token> _tokenizeYaml(String src) {
    final lines = src.split('\n');
    final tokens = <Token>[];
    for (var index = 0; index < lines.length; index++) {
      if (index > 0) tokens.add(const Token(TokenType.plain, '\n'));
      final line = lines[index];
      var hash = -1;
      var inSingle = false;
      var inDouble = false;
      for (var i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == "'" && !inDouble) {
          inSingle = !inSingle;
        } else if (char == '"' && !inSingle) {
          inDouble = !inDouble;
        } else if (char == '#' &&
            !inSingle &&
            !inDouble &&
            (i == 0 || line[i - 1] == ' ' || line[i - 1] == '\t')) {
          hash = i;
          break;
        }
      }

      final code = hash >= 0 ? line.substring(0, hash) : line;
      final comment = hash >= 0 ? line.substring(hash) : '';
      _tokenizeYamlLine(code, tokens);
      if (comment.isNotEmpty) {
        tokens.add(Token(TokenType.comment, comment));
      }
    }
    return tokens;
  }

  static void _tokenizeYamlLine(String line, List<Token> tokens) {
    if (line.isEmpty) return;

    var rest = line;
    final indent = RegExp(r'^\s+').firstMatch(line);
    if (indent != null) {
      tokens.add(Token(TokenType.plain, indent.group(0)!));
      rest = line.substring(indent.end);
    }

    while (rest.startsWith('- ')) {
      tokens.add(const Token(TokenType.punctuation, '- '));
      rest = rest.substring(2);
    }

    final colon = rest.indexOf(':');
    if (colon > 0) {
      final key = rest.substring(0, colon);
      if (key.trim().isNotEmpty && !key.contains('{') && !key.contains('[')) {
        tokens.add(Token(TokenType.type, key));
        tokens.add(const Token(TokenType.punctuation, ':'));
        rest = rest.substring(colon + 1);
        if (rest.startsWith(' ')) {
          tokens.add(const Token(TokenType.plain, ' '));
          rest = rest.substring(1);
        }
      }
    }

    _appendWithPattern(rest, _valuePattern, tokens);
  }

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  static final RegExp _jsonPattern = RegExp(
    r"""(?<string>"(?:[^"\\]|\\.)*")|(?<keyword>\b(?:true|false|null)\b)"""
    r"""|(?<number>-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(?<punctuation>[{}\[\],:])""",
  );

  static List<Token> _tokenizeJson(String src) {
    final tokens = <Token>[];
    var last = 0;
    for (final match in _jsonPattern.allMatches(src)) {
      if (match.start > last) {
        tokens.add(Token(TokenType.plain, src.substring(last, match.start)));
      }
      var type = _tokenTypeOf(match);
      if (type == TokenType.string) {
        var probe = match.end;
        while (probe < src.length &&
            (src[probe] == ' ' || src[probe] == '\t')) {
          probe++;
        }
        if (probe < src.length && src[probe] == ':') {
          type = TokenType.type;
        }
      }
      tokens.add(Token(type, match.group(0)!));
      last = match.end;
    }
    if (last < src.length) {
      tokens.add(Token(TokenType.plain, src.substring(last)));
    }
    return tokens;
  }

  // ---------------------------------------------------------------------------
  // Markdown
  // ---------------------------------------------------------------------------

  static final RegExp _markdownInline = RegExp(
    r"""(?<strong>\*\*[^*\n]+\*\*)|(?<code>`[^`\n]+`)|(?<link>\[[^\]\n]*\]\([^)\n]*\))""",
  );

  static List<Token> _tokenizeMarkdown(String src) {
    final lines = src.split('\n');
    final tokens = <Token>[];
    var inFence = false;

    for (var index = 0; index < lines.length; index++) {
      if (index > 0) tokens.add(const Token(TokenType.plain, '\n'));
      final line = lines[index];
      final trimmed = line.trimLeft();
      final isFence = trimmed.startsWith('```');

      if (inFence) {
        tokens.add(Token(TokenType.string, line));
        if (isFence) inFence = false;
        continue;
      }
      if (isFence) {
        inFence = true;
        tokens.add(Token(TokenType.string, line));
        continue;
      }
      if (trimmed.startsWith('#')) {
        tokens.add(Token(TokenType.keyword, line));
        continue;
      }
      if (trimmed.startsWith('>')) {
        tokens.add(Token(TokenType.comment, line));
        continue;
      }

      var rest = line;
      final listMarker = RegExp(r'^(\s*)([-*+]|\d+\.)(\s+)').firstMatch(line);
      if (listMarker != null) {
        tokens.add(Token(TokenType.plain, listMarker.group(1)!));
        tokens.add(Token(TokenType.punctuation, listMarker.group(2)!));
        tokens.add(Token(TokenType.plain, listMarker.group(3)!));
        rest = line.substring(listMarker.end);
      }

      _appendWithPattern(rest, _markdownInline, tokens);
    }
    return tokens;
  }

  // ---------------------------------------------------------------------------
  // 通用
  // ---------------------------------------------------------------------------

  static final RegExp _valuePattern = RegExp(
    r"""(?<string>"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')"""
    r"""|(?<keyword>\b(?:true|false|null|yes|no|on|off)\b)|(?<number>-?\d+(?:\.\d+)?\b)""",
  );

  static final RegExp _plainPattern = RegExp(
    r"""(?<comment>//[^\n]*|\#[^\n]*)|(?<string>"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')"""
    r"""|(?<number>\b\d+(?:\.\d+)?\b)""",
  );

  static List<Token> _tokenizePlain(String src) {
    final tokens = <Token>[];
    _appendWithPattern(src, _plainPattern, tokens);
    return tokens;
  }

  static void _appendWithPattern(
    String src,
    RegExp pattern,
    List<Token> tokens,
  ) {
    var last = 0;
    for (final match in pattern.allMatches(src)) {
      if (match.start > last) {
        tokens.add(Token(TokenType.plain, src.substring(last, match.start)));
      }
      tokens.add(Token(_tokenTypeOf(match), match.group(0)!));
      last = match.end;
    }
    if (last < src.length) {
      tokens.add(Token(TokenType.plain, src.substring(last)));
    }
  }

  static TokenType _tokenTypeOf(RegExpMatch match) {
    for (final name in match.groupNames) {
      if (match.namedGroup(name) == null) continue;
      switch (name) {
        case 'comment':
          return TokenType.comment;
        case 'string':
        case 'code':
          return TokenType.string;
        case 'keyword':
          return TokenType.keyword;
        case 'number':
          return TokenType.number;
        case 'punctuation':
          return TokenType.punctuation;
        case 'strong':
          return TokenType.type;
        case 'link':
          return TokenType.function;
      }
    }
    return TokenType.plain;
  }

  static List<Token> _compact(List<Token> tokens) {
    final result = <Token>[];
    for (final token in tokens) {
      if (token.text.isEmpty) continue;
      if (result.isNotEmpty && result.last.type == token.type) {
        result[result.length - 1] =
            Token(token.type, result.last.text + token.text);
      } else {
        result.add(token);
      }
    }
    return result;
  }
}
