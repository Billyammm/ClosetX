import 'package:closetx/models/account.dart';
import 'package:closetx/screens/closet_screens.dart';
import 'package:closetx/state/closet_store.dart';
import 'package:closetx/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/garments.dart';

class _MockSessionStore extends SessionStore {
  @override
  bool get isSignedIn => true;

  @override
  bool get isShopper => true;

  @override
  String? get userId => 'test-shopper';

  @override
  UserProfile? get profile => const UserProfile(
        id: 'test-shopper',
        email: 'shopper@example.com',
        fullName: 'Test Shopper',
        role: AccountRole.shopper,
        designerStatus: 'approved',
      );

  @override
  Future<void> ensureProfileLoaded() async {}
}

void main() {
  late ClosetStore store;
  late SessionStore sessionStore;

  setUp(() {
    store = ClosetStore(garments: testGarments);
    sessionStore = _MockSessionStore();
  });

  tearDown(() {
    store.dispose();
    sessionStore.dispose();
  });

  Future<void> openProductDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      SessionScope(
        store: sessionStore,
        child: ClosetStoreScope(
          store: store,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(accessibleNavigation: false),
              child: ProductDetailScreen(garment: testGarments.first),
            ),
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
