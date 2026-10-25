import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'terminal_session.dart';

/// 终端运行环境类型。
enum RuntimeKind {
  /// 基于 proot 的 Alpine Linux 容器。
  proot,

  /// 直接使用系统自带的 shell。
  host,
}

/// 本地编译环境：负责安装 proot + Alpine 根文件系统，并生成终端启动参数。
///
/// proot 二进制与依赖库随 APK 以 native library 的形式打包（见
/// `android/app/src/main/jniLibs`），根文件系统首次使用时从 assets 解压到
/// 应用私有目录，因此不需要 root 权限。
class LocalRuntime {
  LocalRuntime({
    required this.abi,
    required this.projectPath,
    required this.supportDirectory,
    required this.rootfsDirectory,
    required this.nativeLibraryDirectory,
    required this.prootPath,
    required this.loaderPath,
    required this.loader32Path,
  });

  static const _channel = MethodChannel('slipecode/runtime');
  static const _rootfsMarker = '.slipecode-rootfs';

  /// 设备 ABI，例如 `arm64-v8a`、`x86_64`。
  final String abi;

  /// 项目在宿主上的路径，会被挂载到容器内的 `/workspace`。
  final String projectPath;

  final Directory supportDirectory;
  final Directory rootfsDirectory;
  final String? nativeLibraryDirectory;
  final String? prootPath;
  final String? loaderPath;
  final String? loader32Path;

  /// 当前设备是否具备启动 proot 的条件。
  bool get prootAvailable {
    final proot = prootPath;
    final loader = loaderPath;
    if (proot == null || loader == null) return false;
    if (rootfsArchFor(abi) == null) return false;
    return File(proot).existsSync() && File(loader).existsSync();
  }

  /// 根文件系统是否已解压完成。
  bool get installed =>
      File(p.join(rootfsDirectory.path, _rootfsMarker)).existsSync();

  bool get ready => prootAvailable && installed;

  RuntimeKind get kind => ready ? RuntimeKind.proot : RuntimeKind.host;

  bool get isProot => kind == RuntimeKind.proot;

  /// 终端里展示的初始工作目录。
  String get promptPath => isProot ? '/workspace' : projectPath;

  /// ABI 到 Alpine 根文件系统架构的映射，不支持时返回 null。
  @visibleForTesting
  static String? rootfsArchFor(String abi) => switch (abi) {
        'arm64-v8a' => 'aarch64',
        'x86_64' => 'x86_64',
        _ => null,
      };

