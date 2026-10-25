import 'dart:io';

/// 一个本地 Flutter 项目。
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.directory,
    required this.createdAt,
    required this.updatedAt,
    required this.fileCount,
  });

  /// 项目目录名，同时也是稳定标识。
  final String id;
  final String name;
  final Directory directory;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int fileCount;

  String get path => directory.path;

  Project copyWith({String? name, DateTime? updatedAt, int? fileCount}) {
    return Project(
      id: id,
      name: name ?? this.name,
      directory: directory,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fileCount: fileCount ?? this.fileCount,
    );
  }
}
