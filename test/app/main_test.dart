import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tk2ragaspace/features/home/home_screen.dart';
import 'package:tk2ragaspace/main.dart' as app;
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    homeSkipNetworkForTests = true;
    homeDisableNetworkImagesForTests = true;
    debugSetFadeSlideInDisabledForTests(true);
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    homeSkipNetworkForTests = false;
    homeDisableNetworkImagesForTests = false;
    debugSetFadeSlideInDisabledForTests(false);
  });

  testWidgets('MyApp builds home screen', (tester) async {
    await tester.pumpWidget(const app.MyApp());
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
