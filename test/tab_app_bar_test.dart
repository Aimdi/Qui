import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qui/ui/layout.dart';
import 'package:qui/ui/tab_app_bar.dart';

void main() {
  testWidgets('desktop tabs drop the duplicate title the rail already shows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(useDesktopShell(context), isTrue);
            return Scaffold(
              appBar: tabAppBar(
                context: context,
                title: const Text('Subscriptions'),
                actions: [
                  IconButton(icon: const Icon(Icons.add), onPressed: () {}),
                ],
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Subscriptions'), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('compact tabs keep the title', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(useDesktopShell(context), isFalse);
            return Scaffold(
              appBar: tabAppBar(
                context: context,
                title: const Text('Subscriptions'),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Subscriptions'), findsOneWidget);
  });
}
