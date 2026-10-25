import 'package:flutter/material.dart';

/// 新建项目时可选择的模板。
class ProjectTemplate {
  const ProjectTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.accent,
    required this.buildFiles,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color accent;

  /// 以合法的 Dart 包名为参数，返回「相对路径 -> 文件内容」。
  final Map<String, String> Function(String packageName) buildFiles;
}

const _pubspecTemplate = '''
name: @packageName@
description: "由 Slipecode 创建的 Flutter 项目"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
''';

const _analysisOptions = '''
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    avoid_print: false
''';

const _gitignore = '''
# Flutter / Dart
.dart_tool/
.packages
build/
.flutter-plugins
.flutter-plugins-dependencies

# IDE
.idea/
*.iml
.vscode/

# OS
.DS_Store
''';

const _counterMain = r'''import 'package:flutter/material.dart';

void main() {
  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '计数器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C6CFF),
        ),
      ),
      home: const CounterPage(),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _count = 0;

  void _increment() => setState(() => _count++);

  void _reset() => setState(() => _count = 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('计数器'),
        actions: [
          IconButton(
            onPressed: _count == 0 ? null : _reset,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重置',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '你点击了',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_count',
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '次',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _increment,
        tooltip: '增加',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
''';

const _counterTest = r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:@packageName@/main.dart';

void main() {
  testWidgets('点击按钮后计数增加', (tester) async {
    await tester.pumpWidget(const CounterApp());

    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
  });
}
''';

const _blankMain = r'''import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我的应用',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C6CFF),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的应用')),
      body: const Center(
        child: Text('开始写点什么吧'),
      ),
    );
  }
}
''';

const _todoMain = r'''import 'package:flutter/material.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '待办清单',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C6CFF),
        ),
      ),
      home: const TodoPage(),
    );
  }
}

class TodoItem {
  TodoItem({required this.title, this.done = false});

  final String title;
  bool done;
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final List<TodoItem> _items = [];

  Future<void> _addTodo() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加待办'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '今天要做什么？'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );

    final trimmed = title?.trim() ?? '';
    if (trimmed.isEmpty) return;

    setState(() => _items.add(TodoItem(title: trimmed)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待办清单'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_items.where((item) => !item.done).length} 项未完成',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('还没有待办事项'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return CheckboxListTile(
                  value: item.done,
                  title: Text(
                    item.title,
                    style: TextStyle(
                      decoration:
                          item.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => item.done = value ?? false);
                  },
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () {
                      setState(() => _items.removeAt(index));
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTodo,
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加待办'),
      ),
    );
  }
}
''';

Map<String, String> _baseFiles(String packageName) {
  return {
    'pubspec.yaml': _pubspecTemplate.replaceAll('@packageName@', packageName),
    'analysis_options.yaml': _analysisOptions,
    '.gitignore': _gitignore,
    'README.md': '# $packageName\n\n'
        '由 Slipecode 创建的 Flutter 项目。\n\n'
        '## 运行\n\n'
        '```bash\n'
        'flutter pub get\n'
        'flutter run\n'
        '```\n',
  };
}

final List<ProjectTemplate> projectTemplates = [
  ProjectTemplate(
    id: 'counter',
    name: '计数器应用',
    description: 'Material 3 状态管理示例',
    icon: Icons.exposure_plus_1_rounded,
    accent: const Color(0xFF6C8CFF),
    buildFiles: (packageName) => {
      ..._baseFiles(packageName),
      'lib/main.dart': _counterMain,
      'test/widget_test.dart': _counterTest.replaceAll('@packageName@', packageName),
    },
  ),
  ProjectTemplate(
    id: 'todo',
    name: '待办清单',
    description: '列表、对话框与交互',
    icon: Icons.checklist_rounded,
    accent: const Color(0xFF46C2A4),
    buildFiles: (packageName) => {
      ..._baseFiles(packageName),
      'lib/main.dart': _todoMain,
    },
  ),
  ProjectTemplate(
    id: 'blank',
    name: '空白应用',
    description: '只有入口文件的干净起点',
    icon: Icons.crop_square_rounded,
    accent: const Color(0xFFB07CFF),
    buildFiles: (packageName) => {
      ..._baseFiles(packageName),
      'lib/main.dart': _blankMain,
    },
  ),
];

ProjectTemplate templateById(String id) {
  return projectTemplates.firstWhere(
    (template) => template.id == id,
    orElse: () => projectTemplates.first,
  );
}
