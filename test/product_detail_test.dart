import 'package:closetx/screens/closet_screens.dart';
import 'package:closetx/state/closet_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/garments.dart';

void main() {
  late ClosetStore store;

  setUp(() {
    store = ClosetStore(garments: testGarments);
  });

  tearDown(() {
    store.dispose();
  });

  Future<void> openProductDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ClosetStoreScope(
        store: store,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: false),
            child: ProductDetailScreen(garment: testGarments.first),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add to bag'));
    await tester.pumpAndSettle();
  }

  testWidgets('add-to-bag snackbar opens the shopping bag', (tester) async {
    await openProductDetail(tester);

    expect(
      find.text('${testGarments.first.name} added to your bag'),
      findsOneWidget,
    );
    expect(store.cartCount, 1);

    await tester.tap(find.text('VIEW BAG'));
    await tester.pumpAndSettle();

    expect(find.text('Shopping bag'), findsOneWidget);
    expect(find.text(testGarments.first.name), findsOneWidget);
    expect(
      find.text('${testGarments.first.name} added to your bag'),
      findsNothing,
    );
  });

  testWidgets('add-to-bag snackbar disappears after its duration', (
    tester,
  ) async {
    await openProductDetail(tester);

    expect(
      find.text('${testGarments.first.name} added to your bag'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(
      find.text('${testGarments.first.name} added to your bag'),
      findsNothing,
    );
  });
}
