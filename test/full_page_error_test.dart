import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/ui/errors.dart';

void main() {
  testWidgets('a missing stack trace is omitted instead of showing null', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L10n.delegate.supportedLocales,
        home: const Scaffold(
          body: FullPageErrorWidget(
            error: 'boom',
            stackTrace: null,
            prefix: 'while loading the feed',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('null'), findsNothing);
    expect(find.text('boom'), findsOneWidget);
    expect(find.text('while loading the feed'), findsOneWidget);
  });
}
