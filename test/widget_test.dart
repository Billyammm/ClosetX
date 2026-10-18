import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:closetx/main.dart';
import 'package:closetx/supabase/supabase_config.dart';

void main() {
  testWidgets('new accounts can choose shopper or designer signup', (
    tester,
  ) async {
    await tester.pumpWidget(const ClosetXApp());

    await tester.tap(find.text('New to ClosetX? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('How will you use ClosetX?'), findsOneWidget);

    await tester.tap(find.text('Designer'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Create a designer account to set up your brand and upload your designs.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Already have an account? Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to ClosetX? Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shopper'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Create a shopper account to save designs and keep your favourites together.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('ClosetX showroom and navigation render', (tester) async {
    await tester.pumpWidget(const ClosetXApp());
    await tester.tap(find.text('Continue browsing as a guest'));
    await tester.pumpAndSettle();

    expect(find.text('Find your next\nfavourite.'), findsOneWidget);
    expect(find.text('Most saved designs'), findsOneWidget);
    if (!isSupabaseConfigured) {
      await tester.scrollUntilVisible(
        find.text('No designs available yet'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No designs available yet'), findsOneWidget);
      expect(find.textContaining('dart-define-from-file'), findsNothing);
    }
    expect(find.text('Discover'), findsOneWidget);

    await tester.tap(find.text('Impact'));
    await tester.pumpAndSettle();

    expect(find.text('A little more\nthoughtful.'), findsOneWidget);
    expect(find.text('Made by local designers'), findsOneWidget);
  });

  testWidgets('saved tab shows an empty state initially', (tester) async {
    await tester.pumpWidget(const ClosetXApp());
    await tester.tap(find.text('Continue browsing as a guest'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    expect(find.text('Saved pieces'), findsOneWidget);
    expect(find.text('Your edit is waiting'), findsOneWidget);
  });
}
