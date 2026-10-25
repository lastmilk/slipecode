import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:slipecode/app.dart';
import 'package:slipecode/editor/code_editor.dart';
import 'package:slipecode/services/project_repository.dart';

void main() {
  /// 真实文件 IO 需要借 runAsync 驱动事件循环，这里按轮次等待目标出现。
  Future<bool> waitFor(
    WidgetTester tester,
    Finder finder, {
    int rounds = 400,
  }) async {
    for (var i = 0; i < rounds; i++) {
      if (finder.evaluate().isNotEmpty) return true;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    return finder.evaluate().isNotEmpty;
  }

  testWidgets('创建项目、打开文件、编辑并保存', (tester) async {
    final sandbox = await tester.runAsync(
      () => Directory.systemTemp.createTemp('slipecode_app_'),
    );
    expect(sandbox, isNotNull);
    final directory = sandbox!;
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final repository = ProjectRepository(
      Directory(p.join(directory.path, 'projects')),
    );

    await tester.pumpWidget(SlipecodeApp(repository: repository));
    expect(await waitFor(tester, find.text('还没有项目')), isTrue);
    expect(find.text('Slipecode'), findsOneWidget);

    await tester.tap(find.text('创建第一个项目'));
    await tester.pumpAndSettle();
    expect(find.text('新建项目'), findsWidgets);

    await tester.enterText(find.byType(TextField), '我的应用');
    await tester.tap(find.text('创建项目'));

    expect(await waitFor(tester, find.textContaining('个文件已打开')), isTrue);
    expect(find.text('我的应用'), findsWidgets);

    expect(await waitFor(tester, find.byTooltip('文件')), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('文件'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(await waitFor(tester, find.text('main.dart')), isTrue);
    await tester.tap(find.text('main.dart').first);

    expect(await waitFor(tester, find.byType(CodeEditor)), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    final codeField = find.byType(TextField);
    expect(codeField, findsOneWidget);

    await tester.enterText(codeField, 'void main() {}\n');
    await tester.pump();
    expect(find.text('未保存'), findsOneWidget);

    await tester.tap(find.byTooltip('保存全部'));
    expect(await waitFor(tester, find.text('已保存')), isTrue);

    final projects = await tester.runAsync(() => repository.listProjects());
    expect(projects, isNotNull);
    final mainFile = File(p.join(projects!.single.path, 'lib', 'main.dart'));
    final content = await tester.runAsync(() => mainFile.readAsString());
    expect(content, 'void main() {}\n');
  });
}
