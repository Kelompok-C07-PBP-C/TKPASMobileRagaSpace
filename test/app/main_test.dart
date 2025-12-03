import 'package:flutter_test/flutter_test.dart';
import 'package:marco/features/authentication/login_screen.dart';
import 'package:marco/main.dart' as app;

void main() {
  testWidgets('MyApp builds login screen', (tester) async {
    await tester.pumpWidget(const app.MyApp());
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}

