import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../models/project.dart';
import '../services/local_runtime.dart';
import '../services/terminal_session.dart';

const _background = Color(0xFF0B0E14);
const _panel = Color(0xFF121724);
const _panelAlt = Color(0xFF171D2B);
const _border = Color(0xFF232B3D);
const _text = Color(0xFFC9D4E8);
const _muted = Color(0xFF6E7A93);
const _accent = Color(0xFF8B7DFF);
const _success = Color(0xFF46C2A4);
const _danger = Color(0xFFFF6B81);

/// 项目终端：基于 proot 容器执行命令，支持本地编译环境。
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key, required this.project});

  final Project project;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final List<TerminalLine> _lines = [];
  final List<String> _history = [];

  LocalRuntime? _runtime;
  TerminalSession? _session;
  StreamSubscription<TerminalLine>? _outputSubscription;
  StreamSubscription<void>? _exitSubscription;

  int _historyIndex = 0;
  bool _preparing = true;
  bool _installing = false;
  bool _busy = false;
  bool _flushScheduled = false;
  double _progress = 0;
  String? _initializationError;

  bool get _needsInstall =>
      _runtime != null && _runtime!.prootAvailable && !_runtime!.installed;

  bool get _canRun => _session != null && !_busy && !_installing;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    _exitSubscription?.cancel();
    _session?.close();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final runtime = await LocalRuntime.open(projectPath: widget.project.path);
      if (!mounted) return;
      setState(() {
        _runtime = runtime;
        _preparing = false;
      });

      if (runtime.ready) {
        await _startSession();
      } else if (!runtime.prootAvailable) {
        await _startSession();
        _system('未检测到 proot 运行环境，已切换为系统 Shell（功能受限）。');
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _initializationError = '$error';
      });
    }
  }

  Future<void> _startSession() async {
    final runtime = _runtime;
    if (runtime == null) return;
    if (!runtime.isProot && runtime.prootAvailable) return;

    try {
      final session = await TerminalSession.start(runtime.launchConfig);
      if (!mounted) {
        await session.close();
        return;
      }
      _outputSubscription = session.lines.listen(_appendLine);
      _exitSubscription = session.exits.listen((_) {
        if (!mounted) return;
        setState(() {
          _session = null;
          _busy = false;
        });
        _system('终端已退出，点击右上角可重新启动。');
      });
      setState(() => _session = session);

      if (runtime.isProot) {
        _system('Slipecode 终端 · Alpine Linux 3.20（proot）');
        _system('项目已挂载到 /workspace，可执行 apk add 安装工具。');
      } else {
        _system('Slipecode 终端 · 系统 Shell（未启用 proot 容器）');
        _system('工作目录：${widget.project.path}');
      }
    } on Object catch (error) {
      if (!mounted) return;
      _system('启动终端失败：$error');
    }
  }

  Future<void> _restartSession() async {
    final old = _session;
    await _outputSubscription?.cancel();
    await _exitSubscription?.cancel();
    _outputSubscription = null;
    _exitSubscription = null;
    if (old != null && !old.closed) await old.close();
    if (!mounted) return;
    setState(() {
      _session = null;
      _busy = false;
      _lines.clear();
    });
    await _startSession();
  }

  Future<void> _installEnvironment() async {
    final runtime = _runtime;
    if (runtime == null || _installing) return;

    setState(() {
      _installing = true;
      _progress = 0;
    });

    var lastReported = 0.0;
    try {
      await runtime.install(onProgress: (value) {
        if (!mounted || value - lastReported < 0.02) return;
        lastReported = value;
        setState(() => _progress = value);
      });
      if (!mounted) return;
      setState(() {
        _installing = false;
        _progress = 1;
      });
      _system('Alpine 环境安装完成，正在启动终端…');
      await _startSession();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _installing = false);
      _system('安装失败：$error');
    }
  }

  void _appendLine(TerminalLine line) {
    _lines.add(line);
    if (_lines.length > 4000) {
      _lines.removeRange(0, _lines.length - 4000);
    }
    _scheduleRebuild();
  }

  void _system(String message) {
    _appendLine(TerminalLine(message, TerminalLineKind.system));
  }

  void _scheduleRebuild() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      if (!mounted) return;
      setState(() {});
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  Future<void> _run([String? value]) async {
    final session = _session;
    if (session == null || _busy || _installing) return;

    final command = (value ?? _input.text).trim();
    if (command.isEmpty) return;

    _input.clear();
    if (_history.isEmpty || _history.last != command) {
      _history.add(command);
    }
    _historyIndex = _history.length;
    setState(() => _busy = true);
    _inputFocus.requestFocus();

    try {
      await session.run(command);
    } on Object catch (error) {
      _system('无法执行命令：$error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _inputFocus.requestFocus();
      }
    }
  }

  Future<void> _stop() async {
    final session = _session;
    if (session == null) return;
    await session.close();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _session = null;
    });
    _system('已终止终端进程，点击右上角可重新启动。');
  }

  void _recallHistory(int delta) {
    if (_history.isEmpty) return;
    final next = (_historyIndex + delta).clamp(0, _history.length);
    _historyIndex = next;
    _input.text = next == _history.length ? '' : _history[next];
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_installing || _preparing) _buildProgress(),
            Expanded(child: _buildOutput()),
            if (_needsInstall && !_installing) _buildInstallPanel(),
            _buildQuickCommands(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final runtime = _runtime;
    final statusLabel = _preparing
        ? '准备中'
        : runtime == null
            ? '不可用'
            : runtime.isProot
                ? 'Alpine · proot'
                : '系统 Shell';
    final statusColor = !_preparing && runtime != null && runtime.isProot
        ? _success
        : _muted;

    return AppBar(
      backgroundColor: _panel,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '终端',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            widget.project.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '清屏',
          onPressed: _lines.isEmpty ? null : () => setState(_lines.clear),
          icon: const Icon(Icons.cleaning_services_outlined, size: 19),
        ),
        IconButton(
          tooltip: '重启终端',
          onPressed: _restartSession,
          icon: const Icon(Icons.refresh_rounded, size: 19),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: _installing ? _progress : null,
          minHeight: 2,
          backgroundColor: _border,
          color: _accent,
        ),
        if (_installing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '正在解压 Alpine 根文件系统… ${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildOutput() {
    if (_initializationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '终端初始化失败：$_initializationError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _danger, fontSize: 12.5),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _inputFocus.requestFocus(),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        itemCount: _lines.length,
        itemBuilder: (context, index) {
          final line = _lines[index];
          return SelectableText(
            line.text.isEmpty ? ' ' : line.text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.45,
              color: _colorFor(line.kind),
              fontWeight: line.kind == TerminalLineKind.command
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }

  Color _colorFor(TerminalLineKind kind) => switch (kind) {
        TerminalLineKind.command => _accent,
        TerminalLineKind.output => _text,
        TerminalLineKind.error => _danger,
        TerminalLineKind.system => _muted,
      };

  Widget _buildInstallPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.memory_rounded, color: _accent, size: 19),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '安装 Alpine 编译环境',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '约 4 MB · 无需 root · 解压后即可离线使用',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: FilledButton.icon(
              onPressed: _installEnvironment,
              style: FilledButton.styleFrom(backgroundColor: _accent),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('开始安装'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCommands() {
    const quickCommands = <(String, String)>[
      ('列出文件', 'ls -la'),
      ('系统信息', 'uname -a'),
      ('安装 Dart', 'apk add --no-cache dart'),
      ('更新软件源', 'apk update'),
      ('构建 APK', 'command -v flutter >/dev/null 2>&1 && flutter build apk --debug '
          "|| echo '未安装 Flutter SDK：请先在容器内安装 Flutter'"),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        itemCount: quickCommands.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, command) = quickCommands[index];
          final enabled = _canRun;
          return ActionChip(
            label: Text(label),
            onPressed: enabled ? () => _run(command) : null,
            backgroundColor: _panelAlt,
            side: const BorderSide(color: _border),
            labelStyle: TextStyle(
              color: enabled ? _text : _muted,
              fontSize: 11.5,
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 2),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    final enabled = _canRun;
    final prompt = _promptLabel();

    return Container(
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 168),
            child: Text(
              prompt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: enabled ? _success : _muted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '\$',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: enabled ? _success : _muted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _recallHistory(-1);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _recallHistory(1);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _input,
                focusNode: _inputFocus,
                enabled: enabled,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: _text,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  hintText: _installing
                      ? '正在安装环境…'
                      : _busy
                          ? '命令执行中…'
                          : '输入命令',
                  hintStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: _muted,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: _run,
                autocorrect: false,
                enableSuggestions: false,
              ),
            ),
          ),
          if (_busy)
            IconButton(
              tooltip: '停止',
              onPressed: _stop,
              icon: const Icon(Icons.stop_circle_outlined),
              color: _danger,
            )
          else
            IconButton(
              tooltip: '执行',
              onPressed: enabled ? () => _run() : null,
              icon: const Icon(Icons.keyboard_return_rounded),
              color: enabled ? _success : _muted,
            ),
        ],
      ),
    );
  }

  String _promptLabel() {
    final runtime = _runtime;
    final pwd = _session?.prompt ?? runtime?.promptPath ?? widget.project.path;
    if (runtime?.isProot == true) return 'root@alpine:$pwd';
    final name = p.basename(pwd);
    return name.isEmpty ? pwd : name;
  }
}
