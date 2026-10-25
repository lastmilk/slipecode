import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'local_runtime.dart' show RuntimeKind;

/// 终端输出的一行。
enum TerminalLineKind { command, output, error, system }

class TerminalLine {
  const TerminalLine(this.text, this.kind);

  final String text;
  final TerminalLineKind kind;
}

/// 一条命令的执行结果。
class TerminalResult {
  const TerminalResult({required this.exitCode, required this.output});

  final int exitCode;
  final String output;

  bool get succeeded => exitCode == 0;
}

/// 终端进程的启动参数。
class TerminalLaunchConfig {
  const TerminalLaunchConfig({
    required this.kind,
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
    required this.prompt,
  });

  final RuntimeKind kind;
  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final Map<String, String> environment;

  /// 初始工作目录（容器内路径或宿主路径）。
  final String prompt;
}

class _PendingCommand {
  _PendingCommand(this.marker, this.completer);

  final String marker;
  final Completer<TerminalResult> completer;
  final StringBuffer output = StringBuffer();
}

/// 持久的交互式 shell 会话。
///
/// 每次执行命令时追加一个唯一标记，读到标记即认为命令执行完毕，
/// 因此 `cd`、`export` 等状态可以跨命令保留。
class TerminalSession {
  TerminalSession._(this._process, this._config) : _prompt = _config.prompt;

  final Process _process;
  final TerminalLaunchConfig _config;

  final StreamController<TerminalLine> _lines =
      StreamController<TerminalLine>.broadcast();
  final StreamController<void> _exits = StreamController<void>.broadcast();

  late final StreamSubscription<String> _stdoutSubscription;
  late final StreamSubscription<String> _stderrSubscription;

  _PendingCommand? _pending;
  String _prompt;
  bool _closed = false;
  int _sequence = 0;

  Stream<TerminalLine> get lines => _lines.stream;

  /// 进程自行退出时触发（调用 [close] 主动关闭时不会触发）。
  Stream<void> get exits => _exits.stream;

  /// 当前工作目录（随 `cd` 更新）。
  String get prompt => _prompt;

  RuntimeKind get kind => _config.kind;

  bool get closed => _closed;

  static Future<TerminalSession> start(TerminalLaunchConfig config) async {
    final process = await Process.start(
      config.executable,
      config.arguments,
      workingDirectory: config.workingDirectory,
      environment: config.environment,
      includeParentEnvironment: false,
    );
    final session = TerminalSession._(process, config);
    session._subscribe();
    return session;
  }

  void _subscribe() {
    _stdoutSubscription = _process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) => _handleLine(line, isError: false));

    _stderrSubscription = _process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) => _handleLine(line, isError: true));

    _process.exitCode.then((code) {
      if (_closed) return;
      _closed = true;
      final pending = _pending;
      _pending = null;
      if (pending != null && !pending.completer.isCompleted) {
        pending.completer.complete(
          TerminalResult(exitCode: -1, output: pending.output.toString()),
        );
      }
      _emit('进程已退出（退出码 $code）', TerminalLineKind.system);
      if (!_exits.isClosed) _exits.add(null);
    });
  }

  void _handleLine(String line, {required bool isError}) {
    final pending = _pending;
    if (pending != null) {
      final match = RegExp(
        '^${RegExp.escape(pending.marker)}(\\d+):(.*)\$',
      ).firstMatch(line);
      if (match != null) {
        _pending = null;
        final pwd = match.group(2) ?? '';
        if (pwd.isNotEmpty) _prompt = pwd;
        if (!pending.completer.isCompleted) {
          pending.completer.complete(
            TerminalResult(
              exitCode: int.tryParse(match.group(1) ?? '') ?? -1,
              output: pending.output.toString(),
            ),
          );
        }
        return;
      }
      pending.output.writeln(line);
    }

    _emit(
      line,
      isError ? TerminalLineKind.error : TerminalLineKind.output,
    );
  }

  void _emit(String text, TerminalLineKind kind) {
    if (_lines.isClosed) return;
    _lines.add(TerminalLine(text, kind));
  }

  /// 执行一条命令并等待其结束。
  Future<TerminalResult> run(String command) async {
    if (_closed) throw StateError('终端会话已关闭');
    if (_pending != null) throw StateError('上一条命令仍在执行');

    final source = command.trimRight();
    if (source.isEmpty) {
      return const TerminalResult(exitCode: 0, output: '');
    }

    _emit('$prompt \$ $source', TerminalLineKind.command);

    final marker = '__SLIPECODE_DONE_${++_sequence}__';
    final pending = _PendingCommand(marker, Completer<TerminalResult>());
    _pending = pending;

    final stdin = _process.stdin;
    // 用花括号包裹，保证命令的 stdout 与 stderr 合并成一路输出。
    stdin.writeln('{ $source');
    stdin.writeln('} 2>&1');
    stdin.writeln("printf '\\n$marker%s\\n' \"\$?:\$PWD\"");
    await stdin.flush();

    return pending.completer.future;
  }

  /// 终止当前会话。
  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.completer.isCompleted) {
      pending.completer.complete(
        TerminalResult(exitCode: -1, output: pending.output.toString()),
      );
    }

    try {
      await _process.stdin.close();
    } on Object {
      // 进程可能已经退出
    }
    _process.kill();

    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();
    await _lines.close();
    if (!_exits.isClosed) await _exits.close();
  }
}
