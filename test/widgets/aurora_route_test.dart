import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tk2ragaspace/widgets/aurora_route.dart';

class _RouteTarget extends StatelessWidget {
  const _RouteTarget();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Target'));
  }
}

void main() {
  testWidgets('AuroraWarpRoute pushes target page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              AuroraWarpRoute(const _RouteTarget()),
            ),
            child: const Text('Go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Target'), findsOneWidget);
  });

  testWidgets('ZoomInRoute pushes target page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              ZoomInRoute(const _RouteTarget()),
            ),
            child: const Text('Zoom'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Zoom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Target'), findsOneWidget);
  });
}

