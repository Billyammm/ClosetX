import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:closetx/main.dart';
import 'package:closetx/supabase/supabase_config.dart';

void main() {
  testWidgets('ClosetX showroom and navigation render', (tester) async {
    await tester.pumpWidget(const ClosetXApp());
    await tester.tap(find.text('Continue browsing'));
    await tester.pumpAndSettle();

    expect(find.text('Find your next\nfavourite.'), findsOneWidget);
    expect(find.text('Featured designs'), findsOneWidget);
    if (!isSupabaseConfigured) {
      await tester.scrollUntilVisible(
        find.text('Connect to your ClosetX database'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Connect to your ClosetX database'), findsOneWidget);
    }
    expect(find.text('Discover'), findsOneWidget);

    await tester.tap(find.text('Impact'));
    await tester.pumpAndSettle();

    expect(find.text('A little more\nthoughtful.'), findsOneWidget);
    expect(find.text('Made by local designers'), findsOneWidget);
  });

  testWidgets('saved tab shows an empty state initially', (tester) async {
    await tester.pumpWidget(const ClosetXApp());
    await tester.tap(find.text('Continue browsing'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    expect(find.text('Saved pieces'), findsOneWidget);
    expect(find.text('Your edit is waiting'), findsOneWidget);
  });
}