  /// 打开当前项目的运行环境（不会自动安装根文件系统）。
  static Future<LocalRuntime> open({required String projectPath}) async {
    final support = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'runtime'),
    );
    await support.create(recursive: true);
    await Directory(p.join(support.path, 'tmp')).create(recursive: true);

    final abi = await _resolveAbi();
    final nativeDirectory =
        Platform.isAndroid ? await _nativeLibraryDirectory() : null;
    final prootPath = nativeDirectory == null
        ? null
        : p.join(nativeDirectory, 'libproot.so');
    final loaderPath = nativeDirectory == null
        ? null
        : p.join(nativeDirectory, 'libproot-loader.so');
    final loader32 = nativeDirectory == null
        ? null
        : p.join(nativeDirectory, 'libproot-loader32.so');

    return LocalRuntime(
      abi: abi,
      projectPath: projectPath,
      supportDirectory: support,
      rootfsDirectory: Directory(p.join(support.path, 'rootfs-$abi')),
      nativeLibraryDirectory: nativeDirectory,
      prootPath: prootPath,
      loaderPath: loaderPath,
      loader32Path: loader32 != null && File(loader32).existsSync()
          ? loader32
          : null,
    );
  }

  static Future<String> _resolveAbi() async {
    if (!Platform.isAndroid) return 'host';
    try {
      final abi = await _channel.invokeMethod<String>('abi');
      if (abi != null && abi.isNotEmpty) return abi;
    } on Object {
      // 通道不可用时按最常见的 64 位 ARM 设备处理
    }
    return 'arm64-v8a';
  }

  static Future<String?> _nativeLibraryDirectory() async {
    try {
      return await _channel.invokeMethod<String>('nativeLibraryDir');
    } on Object {
      return null;
    }
  }

  /// 解压 Alpine 根文件系统。耗时操作，调用方需要展示进度。
  Future<void> install({void Function(double value)? onProgress}) async {
    final arch = rootfsArchFor(abi);
    if (!prootAvailable || arch == null) {
      throw StateError('当前设备不支持 proot 容器（ABI: $abi）');
    }

    final data = await rootBundle.load('assets/rootfs/alpine-$arch.tar.gz');
    final tarBytes = GZipDecoder().decodeBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final archive = TarDecoder().decodeBytes(tarBytes);

    if (await rootfsDirectory.exists()) {
      await rootfsDirectory.delete(recursive: true);
    }
    await rootfsDirectory.create(recursive: true);

    final rootPath = rootfsDirectory.path;
    final links = <ArchiveFile>[];
    final entries = archive.files;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final target = p.normalize(p.join(rootPath, entry.name));
      if (!p.isWithin(rootPath, target)) continue;

      if (entry.isSymbolicLink) {
        // 链接统一放到最后创建，避免后续文件被写入到链接指向的位置。
        links.add(entry);
      } else if (entry.isDirectory) {
        await Directory(target).create(recursive: true);
      } else {
        final file = File(target);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.content, flush: false);
      }

      if (index % 8 == 0) {
        onProgress?.call((index + 1) / entries.length);
      }
    }

    for (final entry in links) {
      final target = p.normalize(p.join(rootPath, entry.name));
      final link = Link(target);
      if (await link.exists()) await link.delete();
      await link.parent.create(recursive: true);
      await link.create(entry.symbolicLink!);
    }

    // Dart 没有 chmod API，交给系统自带的 chmod 补上可执行权限。
    try {
      await Process.run(
        Platform.isAndroid ? '/system/bin/chmod' : 'chmod',
        ['-R', '755', rootPath],
      );
    } on Object {
      // 部分设备可能无法执行 chmod，此时容器里的程序会因权限不足而失败。
    }

    await File(p.join(rootPath, 'etc', 'resolv.conf')).writeAsString(
      'nameserver 223.5.5.5\nnameserver 1.1.1.1\n',
      flush: true,
    );
    await File(p.join(rootPath, _rootfsMarker)).writeAsString(arch, flush: true);
    onProgress?.call(1);
  }

  /// 生成终端进程的启动配置。
  TerminalLaunchConfig get launchConfig {
    if (isProot) {
      final env = <String, String>{
        'HOME': '/root',
        'TERM': 'xterm-256color',
        'LANG': 'C.UTF-8',
        'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
        'LD_LIBRARY_PATH': nativeLibraryDirectory!,
        'PROOT_LOADER': loaderPath!,
        'PROOT_TMP_DIR': p.join(supportDirectory.path, 'tmp'),
        // 部分 Android 设备的 seccomp 策略会阻止 ptrace，关掉可提升兼容性。
        'PROOT_NO_SECCOMP': '1',
      };
      if (loader32Path != null) env['PROOT_LOADER_32'] = loader32Path!;

      return TerminalLaunchConfig(
        kind: RuntimeKind.proot,
        executable: prootPath!,
        arguments: [
          '-0',
          '--link2symlink',
          '--kill-on-exit',
          '-r',
          rootfsDirectory.path,
          '-b',
          '/dev',
          '-b',
          '/proc',
          '-b',
          '/sys',
          '-b',
          '$projectPath:/workspace',
          '-w',
          '/workspace',
          '/bin/sh',
        ],
        workingDirectory: projectPath,
        environment: env,
        prompt: '/workspace',
      );
    }

    final android = Platform.isAndroid;
    return TerminalLaunchConfig(
      kind: RuntimeKind.host,
      executable: android ? '/system/bin/sh' : '/bin/sh',
      arguments: const [],
      workingDirectory: projectPath,
      environment: {
        'HOME': projectPath,
        'TERM': 'xterm-256color',
        'LANG': 'C.UTF-8',
        'PATH': android
            ? '/system/bin:/system/xbin:/vendor/bin'
            : '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin',
      },
      prompt: projectPath,
    );
  }
}
