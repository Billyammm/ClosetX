import 'package:closetx/state/closet_store.dart';
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

  test('saved pieces toggle by garment', () {
    final garment = testGarments.first;

    store.toggleSaved(garment);
    expect(store.savedGarments, [garment]);

    store.toggleSaved(garment);
    expect(store.savedGarments, isEmpty);
  });

  test('saved ids can be replaced after loading shopper saves', () {
    store.replaceSavedIds(['first', 'second']);
    expect(store.savedIds, {'first', 'second'});

    store.replaceSavedIds(['second']);
    expect(store.savedIds, {'second'});
  });

  test('bag merges the same garment and updates subtotal', () {
    final garment = testGarments.first;
    final other = testGarments[1];

    store.addToCart(garment);
    store.addToCart(garment, quantity: 2);
    store.addToCart(other);

    expect(store.cartCount, 4);
    expect(store.cartItems, hasLength(2));
    expect(store.subtotal, garment.price * 3 + other.price);

    final item = store.cartItems.firstWhere((item) => item.garment == garment);
    store.setQuantity(item, 1);
    expect(store.cartCount, 2);
    expect(store.subtotal, garment.price + other.price);
  });

  test('setting a quantity below one removes the bag item', () {
    store.addToCart(testGarments.first);
    store.setQuantity(store.cartItems.single, 0);

    expect(store.cartItems, isEmpty);
    expect(store.cartCount, 0);
    expect(store.subtotal, 0);
  });

  test('replacing the catalog keeps saved item ids visible', () {
    final garment = testGarments.first;
    store.toggleSaved(garment);
    store.replaceGarments([garment]);

    expect(store.garments, [garment]);
    expect(store.savedGarments, [garment]);
  });

  test(
    'failed catalog reload clears garments from the previous catalog',
    () async {
      store.replaceGarments([testGarments.first]);

      await expectLater(
        store.loadCatalog(() async => throw Exception('network unavailable')),
        completes,
      );

      expect(store.garments, isEmpty);
      expect(store.catalogError, isNotNull);
    },
  );
}
