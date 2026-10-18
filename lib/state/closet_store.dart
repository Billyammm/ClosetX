import 'package:flutter/widgets.dart';

import '../models/garment.dart';

@immutable
class CartItem {
  const CartItem({required this.garment, required this.quantity});

  final Garment garment;
  final int quantity;

  String get id => garment.id;
  int get lineTotal => garment.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(garment: garment, quantity: quantity ?? this.quantity);
}

class ClosetStore extends ChangeNotifier {
  ClosetStore({required List<Garment> garments})
    : _garments = List.of(garments);

  List<Garment> _garments;
  final Set<String> _savedIds = {};
  final Map<String, CartItem> _cartItems = {};
  bool _isLoadingCatalog = false;
  Object? _catalogError;

  List<Garment> get garments => List.unmodifiable(_garments);
  bool get isLoadingCatalog => _isLoadingCatalog;
  Object? get catalogError => _catalogError;
  Set<String> get savedIds => Set.unmodifiable(_savedIds);
  List<CartItem> get cartItems => List.unmodifiable(_cartItems.values);
  int get cartCount =>
      _cartItems.values.fold(0, (total, item) => total + item.quantity);
  int get subtotal =>
      _cartItems.values.fold(0, (total, item) => total + item.lineTotal);
  List<Garment> get savedGarments =>
      _garments.where((garment) => _savedIds.contains(garment.id)).toList();

  void replaceGarments(List<Garment> garments) {
    _garments = List.of(garments);
    notifyListeners();
  }

  Future<void> loadCatalog(Future<List<Garment>> Function() load) async {
    _isLoadingCatalog = true;
    _catalogError = null;
    _garments = [];
    notifyListeners();
    try {
      _garments = List.of(await load());
    } catch (error) {
      _catalogError = error;
    } finally {
      _isLoadingCatalog = false;
      notifyListeners();
    }
  }

  bool isSaved(Garment garment) => _savedIds.contains(garment.id);

  void toggleSaved(Garment garment) {
    if (!_savedIds.add(garment.id)) {
      _savedIds.remove(garment.id);
    }
    notifyListeners();
  }

  void replaceSavedIds(Iterable<String> savedIds) {
    _savedIds
      ..clear()
      ..addAll(savedIds);
    notifyListeners();
  }

  void addToCart(Garment garment, {int quantity = 1}) {
    final item = CartItem(garment: garment, quantity: quantity);
    final existing = _cartItems[item.id];
    _cartItems[item.id] = existing == null
        ? item
        : existing.copyWith(quantity: existing.quantity + quantity);
    notifyListeners();
  }

  void setQuantity(CartItem item, int quantity) {
    if (quantity < 1) {
      removeFromCart(item);
      return;
    }
    _cartItems[item.id] = item.copyWith(quantity: quantity);
    notifyListeners();
  }

  void removeFromCart(CartItem item) {
    _cartItems.remove(item.id);
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }
}

class ClosetStoreScope extends InheritedNotifier<ClosetStore> {
  const ClosetStoreScope({
    required ClosetStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  static ClosetStore of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ClosetStoreScope>();
    assert(scope != null, 'ClosetStoreScope is missing above this context.');
    return scope!.notifier!;
  }
}
