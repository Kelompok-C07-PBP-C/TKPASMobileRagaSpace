import 'package:flutter_test/flutter_test.dart';
import 'package:tk2ragaspace/features/authentication/login_screen.dart';
import 'package:tk2ragaspace/main.dart' as app;

void main() {
  testWidgets('MyApp builds login screen', (tester) async {
    await tester.pumpWidget(const app.MyApp());
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}

