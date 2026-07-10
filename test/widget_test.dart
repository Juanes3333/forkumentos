import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/app/app.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Forkumentos Bootstrap Ready'), findsOneWidget);
  });
}
