import 'package:flutter/material.dart';

import '../data/project_templates.dart';
import '../services/project_repository.dart';

/// 新建项目底部弹窗。
class CreateProjectSheet extends StatefulWidget {
  const CreateProjectSheet({super.key, required this.repository});

  final ProjectRepository repository;

  @override
  State<CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<CreateProjectSheet> {
  final TextEditingController _nameController =
      TextEditingController(text: '我的应用');
  int _selectedIndex = 0;
  String? _nameError;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '请输入项目名称');
      return;
    }
    if (name.length > 40) {
      setState(() => _nameError = '名称不能超过 40 个字符');
      return;
    }

    setState(() {
      _creating = true;
      _nameError = null;
    });

    try {
      if (await widget.repository.hasProjectNamed(name)) {
        if (!mounted) return;
        setState(() {
          _creating = false;
          _nameError = '已有同名项目';
        });
        return;
      }
      final project = await widget.repository.createProject(
        name: name,
        template: projectTemplates[_selectedIndex],
      );
      if (!mounted) return;
      Navigator.of(context).pop(project);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _nameError = '创建失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '新建项目',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _creating
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: '关闭',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  enabled: !_creating,
                  decoration: InputDecoration(
                    labelText: '项目名称',
                    hintText: '例如：我的第一个应用',
                    errorText: _nameError,
                    prefixIcon: const Icon(Icons.edit_rounded, size: 18),
                  ),
                  onSubmitted: (_) {
                    if (!_creating) _create();
                  },
                ),
                const SizedBox(height: 22),
                Text(
                  '选择模板',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                for (var index = 0; index < projectTemplates.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == projectTemplates.length - 1 ? 0 : 10,
                    ),
                    child: _TemplateCard(
                      template: projectTemplates[index],
                      selected: index == _selectedIndex,
                      onTap: _creating
                          ? null
                          : () => setState(() => _selectedIndex = index),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _creating ? null : _create,
                    icon: _creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded, size: 20),
                    label: Text(_creating ? '正在创建…' : '创建项目'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final ProjectTemplate template;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? template.accent.withValues(alpha: 0.12)
              : scheme.surfaceContainerHigh.withValues(alpha: 0.35),
          border: Border.all(
            color: selected
                ? template.accent.withValues(alpha: 0.7)
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    template.accent,
                    template.accent.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Icon(template.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    template.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? template.accent : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
