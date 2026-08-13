import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qui/ui/keyboard_shortcuts.dart';

void main() {
  testWidgets('slash opens search unless a text field is focused', (
    tester,
  ) async {
    var searches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopKeyboardShortcuts(
          onSearch: () => searches++,
          onSettings: () {},
          onClosePane: () {},
          onScrollNext: () {},
          onScrollPrevious: () {},
          onSelectTab: (_) {},
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pump();
    expect(searches, 1);
  });

  testWidgets('slash in a text field is not stolen', (tester) async {
    var searches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopKeyboardShortcuts(
          onSearch: () => searches++,
          onSettings: () {},
          onClosePane: () {},
          onScrollNext: () {},
          onScrollPrevious: () {},
          onSelectTab: (_) {},
          child: const Scaffold(body: TextField(autofocus: true)),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '/');
    await tester.pump();
    expect(searches, 0);
    expect(find.text('/'), findsOneWidget);
  });

  testWidgets('escape closes the reading pane', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopKeyboardShortcuts(
          onSearch: () {},
          onSettings: () {},
          onClosePane: () => closed++,
          onScrollNext: () {},
          onScrollPrevious: () {},
          onSelectTab: (_) {},
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(closed, 1);
  });

  testWidgets('digit keys select rail tabs', (tester) async {
    var tab = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopKeyboardShortcuts(
          onSearch: () {},
          onSettings: () {},
          onClosePane: () {},
          onScrollNext: () {},
          onScrollPrevious: () {},
          onSelectTab: (index) => tab = index,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    expect(tab, 2);
  });

  testWidgets('j/k scroll the attached feed', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopKeyboardShortcuts(
          onSearch: () {},
          onSettings: () {},
          onClosePane: () {},
          onScrollNext: () => scrollFeedByStep(controller, direction: 1),
          onScrollPrevious: () => scrollFeedByStep(controller, direction: -1),
          onSelectTab: (_) {},
          child: Scaffold(
            body: ListView(
              controller: controller,
              children: List.generate(
                40,
                (i) => SizedBox(height: 100, child: Text('item $i')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));

    final afterJ = controller.offset;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(controller.offset, lessThan(afterJ));
  });
}
