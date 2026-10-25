import 'package:flutter/material.dart';

import 'app.dart';
import 'services/project_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await ProjectRepository.open();
  runApp(SlipecodeApp(repository: repository));
}
