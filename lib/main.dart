import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/app/app.dart';
import 'package:forkumentos/app/bootstrap.dart';

void main() async {
  await bootstrap();
  runApp(const ProviderScope(child: App()));
}
