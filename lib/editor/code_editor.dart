import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'code_controller.dart';
import 'cursor_info.dart';
import 'highlight_theme.dart';

/// 代码编辑器：行号、语法高亮、横向滚动、快捷符号栏、撤销/重做。
class CodeEditor extends StatefulWidget {
  const CodeEditor({
    super.key,
    required this.controller,
    required this.undoController,
    this.onSave,
  });

  final CodeController controller;
  final UndoHistoryController undoController;
  final VoidCallback? onSave;

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  static const double _fontSize = 13.5;
  static const double _lineHeightFactor = 1.55;
  static const double _gutterWidth = 46;
  static const double _topPadding = 14;
  static const double _bottomPadding = 72;
  static const TextStyle _codeStyle = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Courier New'],
    fontSize: _fontSize,
    height: _lineHeightFactor,
    letterSpacing: 0,
  );

  static const List<(String, String)> _snippets = [
    ('⇥', '  '),
    ('{ }', '{}'),
    ('( )', '()'),
    ('[ ]', '[]'),
    ('" "', '""'),
    ("' '", "''"),
    (';', ';'),
    (':', ':'),
    ('=>', ' => '),
  ];

  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();
  final FocusNode _focus = FocusNode();

  late final double _charWidth = _measureCharWidth();

  double get _lineHeight => _fontSize * _lineHeightFactor;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant CodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
      if (_vertical.hasClients) _vertical.jumpTo(0);
      if (_horizontal.hasClients) _horizontal.jumpTo(0);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _vertical.dispose();
    _horizontal.dispose();
    _focus.dispose();
    super.dispose();
  }

  double _measureCharWidth() {
    final painter = TextPainter(
      text: const TextSpan(text: 'M', style: _codeStyle),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  void _handleControllerChange() {
    if (!mounted) return;
    _ensureCaretVisible();
  }

  void _ensureCaretVisible() {
    final selection = widget.controller.selection;
    if (!selection.isValid) return;
    final text = widget.controller.text;
    final info = cursorInfoOf(text, selection.baseOffset);

    if (_vertical.hasClients &&
        _vertical.position.hasContentDimensions &&
        _vertical.position.hasViewportDimension) {
      final y = _topPadding + (info.line - 1) * _lineHeight;
      final viewport = _vertical.position.viewportDimension;
      final offset = _vertical.offset;
      final maxExtent = _vertical.position.maxScrollExtent;
      if (y < offset + 24) {
        _vertical.jumpTo(math.max(0, y - 48));
      } else if (y + _lineHeight + 48 > offset + viewport) {
        _vertical.jumpTo(
          math.min(maxExtent, y + _lineHeight + 64 - viewport),
        );
      }
    }

    if (_horizontal.hasClients &&
        _horizontal.position.hasContentDimensions &&
        _horizontal.position.hasViewportDimension) {
      final x = _gutterWidth + 12 + (info.column - 1) * _charWidth;
      final viewport = _horizontal.position.viewportDimension;
      final offset = _horizontal.offset;
      final maxExtent = _horizontal.position.maxScrollExtent;
      if (x < offset + 24) {
        _horizontal.jumpTo(math.max(0, x - 48));
      } else if (x + 24 > offset + viewport) {
        _horizontal.jumpTo(
          math.min(maxExtent, x + 64 - viewport),
        );
      }
    }
  }

  double _estimateContentWidth(String text) {
    var maxUnits = 0;
    var units = 0;
    for (final rune in text.runes) {
      if (rune == 10) {
        if (units > maxUnits) maxUnits = units;
        units = 0;
      } else if (rune == 9) {
        units += 2;
      } else if (rune > 0x2E7F) {
        units += 2;
      } else {
        units += 1;
      }
    }
    if (units > maxUnits) maxUnits = units;
    return maxUnits * _charWidth + 120;
  }

  void _insertSnippet(String before, [String? after]) {
    final value = widget.controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final selected = value.text.substring(start, end);
    final inserted = before + selected + (after ?? '');
    final text = value.text.replaceRange(start, end, inserted);
    final cursor = selected.isEmpty
        ? start + before.length
        : start + before.length + selected.length;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _focus.requestFocus();
    _ensureCaretVisible();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.controller.theme;
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final cursor = cursorInfoOf(text, selection.baseOffset);
    final lineCount = lineCountOf(text);
    final baseStyle = _codeStyle.copyWith(color: theme.plain);

    return MediaQuery.withNoTextScaling(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.tab): () {
            _insertSnippet('  ');
          },
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            widget.onSave?.call();
          },
        },
        child: TextSelectionTheme(
          data: TextSelectionThemeData(
            cursorColor: theme.cursor,
            selectionColor: theme.selection,
            selectionHandleColor: theme.accent,
          ),
          child: Container(
            color: theme.background,
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = math.max(
                        constraints.maxWidth - _gutterWidth,
                        _estimateContentWidth(text),
                      );
                      return Scrollbar(
                        controller: _vertical,
                        child: SingleChildScrollView(
                          controller: _vertical,
                          child: SingleChildScrollView(
                            controller: _horizontal,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: _gutterWidth + width,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: _gutterWidth,
                                    child: _buildGutter(
                                      theme,
                                      lineCount,
                                      cursor.line,
                                    ),
                                  ),
                                  SizedBox(
                                    width: width,
                                    child: _buildTextField(baseStyle, theme),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildToolbar(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGutter(HighlightTheme theme, int lineCount, int activeLine) {
    return Padding(
      padding: const EdgeInsets.only(top: _topPadding, bottom: _bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(lineCount, (index) {
          final line = index + 1;
          final isActive = line == activeLine;
          return SizedBox(
            height: _lineHeight,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$line',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    height: 1,
                    color: isActive ? theme.accent : theme.gutter,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTextField(TextStyle baseStyle, HighlightTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(
        top: _topPadding,
        bottom: _bottomPadding,
        right: 32,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        undoController: widget.undoController,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: baseStyle,
        strutStyle: const StrutStyle(
          fontFamily: 'monospace',
          fontSize: _fontSize,
          height: _lineHeightFactor,
          forceStrutHeight: true,
        ),
        cursorColor: theme.cursor,
        cursorWidth: 2,
        cursorRadius: const Radius.circular(1),
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        keyboardAppearance: Brightness.dark,
        textAlignVertical: TextAlignVertical.top,
        scrollPadding: const EdgeInsets.all(48),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildToolbar(HighlightTheme theme) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: theme.toolbar,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              children: [
                for (final snippet in _snippets)
                  _buildSnippetButton(theme, snippet),
              ],
            ),
          ),
          Container(width: 1, height: 20, color: theme.border),
          ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: widget.undoController,
            builder: (context, value, _) {
              return Row(
                children: [
                  _buildIconButton(
                    theme,
                    Icons.undo_rounded,
                    value.canUndo,
                    widget.undoController.undo,
                  ),
                  _buildIconButton(
                    theme,
                    Icons.redo_rounded,
                    value.canRedo,
                    widget.undoController.redo,
                  ),
                  const SizedBox(width: 4),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSnippetButton(HighlightTheme theme, (String, String) snippet) {
    final (label, insert) = snippet;
    final isPair = insert.length == 2 &&
        const ['{}', '()', '[]', '""', "''"].contains(insert);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => isPair
              ? _insertSnippet(insert[0], insert[1])
              : _insertSnippet(insert),
          child: Container(
            constraints: const BoxConstraints(minWidth: 34),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: theme.plain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(
    HighlightTheme theme,
    IconData icon,
    bool enabled,
    VoidCallback action,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? action : null,
        child: SizedBox(
          width: 34,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? theme.plain : theme.gutter,
          ),
        ),
      ),
    );
  }
}
