import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/project_templates.dart';
import '../models/project.dart';

/// 项目仓库：项目都保存在应用文档目录下的 `Slipecode/projects` 中。
class ProjectRepository {
  ProjectRepository(this.rootDirectory);

  static const metadataFileName = '.slipecode.json';

  final Directory rootDirectory;

  static Future<ProjectRepository> open() async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(documents.path, 'Slipecode', 'projects'));
    await root.create(recursive: true);
    return ProjectRepository(root);
  }

  Future<List<Project>> listProjects() async {
    if (!await rootDirectory.exists()) return [];

    final projects = <Project>[];
    await for (final entity in rootDirectory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final metadata = File(p.join(entity.path, metadataFileName));
      if (!await metadata.exists()) continue;

      try {
        final raw = jsonDecode(await metadata.readAsString());
        if (raw is! Map<String, dynamic>) continue;
        final rawName = raw['name'];
        final rawCreatedAt = raw['createdAt'];
        final stats = await _scanStatistics(entity);
        projects.add(Project(
          id: p.basename(entity.path),
          name: rawName is String && rawName.trim().isNotEmpty
              ? rawName.trim()
              : p.basename(entity.path),
          directory: entity,
          createdAt: rawCreatedAt is String
              ? DateTime.tryParse(rawCreatedAt) ?? stats.latestModified
              : stats.latestModified,
          updatedAt: stats.latestModified,
          fileCount: stats.fileCount,
        ));
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }

    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<bool> hasProjectNamed(String name, {String? exceptId}) async {
    final target = name.trim().toLowerCase();
    for (final project in await listProjects()) {
      if (project.id == exceptId) continue;
      if (project.name.toLowerCase() == target) return true;
    }
    return false;
  }

  Future<Project> createProject({
    required String name,
    required ProjectTemplate template,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('项目名称不能为空');
    }

    final id = _newProjectId();
    final directory = Directory(p.join(rootDirectory.path, id));
    await directory.create(recursive: true);

    final packageName = _packageName(trimmed);
    final files = template.buildFiles(packageName);
    for (final entry in files.entries) {
      final file = File(p.join(directory.path, entry.key));
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value, flush: true);
    }

    final createdAt = DateTime.now();
    await File(p.join(directory.path, metadataFileName)).writeAsString(
      jsonEncode({
        'name': trimmed,
        'template': template.id,
        'createdAt': createdAt.toIso8601String(),
      }),
      flush: true,
    );

    return Project(
      id: id,
      name: trimmed,
      directory: directory,
      createdAt: createdAt,
      updatedAt: createdAt,
      fileCount: files.length,
    );
  }

  Future<void> renameProject(Project project, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('项目名称不能为空');

    final metadata = File(p.join(project.path, metadataFileName));
    final raw = jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
    raw['name'] = trimmed;
    await metadata.writeAsString(jsonEncode(raw), flush: true);
  }

  Future<void> deleteProject(Project project) async {
    if (await project.directory.exists()) {
      await project.directory.delete(recursive: true);
    }
  }

  Future<_ProjectStatistics> _scanStatistics(Directory directory) async {
    var fileCount = 0;
    var latest = DateTime.fromMillisecondsSinceEpoch(0);

    Future<void> visit(Directory dir, int depth) async {
      if (depth > 8) return;
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (fileCount >= 2000) return;
          if (entity is Directory) {
            await visit(entity, depth + 1);
          } else if (entity is File) {
            if (p.basename(entity.path) == metadataFileName) continue;
            fileCount++;
            try {
              final stat = await entity.stat();
              if (stat.modified.isAfter(latest)) latest = stat.modified;
            } on FileSystemException {
              // 忽略单个文件的读取失败
            }
          }
        }
      } on FileSystemException {
        // 忽略无法访问的目录
      }
    }

    await visit(directory, 0);
    if (fileCount == 0) {
      latest = await directory.stat().then((stat) => stat.modified);
    }
    return _ProjectStatistics(fileCount, latest);
  }

  String _newProjectId() {
    final now = DateTime.now();
    final random = Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return '${now.millisecondsSinceEpoch}_$random';
  }

  String _packageName(String name) {
    var slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (slug.isEmpty) return 'flutter_app';
    if (!RegExp(r'^[a-z]').hasMatch(slug)) slug = 'app_$slug';
    if (slug.length > 40) slug = slug.substring(0, 40);
    return slug;
  }
}

class _ProjectStatistics {
  const _ProjectStatistics(this.fileCount, this.latestModified);

  final int fileCount;
  final DateTime latestModified;
}
