import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/project_repository.dart';
import '../theme/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/format.dart';
import 'create_project_sheet.dart';
import 'editor_screen.dart';

enum _ProjectAction { rename, delete }

/// 项目列表首页。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final ProjectRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Project> _projects = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(showLoading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final projects = await widget.repository.listProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _createProject() async {
    final project = await showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateProjectSheet(repository: widget.repository),
    );
    if (project == null || !mounted) return;
    await _load();
    if (!mounted) return;
    await _openProject(project);
  }

  Future<void> _openProject(Project project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => EditorScreen(project: project),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _renameProject(Project project) async {
    final name = await showNameDialog(
      context,
      title: '重命名项目',
      hint: '项目名称',
      initialValue: project.name,
      validator: (value) {
        if (value.isEmpty) return '名称不能为空';
        if (value.length > 40) return '名称不能超过 40 个字符';
        return null;
      },
    );
    if (name == null || name == project.name || !mounted) return;

    if (await widget.repository.hasProjectNamed(name, exceptId: project.id)) {
      if (!mounted) return;
      _showMessage('已有同名项目');
      return;
    }

    try {
      await widget.repository.renameProject(project, name);
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showMessage('重命名失败：$error');
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除项目',
      message: '确定删除「${project.name}」？项目内的所有文件都会被删除，且无法恢复。',
    );
    if (!confirmed) return;

    try {
      await widget.repository.deleteProject(project);
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showMessage('删除失败：$error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accent, AppColors.accentAlt],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.terminal_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Slipecode',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '移动端 Flutter 编辑器',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Text(
                '项目',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              if (_projects.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_projects.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _createProject,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('新建项目'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _CenteredMessage(
        icon: Icons.error_outline_rounded,
        title: '加载项目失败',
        message: _error!,
        actionLabel: '重试',
        onAction: () => _load(showLoading: true),
      );
    }

    if (_projects.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
          children: [
            _CenteredMessage(
              icon: Icons.folder_copy_outlined,
              title: '还没有项目',
              message: '从模板创建一个 Flutter 项目，\n然后在手机上编辑代码。',
              actionLabel: '创建第一个项目',
              onAction: _createProject,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: _projects.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final project = _projects[index];
          return _ProjectCard(
            project: project,
            onTap: () => _openProject(project),
            onRename: () => _renameProject(project),
            onDelete: () => _deleteProject(project),
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final Project project;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.accent.withValues(alpha: 0.9),
                        AppColors.accentAlt.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.insert_drive_file_outlined,
                            size: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${project.fileCount} 个文件',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              relativeTime(project.updatedAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_ProjectAction>(
                  tooltip: '项目操作',
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _ProjectAction.rename,
                      height: 42,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.drive_file_rename_outline_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          const Text('重命名', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _ProjectAction.delete,
                      height: 42,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: scheme.error,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '删除',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (action) {
                    switch (action) {
                      case _ProjectAction.rename:
                        onRename();
                        break;
                      case _ProjectAction.delete:
                        onDelete();
                        break;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 34, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
