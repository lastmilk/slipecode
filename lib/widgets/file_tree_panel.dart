import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/file_node.dart';
import '../utils/file_icon.dart';

enum _NodeAction { createFile, createFolder, rename, delete }

/// 项目文件树面板。
class FileTreePanel extends StatefulWidget {
  const FileTreePanel({
    super.key,
    required this.root,
    required this.projectName,
    required this.activePath,
    required this.openPaths,
    required this.onOpenFile,
    required this.onCreateFile,
    required this.onCreateFolder,
    required this.onRenameNode,
    required this.onDeleteNode,
  });

  final FileNode root;
  final String projectName;
  final String? activePath;
  final Set<String> openPaths;
  final ValueChanged<FileNode> onOpenFile;
  final ValueChanged<FileNode> onCreateFile;
  final ValueChanged<FileNode> onCreateFolder;
  final ValueChanged<FileNode> onRenameNode;
  final ValueChanged<FileNode> onDeleteNode;

  @override
  State<FileTreePanel> createState() => _FileTreePanelState();
}

class _FileTreePanelState extends State<FileTreePanel> {
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _expandDefaults();
    _expandForActive();
  }

  @override
  void didUpdateWidget(covariant FileTreePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.root.path != widget.root.path) {
      _expanded.clear();
      _expandDefaults();
    }
    if (oldWidget.activePath != widget.activePath) {
      _expandForActive();
    }
  }

  void _expandDefaults() {
    _expanded.add(widget.root.path);
    for (final child in widget.root.children) {
      if (child.isDirectory && child.name == 'lib') {
        _expanded.add(child.path);
      }
    }
  }

  void _expandForActive() {
    final active = widget.activePath;
    if (active == null) return;
    var current = p.dirname(active);
    while (current.length >= widget.root.path.length) {
      _expanded.add(current);
      final parent = p.dirname(current);
      if (parent == current) break;
      current = parent;
    }
  }

  List<_FlatEntry> _flatten() {
    final entries = <_FlatEntry>[];
    void visit(FileNode node, int depth) {
      entries.add(_FlatEntry(node, depth));
      if (node.isDirectory && _expanded.contains(node.path)) {
        for (final child in node.children) {
          visit(child, depth + 1);
        }
      }
    }

    for (final child in widget.root.children) {
      visit(child, 0);
    }
    return entries;
  }

  void _toggle(FileNode node) {
    setState(() {
      if (!_expanded.remove(node.path)) {
        _expanded.add(node.path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = _flatten();

    return Material(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
          Expanded(
            child: entries.isEmpty
                ? _buildEmpty(scheme)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      return _buildRow(context, entries[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '文件',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => widget.onCreateFile(widget.root),
            icon: const Icon(Icons.note_add_outlined),
            iconSize: 20,
            tooltip: '新建文件',
          ),
          IconButton(
            onPressed: () => widget.onCreateFolder(widget.root),
            icon: const Icon(Icons.create_new_folder_outlined),
            iconSize: 20,
            tooltip: '新建文件夹',
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded,
                size: 32, color: scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              '项目还是空的',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _FlatEntry entry) {
    final scheme = Theme.of(context).colorScheme;
    final node = entry.node;
    final active = node.path == widget.activePath;
    final opened = widget.openPaths.contains(node.path);
    final expanded = _expanded.contains(node.path);
    final (icon, iconColor) = fileIconFor(node, scheme);

    return Material(
      color: active ? scheme.primary.withValues(alpha: 0.12) : Colors.transparent,
      child: InkWell(
        onTap: () {
          if (node.isDirectory) {
            _toggle(node);
          } else {
            widget.onOpenFile(node);
          }
        },
        child: SizedBox(
          height: 38,
          child: Row(
            children: [
              SizedBox(width: 10 + entry.depth * 14),
              SizedBox(
                width: 14,
                child: node.isDirectory
                    ? AnimatedRotation(
                        turns: expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: active ? scheme.primary : iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: active ? scheme.primary : scheme.onSurface,
                    fontWeight:
                        active || opened ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              PopupMenuButton<_NodeAction>(
                tooltip: '文件操作',
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 168),
                itemBuilder: (context) => _buildMenuItems(context, node),
                onSelected: (action) {
                  switch (action) {
                    case _NodeAction.createFile:
                      widget.onCreateFile(node);
                      break;
                    case _NodeAction.createFolder:
                      widget.onCreateFolder(node);
                      break;
                    case _NodeAction.rename:
                      widget.onRenameNode(node);
                      break;
                    case _NodeAction.delete:
                      widget.onDeleteNode(node);
                      break;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<_NodeAction>> _buildMenuItems(
    BuildContext context,
    FileNode node,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return [
      if (node.isDirectory) ...[
        PopupMenuItem(
          value: _NodeAction.createFile,
          height: 42,
          child: _menuRow(scheme, Icons.note_add_outlined, '新建文件'),
        ),
        PopupMenuItem(
          value: _NodeAction.createFolder,
          height: 42,
          child: _menuRow(scheme, Icons.create_new_folder_outlined, '新建文件夹'),
        ),
        const PopupMenuDivider(),
      ],
      PopupMenuItem(
        value: _NodeAction.rename,
        height: 42,
        child: _menuRow(scheme, Icons.drive_file_rename_outline_rounded, '重命名'),
      ),
      PopupMenuItem(
        value: _NodeAction.delete,
        height: 42,
        child: _menuRow(scheme, Icons.delete_outline_rounded, '删除', error: true),
      ),
    ];
  }

  Widget _menuRow(
    ColorScheme scheme,
    IconData icon,
    String label, {
    bool error = false,
  }) {
    final color = error ? scheme.error : scheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}

class _FlatEntry {
  const _FlatEntry(this.node, this.depth);

  final FileNode node;
  final int depth;
}
