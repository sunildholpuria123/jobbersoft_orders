import 'package:flutter/material.dart';

import 'core/di/injection.dart';
import 'features/dashboard/dashboard_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();

  runApp(const JobberSoftApp());
}

class JobberSoftApp extends StatelessWidget {
  const JobberSoftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JobberSoft Orders',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DashboardShell(),
    );
  }
}