import 'package:flutter/material.dart';

/// 通用命名输入弹窗，返回 null 表示取消。
Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String initialValue = '',
  String confirmLabel = '确定',
  String? description,
  String? Function(String value)? validator,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      String? error;
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final value = controller.text.trim();
            final message =
                validator?.call(value) ?? (value.isEmpty ? '名称不能为空' : null);
            if (message != null) {
              setState(() => error = message);
              return;
            }
            Navigator.of(dialogContext).pop(value);
          }

          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description != null) ...[
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: hint,
                    errorText: error,
                  ),
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: submit,
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  return result;
}

/// 通用确认弹窗。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '删除',
  String cancelLabel = '取消',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
