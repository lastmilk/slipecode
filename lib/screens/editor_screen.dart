import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../editor/code_controller.dart';
import '../editor/code_editor.dart';
import '../editor/cursor_info.dart';
import '../editor/highlight_theme.dart';
import '../editor/syntax_language.dart';
import '../models/file_node.dart';
import '../models/project.dart';
import '../services/file_service.dart';
import '../theme/app_theme.dart';
import '../utils/dialogs.dart';
import '../widgets/file_tree_panel.dart';
import 'terminal_screen.dart';

enum _UnsavedAction { save, discard }

class _OpenDocument {
  _OpenDocument({
    required this.node,
    required this.controller,
    required this.undoController,
    required this.savedText,
  });

  final FileNode node;
  final CodeController controller;
  final UndoHistoryController undoController;
  String savedText;

  bool get isDirty => controller.text != savedText;

  LanguageSpec get language => LanguageSpec.forPath(node.path);

  void dispose() {
    controller.dispose();
    undoController.dispose();
  }
}

/// 项目编辑器：文件树 + 多标签代码编辑。
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.project});

  final Project project;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const _editorTheme = HighlightTheme.dark;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FileService _fileService = FileService();

  FileNode? _root;
  bool _treeLoading = true;
  String? _treeError;

  final Map<String, _OpenDocument> _documents = {};
  final List<String> _openPaths = [];
  String? _activePath;

  _OpenDocument? get _activeDocument =>
      _activePath == null ? null : _documents[_activePath];

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  @override
  void dispose() {
    for (final document in _documents.values) {
      document.dispose();
    }
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _closeDrawer() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    }
  }

  Future<void> _loadTree({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _treeLoading = true;
        _treeError = null;
      });
    }
    try {
      final tree = await _fileService.loadTree(widget.project.directory);
      if (!mounted) return;

      final existing = <String>{};
      void collect(FileNode node) {
        if (node.isDirectory) {
          for (final child in node.children) {
            collect(child);
          }
        } else {
          existing.add(node.path);
        }
      }

      collect(tree);

      final removed = <_OpenDocument>[];
      for (final path in _documents.keys.toList()) {
        if (!existing.contains(path)) {
          final document = _documents.remove(path);
          if (document != null) {
            removed.add(document);
            _openPaths.remove(path);
          }
        }
      }
      for (final document in removed) {
        document.dispose();
      }

      setState(() {
        _root = tree;
        _treeLoading = false;
        _treeError = null;
        if (_activePath != null && !_documents.containsKey(_activePath)) {
          _activePath = _openPaths.isEmpty ? null : _openPaths.last;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _treeLoading = false;
        _treeError = '$error';
      });
    }
  }

  Future<void> _openFile(FileNode node) async {
    if (node.isDirectory) return;

    if (_documents.containsKey(node.path)) {
      setState(() => _activePath = node.path);
      _closeDrawer();
      return;
    }

    final file = File(node.path);
    try {
      final length = await file.length();
      if (length > 512 * 1024) {
        _toast('文件超过 512 KB，暂不支持在手机上编辑');
        return;
      }
      final content = await file.readAsString();
      if (!mounted) return;

      final language = LanguageSpec.forPath(node.path);
      final document = _OpenDocument(
        node: node,
        controller: CodeController(text: content, language: language.id),
        undoController: UndoHistoryController(),
        savedText: content,
      );

      setState(() {
        _documents[node.path] = document;
        _openPaths.add(node.path);
        _activePath = node.path;
      });
      _closeDrawer();
    } catch (error) {
      _toast('无法以文本方式打开该文件');
    }
  }

  void _selectDocument(String path) {
    if (_activePath == path) return;
    setState(() => _activePath = path);
  }

  Future<bool> _saveDocument(_OpenDocument document) async {
    try {
      await _fileService.writeText(File(document.node.path), document.controller.text);
      document.savedText = document.controller.text;
      if (mounted) setState(() {});
      return true;
    } catch (error) {
      _toast('保存失败：$error');
      return false;
    }
  }

  Future<void> _saveAll() async {
    final dirty = _documents.values.where((document) => document.isDirty).toList();
    if (dirty.isEmpty) {
      _toast('没有需要保存的修改');
      return;
    }
    for (final document in dirty) {
      final saved = await _saveDocument(document);
      if (!saved) return;
    }
    _toast('已保存 ${dirty.length} 个文件');
  }

  Future<void> _closeDocument(String path) async {
    final document = _documents[path];
    if (document == null) return;

    if (document.isDirty) {
      final action = await _askUnsaved(document.node.name);
      if (action == null) return;
      if (action == _UnsavedAction.save) {
        final saved = await _saveDocument(document);
        if (!saved) return;
      }
    }

    if (!mounted) return;
    setState(() {
      _documents.remove(path);
      _openPaths.remove(path);
      if (_activePath == path) {
        _activePath = _openPaths.isEmpty ? null : _openPaths.last;
      }
    });
    document.dispose();
  }

  Future<_UnsavedAction?> _askUnsaved(String name) {
    return showDialog<_UnsavedAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('未保存的修改'),
        content: Text('「$name」还有未保存的修改，要保存吗？'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.discard),
            child: const Text('不保存'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.save),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<_UnsavedAction?> _askUnsavedAll(int count) {
    return showDialog<_UnsavedAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('未保存的修改'),
        content: Text('有 $count 个文件尚未保存，离开前要保存吗？'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.discard),
            child: const Text('不保存'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.save),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBack() async {
    final dirty =
        _documents.values.where((document) => document.isDirty).toList();
    if (dirty.isNotEmpty) {
      final action = await _askUnsavedAll(dirty.length);
      if (action == null) return;
      if (action == _UnsavedAction.save) {
        for (final document in dirty) {
          final saved = await _saveDocument(document);
          if (!saved) return;
        }
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _createFile(FileNode parent) async {
    if (!parent.isDirectory) return;
    final name = await showNameDialog(
      context,
      title: '新建文件',
      hint: '例如 main.dart',
      initialValue: 'new_file.dart',
      description: '文件将创建在 ${_relativePath(parent.path)}',
      validator: FileService.validateName,
    );
    if (name == null || !mounted) return;

    try {
      final file =
          await _fileService.createFile(Directory(parent.path), name);
      await _loadTree();
      if (!mounted) return;
      await _openFile(FileNode(
        name: p.basename(file.path),
        path: file.path,
        isDirectory: false,
      ));
    } catch (error) {
      _toast('创建文件失败：$error');
    }
  }

  Future<void> _createFolder(FileNode parent) async {
    if (!parent.isDirectory) return;
    final name = await showNameDialog(
      context,
      title: '新建文件夹',
      hint: '例如 widgets',
      initialValue: '',
      description: '文件夹将创建在 ${_relativePath(parent.path)}',
      validator: FileService.validateName,
    );
    if (name == null || !mounted) return;

    try {
      await _fileService.createDirectory(Directory(parent.path), name);
      await _loadTree();
    } catch (error) {
      _toast('创建文件夹失败：$error');
    }
  }

  Future<void> _renameNode(FileNode node) async {
    final name = await showNameDialog(
      context,
      title: '重命名',
      hint: '新名称',
      initialValue: node.name,
      validator: FileService.validateName,
    );
    if (name == null || name == node.name || !mounted) return;

    try {
      await _closeDocumentsUnder(node.path);
      final entity =
          node.isDirectory ? Directory(node.path) : File(node.path);
      await _fileService.rename(entity, name);
      await _loadTree();
    } catch (error) {
      _toast('重命名失败：$error');
    }
  }

  Future<void> _deleteNode(FileNode node) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除${node.isDirectory ? '文件夹' : '文件'}',
      message: node.isDirectory
          ? '确定删除文件夹「${node.name}」及其中的所有内容？此操作无法恢复。'
          : '确定删除文件「${node.name}」？此操作无法恢复。',
    );
    if (!confirmed || !mounted) return;

    try {
      await _closeDocumentsUnder(node.path);
      final entity =
          node.isDirectory ? Directory(node.path) : File(node.path);
      await _fileService.delete(entity, recursive: true);
      await _loadTree();
    } catch (error) {
      _toast('删除失败：$error');
    }
  }

  /// 关闭某个路径下所有已打开的文件（重命名 / 删除前调用）。
  Future<void> _closeDocumentsUnder(String pathPrefix) async {
    final affected = _documents.values
        .where((document) =>
            document.node.path == pathPrefix ||
            p.isWithin(pathPrefix, document.node.path))
        .toList();
    if (affected.isEmpty) return;

    for (final document in affected) {
      if (document.isDirty) {
        try {
          await _fileService.writeText(
            File(document.node.path),
            document.controller.text,
          );
        } on FileSystemException {
          // 忽略保存失败，继续关闭
        }
      }
      _documents.remove(document.node.path);
      _openPaths.remove(document.node.path);
      document.dispose();
    }

    if (!mounted) return;
    setState(() {
      if (_activePath != null && !_documents.containsKey(_activePath)) {
        _activePath = _openPaths.isEmpty ? null : _openPaths.last;
      }
    });
  }

  String _relativePath(String path) {
    final relative = p.relative(path, from: widget.project.path);
    if (relative == '.' || relative.isEmpty) return widget.project.name;
    return p.split(relative).join(' / ');
  }

  /// 打开项目终端；进入前先保存未保存的文件，返回后刷新文件树。
  Future<void> _openTerminal() async {
    if (_documents.values.any((document) => document.isDirty)) {
      await _saveAll();
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TerminalScreen(project: widget.project),
      ),
    );
    if (mounted) await _loadTree();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 820;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _buildAppBar(context, wide),
        drawer: wide
            ? null
            : Drawer(
                width: 310,
                backgroundColor: Theme.of(context).colorScheme.surface,
                child: SafeArea(child: _buildTreePanel(context)),
              ),
        body: wide
            ? Row(
                children: [
                  SizedBox(width: 310, child: _buildTreePanel(context)),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                  Expanded(child: _buildEditorArea(context)),
                ],
              )
            : _buildEditorArea(context),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, bool wide) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: _handleBack,
        tooltip: '返回',
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.project.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Flutter 项目 · ${_openPaths.length} 个文件已打开',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
      actions: [
        if (!wide)
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: '文件',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        IconButton(
          icon: const Icon(Icons.terminal_rounded),
          tooltip: '终端',
          onPressed: _openTerminal,
        ),
        IconButton(
          icon: const Icon(Icons.save_outlined),
          tooltip: '保存全部',
          onPressed: _openPaths.isEmpty ? null : _saveAll,
        ),
      ],
    );
  }

  Widget _buildTreePanel(BuildContext context) {
    if (_treeLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_treeError != null) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 30, color: scheme.error),
              const SizedBox(height: 10),
              Text(
                '读取项目文件失败',
                style: TextStyle(color: scheme.onSurface, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _loadTree(showLoading: true),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final root = _root;
    if (root == null) return const SizedBox.shrink();

    return FileTreePanel(
      root: root,
      projectName: widget.project.name,
      activePath: _activePath,
      openPaths: _openPaths.toSet(),
      onOpenFile: _openFile,
      onCreateFile: _createFile,
      onCreateFolder: _createFolder,
      onRenameNode: _renameNode,
      onDeleteNode: _deleteNode,
    );
  }

  Widget _buildEditorArea(BuildContext context) {
    final document = _activeDocument;

    return Material(
      color: _editorTheme.background,
      child: Column(
        children: [
          if (_openPaths.isNotEmpty) _buildTabBar(context),
          if (document == null)
            Expanded(child: _buildEditorEmpty(context))
          else ...[
            _buildBreadcrumb(document),
            Expanded(
              child: CodeEditor(
                key: ValueKey(document.node.path),
                controller: document.controller,
                undoController: document.undoController,
                onSave: () => _saveDocument(document),
              ),
            ),
            _buildStatusBar(document),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _editorTheme.toolbar,
        border: Border(
          bottom: BorderSide(color: _editorTheme.border),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _openPaths.length,
        itemBuilder: (context, index) {
          final path = _openPaths[index];
          final document = _documents[path];
          if (document == null) return const SizedBox.shrink();
          return _buildTab(document);
        },
      ),
    );
  }

  Widget _buildTab(_OpenDocument document) {
    final active = document.node.path == _activePath;
    return AnimatedBuilder(
      animation: document.controller,
      builder: (context, _) {
        final dirty = document.isDirty;
        return Material(
          color: active ? _editorTheme.background : _editorTheme.toolbar,
          child: InkWell(
            onTap: () => _selectDocument(document.node.path),
            child: Container(
              padding: const EdgeInsets.only(left: 12, right: 6),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: _editorTheme.border),
                  bottom: BorderSide(
                    color: active ? _editorTheme.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.code_rounded,
                    size: 13,
                    color: active
                        ? _editorTheme.accent
                        : _editorTheme.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    document.node.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: active
                          ? _editorTheme.plain
                          : _editorTheme.muted,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkResponse(
                    radius: 14,
                    onTap: () => _closeDocument(document.node.path),
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: Center(
                        child: dirty
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.warning,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: _editorTheme.muted,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreadcrumb(_OpenDocument document) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _editorTheme.background,
        border: Border(
          bottom: BorderSide(
            color: _editorTheme.border.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _relativePath(document.node.path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: _editorTheme.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _editorTheme.toolbar,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _editorTheme.border),
            ),
            child: Text(
              document.language.label,
              style: TextStyle(
                fontSize: 10,
                color: _editorTheme.muted,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: document.controller,
            builder: (context, _) {
              final dirty = document.isDirty;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dirty
                          ? AppColors.warning
                          : AppColors.success.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    dirty ? '未保存' : '已保存',
                    style: TextStyle(
                      fontSize: 10,
                      color: _editorTheme.muted,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(_OpenDocument document) {
    return Container(
      height: 27,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _editorTheme.toolbar,
        border: Border(top: BorderSide(color: _editorTheme.border)),
      ),
      child: AnimatedBuilder(
        animation: document.controller,
        builder: (context, _) {
          final text = document.controller.text;
          final info = cursorInfoOf(text, document.controller.selection.baseOffset);
          return Row(
            children: [
              Text(
                'Ln ${info.line}, Col ${info.column}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: _editorTheme.muted,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Text(
                '${lineCountOf(text)} 行 · ${text.length} 字符',
                style: TextStyle(
                  fontSize: 10.5,
                  color: _editorTheme.muted,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                document.language.label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: _editorTheme.muted,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditorEmpty(BuildContext context) {
    final root = _root;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _editorTheme.accent.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.code_rounded,
                size: 32,
                color: _editorTheme.accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '未打开文件',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _editorTheme.plain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '从文件树中选择一个文件，\n或新建文件开始编写代码。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: _editorTheme.muted,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: root == null ? null : () => _createFile(root),
              style: OutlinedButton.styleFrom(
                foregroundColor: _editorTheme.plain,
                side: BorderSide(color: _editorTheme.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.note_add_outlined, size: 18),
              label: const Text('新建文件'),
            ),
          ],
        ),
      ),
    );
  }
}
