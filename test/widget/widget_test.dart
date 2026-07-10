import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/app/app.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/storage/storage_providers.dart';
import 'package:forkumentos/routing/app_shell.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('App renders structural shell with provider overrides', (
    WidgetTester tester,
  ) async {
    final fakeLogger = FakeLoggingService();
    final fakeStorage = FakeKeyValueStorage();
    await fakeStorage.initialize();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          loggingServiceProvider.overrideWithValue(fakeLogger),
          keyValueStorageProvider.overrideWithValue(fakeStorage),
        ],
        child: const App(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNWidgets(2));
  });
}
