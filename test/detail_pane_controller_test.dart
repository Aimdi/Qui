import 'package:flutter_test/flutter_test.dart';
import 'package:qui/status.dart';
import 'package:qui/ui/detail_pane.dart';

void main() {
  StatusScreenArguments args(String id) => StatusScreenArguments(id: id, username: null);

  test('open/back/close manage the reading-pane stack', () {
    final c = DetailPaneController();
    expect(c.hasSelection, isFalse);
    expect(c.current, isNull);
    expect(c.canGoBack, isFalse);

    c.open(args('1'));
    expect(c.hasSelection, isTrue);
    expect(c.current!.id, '1');
    expect(c.canGoBack, isFalse);

    c.open(args('2'));
    expect(c.current!.id, '2');
    expect(c.canGoBack, isTrue);

    c.back();
    expect(c.current!.id, '1');
    expect(c.canGoBack, isFalse);

    c.back(); // already at the root — stays put
    expect(c.current!.id, '1');

    c.close();
    expect(c.hasSelection, isFalse);
    expect(c.current, isNull);
  });

  test('re-opening the post already on top does not stack a duplicate', () {
    final c = DetailPaneController();
    c.open(args('1'));
    c.open(args('1'));
    expect(c.canGoBack, isFalse);
    c.close();
    expect(c.hasSelection, isFalse);
  });

  test('notifies listeners only on real changes', () {
    final c = DetailPaneController();
    var notifications = 0;
    c.addListener(() => notifications++);
    c.open(args('1')); // +1
    c.open(args('1')); // no-op, no notification
    c.open(args('2')); // +1
    c.back(); // +1
    c.close(); // +1
    expect(notifications, 4);
  });
}
