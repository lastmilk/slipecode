import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_editor/core/theme/app_theme.dart';
import 'package:flutter_editor/providers/project_provider.dart';
import 'package:flutter_editor/providers/editor_provider.dart';
import 'package:flutter_editor/features/home/home_page.dart';

class FlutterEditorApp extends StatelessWidget {
  const FlutterEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => EditorProvider()),
      ],
      child: MaterialApp(
        title: 'Flutter Editor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomePage(),
      ),
    );
  }
}
