import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/file_node.dart';

/// 负责项目内部文件的读取与文件树构建。
class FileService {
  static const _ignoredDirectories = <String>{
    '.git',
    '.dart_tool',
    '.gradle',
    '.idea',
    'build',
    'Pods',
    'node_modules',
  };

  static const _maxDepth = 10;

  Future<FileNode> loadTree(Directory root) async {
    final children = await _loadChildren(root, 0);
    return FileNode(
      name: p.basename(root.path),
      path: root.path,
      isDirectory: true,
      children: children,
    );
  }

  Future<List<FileNode>> _loadChildren(Directory directory, int depth) async {
    if (depth > _maxDepth) return const [];
    final entries = <FileSystemEntity>[];
    try {
      await for (final entity in directory.list(followLinks: false)) {
        entries.add(entity);
      }
    } on FileSystemException {
      return const [];
    }

    final nodes = <FileNode>[];
    for (final entity in entries) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        if (_ignoredDirectories.contains(name)) continue;
        final children = await _loadChildren(entity, depth + 1);
        nodes.add(FileNode(
          name: name,
          path: entity.path,
          isDirectory: true,
          children: children,
        ));
      } else if (entity is File) {
        nodes.add(FileNode(name: name, path: entity.path, isDirectory: false));
      }
    }

    nodes.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return nodes;
  }

  Future<String> readText(File file) => file.readAsString();

  Future<void> writeText(File file, String content) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
  }

  Future<File> createFile(Directory parent, String name) async {
    final file = File(p.join(parent.path, name));
    if (await FileSystemEntity.type(file.path) != FileSystemEntityType.notFound) {
      throw FileSystemException('文件已存在', file.path);
    }
    await file.parent.create(recursive: true);
    return file..createSync();
  }

  Future<Directory> createDirectory(Directory parent, String name) async {
    final dir = Directory(p.join(parent.path, name));
    if (await FileSystemEntity.type(dir.path) != FileSystemEntityType.notFound) {
      throw FileSystemException('文件夹已存在', dir.path);
    }
    return dir.create(recursive: true);
  }

  Future<void> rename(FileSystemEntity entity, String newName) async {
    final target = p.join(p.dirname(entity.path), newName);
    if (await FileSystemEntity.type(target) != FileSystemEntityType.notFound) {
      throw FileSystemException('同名文件已存在', target);
    }
    await entity.rename(target);
  }

  Future<void> delete(FileSystemEntity entity, {required bool recursive}) async {
    if (entity is Directory) {
      await entity.delete(recursive: recursive);
    } else {
      await entity.delete();
    }
  }

  /// 校验用户输入的文件 / 文件夹名。
  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return '名称不能为空';
    if (name == '.' || name == '..') return '名称无效';
    if (name.contains('/') || name.contains(r'\')) return '名称不能包含斜杠';
    if (name.length > 64) return '名称不能超过 64 个字符';
    return null;
  }
}
