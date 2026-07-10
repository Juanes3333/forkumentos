import 'package:flutter/material.dart';

/// The root Widget of the application.
class App extends StatelessWidget {
  /// Creates a new [App] instance.
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Forkumentos',
      home: Scaffold(body: Center(child: Text('Forkumentos Bootstrap Ready'))),
    );
  }
}
