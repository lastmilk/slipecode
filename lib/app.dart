import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/project_repository.dart';
import 'theme/app_theme.dart';

class SlipecodeApp extends StatelessWidget {
  const SlipecodeApp({super.key, required this.repository});

  final ProjectRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slipecode',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: HomeScreen(repository: repository),
    );
  }
}
