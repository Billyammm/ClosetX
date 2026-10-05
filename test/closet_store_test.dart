import 'package:closetx/data/garments.dart';
import 'package:closetx/state/closet_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ClosetStore store;

  setUp(() {
    store = ClosetStore(garments: sampleGarments);
  });

  tearDown(() {
    store.dispose();
  });

  test('saved pieces toggle by garment', () {
    final garment = sampleGarments.first;

    store.toggleSaved(garment);
    expect(store.savedGarments, [garment]);

    store.toggleSaved(garment);
    expect(store.savedGarments, isEmpty);
  });

  test('bag merges matching sizes and updates subtotal', () {
    final garment = sampleGarments.first;

    store.addToCart(garment, 'M');
    store.addToCart(garment, 'M', quantity: 2);
    store.addToCart(garment, 'L');

    expect(store.cartCount, 4);
    expect(store.cartItems, hasLength(2));
    expect(store.subtotal, garment.price * 4);

    final mediumItem = store.cartItems.firstWhere((item) => item.size == 'M');
    store.setQuantity(mediumItem, 1);
    expect(store.cartCount, 2);
    expect(store.subtotal, garment.price * 2);
  });

  test('setting a quantity below one removes the bag item', () {
    store.addToCart(sampleGarments.first, 'M');
    store.setQuantity(store.cartItems.single, 0);

    expect(store.cartItems, isEmpty);
    expect(store.cartCount, 0);
    expect(store.subtotal, 0);
  });

  test('replacing the catalog keeps saved item ids visible', () {
    final garment = sampleGarments.first;
    store.toggleSaved(garment);
    store.replaceGarments([garment]);

    expect(store.garments, [garment]);
    expect(store.savedGarments, [garment]);
  });
}
