import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qui/ui/adaptive_sheet.dart';
import 'package:qui/ui/layout.dart';

void main() {
  testWidgets('wide windows get a dialog instead of a bottom sheet', (
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
              body: TextButton(
                onPressed: () => showAdaptiveSheet(
                  context: context,
                  builder: (_) => const Text('sheet-body'),
                ),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('sheet-body'), findsOneWidget);
  });

  testWidgets('compact windows keep a bottom sheet', (tester) async {
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
              body: TextButton(
                onPressed: () => showAdaptiveSheet(
                  context: context,
                  builder: (_) => const Text('sheet-body'),
                ),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('sheet-body'), findsOneWidget);
  });
}
