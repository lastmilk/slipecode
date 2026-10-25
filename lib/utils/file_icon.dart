import 'package:flutter/material.dart';

import '../models/file_node.dart';

/// 根据文件类型返回图标与颜色。
(IconData, Color) fileIconFor(FileNode node, ColorScheme scheme) {
  if (node.isDirectory) return (Icons.folder_rounded, scheme.primary);
  switch (node.extension) {
    case 'dart':
      return (Icons.code_rounded, const Color(0xFF6C8CFF));
    case 'yaml':
    case 'yml':
      return (Icons.tune_rounded, const Color(0xFFF0B429));
    case 'json':
      return (Icons.data_object_rounded, const Color(0xFF46C2A4));
    case 'md':
    case 'markdown':
      return (Icons.article_rounded, const Color(0xFFB07CFF));
    default:
      return (Icons.description_rounded, scheme.onSurfaceVariant);
  }
}
