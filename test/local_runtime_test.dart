import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:slipecode/services/local_runtime.dart';

void main() {
  test('ABI 映射到 Alpine 根文件系统架构', () {
    expect(LocalRuntime.rootfsArchFor('arm64-v8a'), 'aarch64');
    expect(LocalRuntime.rootfsArchFor('x86_64'), 'x86_64');
    expect(LocalRuntime.rootfsArchFor('armeabi-v7a'), isNull);
    expect(LocalRuntime.rootfsArchFor('host'), isNull);
  });

  test('proot 启动参数挂载项目目录并以 /workspace 作为工作目录', () async {
    final temp = await Directory.systemTemp.createTemp('slipecode_runtime_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final nativeDirectory = Directory(p.join(temp.path, 'lib'));
    await nativeDirectory.create(recursive: true);
    final proot = File(p.join(nativeDirectory.path, 'libproot.so'));
    final loader = File(p.join(nativeDirectory.path, 'libproot-loader.so'));
    await proot.writeAsBytes(const [0]);
    await loader.writeAsBytes(const [0]);

    final rootfs = Directory(p.join(temp.path, 'rootfs-arm64-v8a'));
    await rootfs.create(recursive: true);
    await File(p.join(rootfs.path, '.slipecode-rootfs')).writeAsString('aarch64');

    final runtime = LocalRuntime(
      abi: 'arm64-v8a',
      projectPath: p.join(temp.path, 'project'),
      supportDirectory: Directory(p.join(temp.path, 'runtime')),
      rootfsDirectory: rootfs,
      nativeLibraryDirectory: nativeDirectory.path,
      prootPath: proot.path,
      loaderPath: loader.path,
      loader32Path: null,
    );

    expect(runtime.ready, isTrue);
    expect(runtime.isProot, isTrue);
    expect(runtime.promptPath, '/workspace');

    final config = runtime.launchConfig;
    expect(config.executable, proot.path);
    expect(config.workingDirectory, p.join(temp.path, 'project'));
    expect(config.arguments, containsAllInOrder(['-r', rootfs.path]));
    expect(
      config.arguments,
      contains('${p.join(temp.path, 'project')}:/workspace'),
    );
    expect(config.arguments, containsAllInOrder(['-w', '/workspace']));
    expect(config.arguments.last, '/bin/sh');
    expect(config.environment['PROOT_LOADER'], loader.path);
    expect(config.environment['HOME'], '/root');
  });

  test('没有 proot 时退回系统 Shell', () async {
    final temp = await Directory.systemTemp.createTemp('slipecode_host_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final runtime = LocalRuntime(
      abi: 'host',
      projectPath: p.join(temp.path, 'project'),
      supportDirectory: temp,
      rootfsDirectory: Directory(p.join(temp.path, 'rootfs')),
      nativeLibraryDirectory: null,
      prootPath: null,
      loaderPath: null,
      loader32Path: null,
    );

    expect(runtime.prootAvailable, isFalse);
    expect(runtime.kind, RuntimeKind.host);

    final config = runtime.launchConfig;
    expect(config.executable, '/bin/sh');
    expect(config.workingDirectory, p.join(temp.path, 'project'));
  });
}
