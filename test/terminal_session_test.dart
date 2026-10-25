import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:slipecode/services/local_runtime.dart';
import 'package:slipecode/services/terminal_session.dart';

void main() {
  late Directory temp;
  late TerminalSession session;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('slipecode_terminal_');
    session = await TerminalSession.start(
      TerminalLaunchConfig(
        kind: RuntimeKind.host,
        executable: '/bin/sh',
        arguments: const [],
        workingDirectory: temp.path,
        environment: {
          'PATH': '/usr/local/bin:/usr/bin:/bin',
          'HOME': temp.path,
          'LANG': 'C.UTF-8',
          'TERM': 'xterm-256color',
        },
        prompt: temp.path,
      ),
    );
  });

  tearDown(() async {
    await session.close();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('执行命令并收集输出', () async {
    final result = await session.run('echo hello');
    expect(result.exitCode, 0);
    expect(result.output, contains('hello'));
  });

  test('cd 的工作目录会保留到下一条命令', () async {
    await Directory(p.join(temp.path, 'sub')).create();
    final change = await session.run('cd sub');
    expect(change.exitCode, 0);

    final result = await session.run('pwd');
    expect(result.output.trim(), endsWith('/sub'));
    expect(session.prompt, endsWith('/sub'));
  });

  test('失败命令返回非零退出码和错误输出', () async {
    final result = await session.run('ls /definitely-not-exists');
    expect(result.exitCode, isNot(0));
    expect(result.output.toLowerCase(), contains('no such file'));
  });

  test('多行输出与连续执行', () async {
    final first = await session.run('for i in 1 2 3; do echo "n\$i"; done');
    expect(first.output.split('\n'), containsAll(['n1', 'n2', 'n3']));

    final second = await session.run('echo done');
    expect(second.output.trim(), 'done');
  });

  test('输出流包含命令回显与结果', () async {
    final lines = <TerminalLine>[];
    final subscription = session.lines.listen(lines.add);
    await session.run('echo stream');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await subscription.cancel();

    expect(
      lines.any((line) => line.kind == TerminalLineKind.command),
      isTrue,
    );
    expect(lines.any((line) => line.text.contains('stream')), isTrue);
  });
}
