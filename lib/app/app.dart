import 'package:flutter/material.dart';
import 'package:forkumentos/core/theme/app_theme.dart';

/// The root Widget of the application.
class App extends StatelessWidget {
  /// Creates a new [App] instance.
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forkumentos',
      theme: AppTheme.dark,
      home: const Scaffold(
        body: Center(child: Text('Forkumentos Bootstrap Ready')),
      ),
    );
  }
}
