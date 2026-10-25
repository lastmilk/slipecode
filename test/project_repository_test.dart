import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:slipecode/data/project_templates.dart';
import 'package:slipecode/services/file_service.dart';
import 'package:slipecode/services/project_repository.dart';

void main() {
  late Directory sandbox;
  late ProjectRepository repository;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('slipecode_repo_');
    repository = ProjectRepository(Directory(p.join(sandbox.path, 'projects')));
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('创建项目会生成模板文件与元数据', () async {
    final project = await repository.createProject(
      name: '我的应用',
      template: projectTemplates.first,
    );

    expect(p.basename(project.path), project.id);
    expect(File(p.join(project.path, 'pubspec.yaml')).existsSync(), isTrue);
    expect(File(p.join(project.path, 'lib', 'main.dart')).existsSync(), isTrue);
    expect(
      File(p.join(project.path, ProjectRepository.metadataFileName)).existsSync(),
      isTrue,
    );

    final pubspec = await File(p.join(project.path, 'pubspec.yaml')).readAsString();
    expect(pubspec, contains('name: flutter_app'));
    expect(pubspec, contains('uses-material-design: true'));
  });

  test('列出 / 重命名 / 删除项目', () async {
    final project = await repository.createProject(
      name: 'Demo',
      template: projectTemplates.last,
    );

    final listed = await repository.listProjects();
    expect(listed, hasLength(1));
    expect(listed.single.name, 'Demo');
    expect(listed.single.fileCount, greaterThan(3));

    await repository.renameProject(project, 'Renamed');
    final renamed = await repository.listProjects();
    expect(renamed.single.name, 'Renamed');
    expect(renamed.single.id, project.id);

    await repository.deleteProject(project);
    expect(await repository.listProjects(), isEmpty);
    expect(project.directory.existsSync(), isFalse);
  });

  test('项目名称重复检测', () async {
    await repository.createProject(name: 'Demo', template: projectTemplates.first);
    expect(await repository.hasProjectNamed('demo'), isTrue);
    expect(await repository.hasProjectNamed('Demo '), isTrue);
    expect(await repository.hasProjectNamed('Other'), isFalse);
  });

  test('文件树按目录优先、名称排序', () async {
    final project = await repository.createProject(
      name: 'Tree',
      template: projectTemplates.first,
    );

    final tree = await FileService().loadTree(project.directory);
    expect(tree.children, isNotEmpty);
    expect(tree.children.first.isDirectory, isTrue);
    expect(tree.children.first.name, 'lib');

    final names = tree.children.map((node) => node.name).toList();
    final firstFileIndex = tree.children.indexWhere((node) => !node.isDirectory);
    expect(firstFileIndex, greaterThan(0));
    expect(names, contains('pubspec.yaml'));
  });

  test('文件与文件夹的创建、重命名、删除', () async {
    final project = await repository.createProject(
      name: 'Ops',
      template: projectTemplates.last,
    );
    final service = FileService();

    final folder = await service.createDirectory(project.directory, 'features');
    final file = await service.createFile(folder, 'home.dart');
    await service.writeText(file, 'void main() {}');
    expect(await service.readText(file), 'void main() {}');

    await service.rename(file, 'welcome.dart');
    final renamed = File(p.join(folder.path, 'welcome.dart'));
    expect(renamed.existsSync(), isTrue);
    expect(file.existsSync(), isFalse);

    await service.delete(renamed, recursive: false);
    expect(renamed.existsSync(), isFalse);

    await service.delete(folder, recursive: true);
    expect(folder.existsSync(), isFalse);
  });

  test('文件名校验', () {
    expect(FileService.validateName('main.dart'), isNull);
    expect(FileService.validateName(''), isNotNull);
    expect(FileService.validateName('..'), isNotNull);
    expect(FileService.validateName('a/b.dart'), isNotNull);
  });
}
