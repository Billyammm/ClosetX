import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/camera_kit_service.dart';
import '../models/garment.dart';
import '../state/closet_store.dart';
import '../theme.dart';
import '../widgets/closet_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  String _category = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ClosetStoreScope.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final garments = store.garments.where((garment) {
      final categoryMatches =
          _category == 'All' || garment.category == _category;
      final queryMatches =
          query.isEmpty ||
          garment.name.toLowerCase().contains(query) ||
          garment.designer.toLowerCase().contains(query) ||
          garment.impact.toLowerCase().contains(query);
      return categoryMatches && queryMatches;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search the edit'),
        actions: [
          CartCountButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const CartScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Designers, pieces, materials...',
                prefixIcon: const Icon(Icons.search_rounded, color: muted),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 64,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              scrollDirection: Axis.horizontal,
              children: [
                for (final category in const [
                  'All',
                  'Dresses',
                  'Tops',
                  'Sets',
                  'Bottoms',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: garments.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No pieces found',
                    message:
                        'Try a different search or choose another category.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: garments.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.60,
                        ),
                    itemBuilder: (context, index) {
                      final garment = garments[index];
                      return GarmentCard(
                        garment: garment,
                        isSaved: store.isSaved(garment),
                        onSave: () => store.toggleSaved(garment),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ProductDetailScreen(garment: garment),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({required this.garment, super.key});

  final Garment garment;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String _size = 'M';
  int _quantity = 1;
  final _cameraKitService = CameraKitService();

  Future<void> _launchTryOn(Garment garment) async {
    try {
      await _cameraKitService.launchLens(garment);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not start Camera Kit.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final garment = widget.garment;
    final store = ClosetStoreScope.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 400,
            backgroundColor: paper,
            actions: [
              IconButton(
                tooltip: store.isSaved(garment) ? 'Remove saved item' : 'Save',
                onPressed: () => store.toggleSaved(garment),
                icon: Icon(
                  store.isSaved(garment)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: store.isSaved(garment) ? accent : ink,
                ),
              ),
              CartCountButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CartScreen()),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: FashionImage(
                imageUrl: garment.imageUrl,
                background: garment.color,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    garment.designer.toUpperCase(),
                    style: const TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(garment.name, style: headingStyle(27)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        garment.formattedPrice,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      const Icon(Icons.eco_outlined, size: 17, color: accent),
                      const SizedBox(width: 7),
                      Text(
                        garment.impact,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    garment.description,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  if (garment.lensId != null ||
                      garment.lensGroupId != null) ...[
                    const SizedBox(height: 16),
                    _LensStudioMetadata(garment: garment),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Choose a size',
                    style: TextStyle(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 9,
                    children: [
                      for (final size in const ['XS', 'S', 'M', 'L', 'XL'])
                        ChoiceChip(
                          label: Text(size),
                          selected: _size == size,
                          onSelected: (_) => setState(() => _size = size),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Text(
                        'Quantity',
                        style: TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Decrease quantity',
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      Text(
                        '$_quantity',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        tooltip: 'Increase quantity',
                        onPressed: () => setState(() => _quantity++),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        store.addToCart(garment, _size, quantity: _quantity);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${garment.name} added to your bag'),
                            action: SnackBarAction(
                              label: 'VIEW BAG',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const CartScreen(),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text('Add to bag'),
                      style: FilledButton.styleFrom(
                        backgroundColor: ink,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _launchTryOn(garment),
                      icon: const Icon(Icons.center_focus_strong_rounded),
                      label: const Text('Try-On with AR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        minimumSize: const Size(0, 50),
                        side: const BorderSide(color: line),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LensStudioMetadata extends StatelessWidget {
  const _LensStudioMetadata({required this.garment});

  final Garment garment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sage,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LENS STUDIO ASSET',
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          if (garment.lensId != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              'Lens ID: ${garment.lensId}',
              style: const TextStyle(color: ink, fontSize: 12),
            ),
          ],
          if (garment.lensGroupId != null) ...[
            const SizedBox(height: 5),
            SelectableText(
              'Lens group: ${garment.lensGroupId}',
              style: const TextStyle(color: ink, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'This design opens its published Lens in Snap Camera Kit.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ClosetStoreScope.of(context);
    final items = store.cartItems;

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping bag')),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Your bag is empty',
              message: 'Find a piece you love and add it to your bag.',
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: SizedBox(
                              width: 88,
                              height: 110,
                              child: FashionImage(
                                imageUrl: item.garment.imageUrl,
                                background: item.garment.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.garment.designer.toUpperCase(),
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  item.garment.name,
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Size ${item.size}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.garment.formattedPrice,
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Decrease quantity',
                                      onPressed: () => store.setQuantity(
                                        item,
                                        item.quantity - 1,
                                      ),
                                      icon: const Icon(
                                        Icons.remove_circle_outline_rounded,
                                        size: 20,
                                      ),
                                    ),
                                    Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Increase quantity',
                                      onPressed: () => store.setQuantity(
                                        item,
                                        item.quantity + 1,
                                      ),
                                      icon: const Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 20,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () =>
                                          store.removeFromCart(item),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: line)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Subtotal',
                              style: TextStyle(color: muted, fontSize: 14),
                            ),
                            const Spacer(),
                            Text(
                              formatPeso(store.subtotal),
                              style: const TextStyle(
                                color: ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Delivery and payment are arranged at checkout.',
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => _showCheckoutNotice(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: ink,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 50),
                            ),
                            child: const Text('Continue to checkout'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showCheckoutNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Checkout is not connected in this preview. Your bag is still saved for this session.',
        ),
      ),
    );
  }
}

class TryOnScreen extends StatelessWidget {
  const TryOnScreen({required this.garment, super.key});

  final Garment garment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF24231F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF24231F),
        foregroundColor: Colors.white,
        title: const Text('Preview concept'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FashionImage(
                        imageUrl: garment.imageUrl,
                        background: const Color(0xFF555147),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.28),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                      const Positioned(
                        top: 15,
                        left: 15,
                        child: _PreviewBadge(),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              garment.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${garment.designer}  ·  ${garment.formattedPrice}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 17),
              const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFD4B6A8),
                    size: 18,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'This is a sample look preview. Live camera tracking and virtual fitting are not connected yet.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    minimumSize: const Size(0, 50),
                  ),
                  child: const Text('Back to the piece'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.center_focus_strong_rounded,
            color: Colors.white,
            size: 15,
          ),
          SizedBox(width: 6),
          Text(
            'PREVIEW ONLY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class ImpactScreen extends StatelessWidget {
  const ImpactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
      children: [
        const Text(
          'DRESS WITH INTENTION',
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text('A little more\nthoughtful.', style: headingStyle(31)),
        const SizedBox(height: 10),
        const Text(
          'Discover the people and choices behind a more considered wardrobe.',
          style: TextStyle(color: muted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: sage,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.eco_outlined, color: accent, size: 27),
              SizedBox(height: 20),
              Text(
                'BUY LESS.\nCHOOSE WELL.',
                style: TextStyle(
                  color: ink,
                  fontSize: 25,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Get to know the local makers behind the clothes you choose.',
                style: TextStyle(color: muted, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _ImpactRow(
          icon: Icons.design_services_outlined,
          title: 'Made by local designers',
          subtitle: 'Explore Filipino creativity, one piece at a time.',
        ),
        const _ImpactRow(
          icon: Icons.recycling_outlined,
          title: 'More considered choices',
          subtitle: 'Learn about the fabric and process behind each item.',
        ),
        const _ImpactRow(
          icon: Icons.favorite_border_rounded,
          title: 'Pieces to keep',
          subtitle: 'Discover thoughtful designs made for repeat wear.',
        ),
        const SizedBox(height: 10),
        const Text(
          'Impact information is illustrative in this prototype.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ClosetStoreScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
      children: [
        const Text(
          'YOUR CLOSETX',
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text('Your style,\nyour way.', style: headingStyle(31)),
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: line),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: sage,
                child: Icon(Icons.person_outline_rounded, color: ink),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to ClosetX',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your personal style space',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sign in',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LoginScreen(
                      onContinue: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.login_rounded, color: accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ProfileOption(
          icon: Icons.bookmark_border_rounded,
          title: 'Saved pieces',
          subtitle: '${store.savedGarments.length} in your edit',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Open Saved from the bottom navigation.'),
            ),
          ),
        ),
        _ProfileOption(
          icon: Icons.shopping_bag_outlined,
          title: 'Shopping bag',
          subtitle: '${store.cartCount} pieces',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const CartScreen())),
        ),
        _ProfileOption(
          icon: Icons.eco_outlined,
          title: 'Our local edit',
          subtitle: 'Meet the makers and materials',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ImpactScreen())),
        ),
        _ProfileOption(
          icon: Icons.straighten_rounded,
          title: 'Size guide',
          subtitle: 'Find your best fit',
          onTap: () => _showSizeGuide(context),
        ),
        const SizedBox(height: 15),
        const Text(
          'Prototype build · Profile and bag data are stored for this session only.',
          style: TextStyle(color: muted, fontSize: 11, height: 1.5),
        ),
      ],
    );
  }

  void _showSizeGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Size guide'),
        content: const Text(
          'Sizes can vary by designer. Check the garment details or contact the maker before ordering.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 3),
      leading: Icon(icon, color: muted),
      title: Text(
        title,
        style: const TextStyle(
          color: ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: muted, fontSize: 11),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: muted),
      onTap: onTap,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.onContinue, super.key});

  final VoidCallback onContinue;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ClosetLogo(),
                  const SizedBox(height: 24),
                  Text('Welcome back.', style: headingStyle(29)),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to keep your favourite local finds together.',
                    style: TextStyle(color: muted, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 26),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Enter your email address.';
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email)) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(context),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your password.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => _submit(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                    ),
                    child: const Text('Sign in'),
                  ),
                  const SizedBox(height: 13),
                  const Text(
                    'Account sign-in is not connected in this prototype. You can keep exploring without an account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 11, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: widget.onContinue,
                    child: const Text('Continue browsing'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sign-in is not connected yet. Continue browsing as a guest.',
        ),
      ),
    );
  }
}
