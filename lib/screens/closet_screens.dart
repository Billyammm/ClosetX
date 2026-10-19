import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/garment.dart';
import '../data/closetx_repository.dart';
import '../state/closet_store.dart';
import '../state/session_store.dart';
import '../theme.dart';
import '../widgets/closet_widgets.dart';
import '../widgets/tryon_view.dart';
import 'account_screens.dart';
import 'tryon_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({this.isBrowse = false, super.key});

  final bool isBrowse;

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
        title: Text(widget.isBrowse ? 'Browse designs' : 'Search the edit'),
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
              autofocus: !widget.isBrowse,
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
                for (final category in [
                  'All',
                  ...{for (final garment in store.garments) garment.category},
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
                        onSave: () => toggleSavedGarment(context, garment),
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
  int _quantity = 1;
  final _repository = ClosetXRepository();
  List<DesignReview> _reviews = const [];
  bool _reviewsLoading = false;

  void _openTryOn(Garment garment, TryOnMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TryOnScreen(garment: garment, initialMode: mode),
      ),
    );
  }

  Future<void> _addToBag() async {
    final session = SessionScope.of(context);
    if (!session.isSignedIn) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (routeContext) => LoginScreen(
            shopperOnly: true,
            onContinue: () => Navigator.of(routeContext).pop(),
          ),
        ),
      );
      if (!mounted || !session.isSignedIn) return;
    }

    await session.ensureProfileLoaded();
    if (!mounted) return;
    if (session.loadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not verify your shopper account.')),
      );
      return;
    }
    if (!session.isShopper) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in with a shopper account to add items.'),
        ),
      );
      return;
    }

    final store = ClosetStoreScope.of(context);
    store.addToCart(widget.garment, quantity: _quantity);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(child: Text('${widget.garment.name} added to your bag')),
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                navigator.push(
                  MaterialPageRoute<void>(builder: (_) => const CartScreen()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onInverseSurface,
              ),
              child: const Text('VIEW BAG'),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String? get _designId {
    const prefix = 'supabase:';
    return widget.garment.id.startsWith(prefix)
        ? widget.garment.id.substring(prefix.length)
        : null;
  }

  @override
  void initState() {
    super.initState();
    if (_designId != null) _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _reviewsLoading = true);
    try {
      final reviews = await _repository.loadDesignReviews(_designId!);
      if (mounted) setState(() => _reviews = reviews);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reviews are temporarily unavailable.')),
        );
      }
    } finally {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _openReviewComposer() async {
    final session = SessionScope.of(context);
    if (!session.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to rate and comment on a design.'),
        ),
      );
      return;
    }
    final existing = _reviews.where((review) => review.isMine).firstOrNull;
    var rating = existing?.rating ?? 5;
    final controller = TextEditingController(text: existing?.comment ?? '');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Rate this design' : 'Edit your review',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 2,
                children: [
                  for (var value = 1; value <= 5; value++)
                    IconButton(
                      tooltip: '$value star${value == 1 ? '' : 's'}',
                      onPressed: () => setDialogState(() => rating = value),
                      icon: Icon(
                        value <= rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: accent,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  hintText: 'What do you think about this design?',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.of(dialogContext).pop(rating);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) {
      controller.dispose();
      return;
    }
    try {
      await _repository.submitDesignReview(
        designId: _designId!,
        rating: result,
        comment: controller.text,
      );
      await _loadReviews();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your review right now.'),
          ),
        );
      }
    } finally {
      controller.dispose();
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
                onPressed: () => toggleSavedGarment(context, garment),
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
              IconButton(
                tooltip: 'Rate this design',
                onPressed: _designId == null ? null : _openReviewComposer,
                icon: const Icon(Icons.rate_review_outlined, color: ink),
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
                  BrandTag(
                    garment: garment,
                    logoSize: 30,
                    style: const TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                  _DesignReviews(
                    reviews: _reviews,
                    isLoading: _reviewsLoading,
                    onReview: _designId == null ? null : _openReviewComposer,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    garment.description,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 14,
                      height: 1.55,
                    ),
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
                      onPressed: _addToBag,
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openTryOn(garment, TryOnMode.viewer3d),
                          icon: const Icon(Icons.view_in_ar_outlined),
                          label: const Text('View in 3D'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            minimumSize: const Size(0, 50),
                            side: const BorderSide(color: line),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openTryOn(garment, TryOnMode.camera),
                          icon: const Icon(Icons.center_focus_strong_rounded),
                          label: const Text('Try on'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            minimumSize: const Size(0, 50),
                            side: const BorderSide(color: line),
                          ),
                        ),
                      ),
                    ],
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

class _DesignReviews extends StatelessWidget {
  const _DesignReviews({
    required this.reviews,
    required this.isLoading,
    required this.onReview,
  });

  final List<DesignReview> reviews;
  final bool isLoading;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final average = reviews.isEmpty
        ? 0
        : reviews.map((review) => review.rating).reduce((a, b) => a + b) /
              reviews.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            if (reviews.isNotEmpty) ...[
              const Icon(Icons.star_rounded, size: 18, color: accent),
              const SizedBox(width: 3),
              Text(
                '${average.toStringAsFixed(1)} (${reviews.length})',
                style: const TextStyle(color: muted, fontSize: 13),
              ),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: onReview,
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: Text(
                reviews.any((review) => review.isMine) ? 'Edit' : 'Review',
              ),
            ),
          ],
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'No reviews yet. Be the first to share what you think.',
              style: TextStyle(color: muted, height: 1.45),
            ),
          )
        else
          ...reviews
              .take(3)
              .map(
                (review) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: paper,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  review.authorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  for (var star = 1; star <= 5; star++)
                                    Icon(
                                      star <= review.rating
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      size: 16,
                                      color: accent,
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            review.comment,
                            style: const TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ],
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
                                BrandTag(garment: item.garment, logoSize: 18),
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

class ImpactScreen extends StatelessWidget {
  const ImpactScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final content = ListView(
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

    if (!showAppBar) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('Our local edit')),
      body: content,
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
    final session = SessionScope.of(context);
    final isDesigner = session.profile?.isDesigner == true;
    final brand = session.brand;
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
        const _AccountCard(),
        if (session.profile?.isDesigner == true)
          _DesignerSection(profile: session.profile!),
        const SizedBox(height: 12),
        if (isDesigner) ...[
          if (brand != null)
            _ProfileOption(
              icon: Icons.storefront_outlined,
              title: 'Brand profile',
              subtitle: 'Edit your brand information and logo',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BrandEditorScreen(),
                ),
              ),
            ),
          if (session.profile?.isApprovedDesigner == true)
            _ProfileOption(
              icon: Icons.checkroom_outlined,
              title: 'My Designs',
              subtitle: 'Manage your uploaded designs',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DesignerStudioScreen(),
                ),
              ),
            ),
        ] else ...[
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
        ],
        _ProfileOption(
          icon: Icons.eco_outlined,
          title: 'Our local edit',
          subtitle: 'Meet the makers and materials',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ImpactScreen(showAppBar: true),
            ),
          ),
        ),
        _ProfileOption(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Share feedback',
          subtitle: 'Tell us how ClosetX could be better',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          isDesigner
              ? 'Application status updates appear in the notification icon.'
              : 'Saved pieces and your bag are kept for this session only.',
          style: TextStyle(color: muted, fontSize: 11, height: 1.5),
        ),
      ],
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

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Are you sure you want to sign out of your ClosetX account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true || !context.mounted) return;

    try {
      await SessionScope.of(context).signOut();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not sign out: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final profile = session.profile;
    final signedIn = session.isSignedIn;

    final String title;
    final String subtitle;
    if (!signedIn) {
      title = 'Welcome to ClosetX';
      subtitle = 'Sign in to shop or open your brand';
    } else if (profile == null) {
      title = session.isLoading ? 'Loading your account…' : 'Signed in';
      subtitle = session.loadError == null
          ? ''
          : 'Could not load your profile. Sign out and in again.';
    } else {
      title = profile.displayName;
      subtitle = profile.isDesigner
          ? switch (profile.designerStatus) {
              'approved' =>
                'Designer${session.brand == null ? '' : ' · ${session.brand!.name}'}',
              'rejected' => 'Designer application not approved',
              _ => 'Designer application pending review',
            }
          : 'Shopper · ${profile.email}';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: sage,
            child: Icon(
              profile?.isDesigner == true
                  ? Icons.design_services_outlined
                  : Icons.person_outline_rounded,
              color: ink,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (signedIn)
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout_rounded, color: muted),
            )
          else
            IconButton(
              tooltip: 'Sign in',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (routeContext) => LoginScreen(
                    onContinue: () => Navigator.of(routeContext).pop(),
                  ),
                ),
              ),
              icon: const Icon(Icons.login_rounded, color: accent),
            ),
        ],
      ),
    );
  }
}

class _DesignerSection extends StatelessWidget {
  const _DesignerSection({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final brand = SessionScope.of(context).brand;
    if (!profile.isApprovedDesigner) {
      final rejected = profile.designerStatus == 'rejected';
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: sage,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rejected ? 'APPLICATION NOT APPROVED' : 'APPLICATION IN REVIEW',
              style: const TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              rejected
                  ? 'Thank you for applying.'
                  : 'We are reviewing your application.',
              style: headingStyle(20),
            ),
            const SizedBox(height: 6),
            Text(
              rejected
                  ? (profile.designerRejectionReason?.trim().isNotEmpty == true
                        ? profile.designerRejectionReason!
                        : 'You can contact us if you have questions.')
                  : 'We will let you know when your designer access is ready.',
              style: const TextStyle(color: muted, fontSize: 12, height: 1.45),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: sage,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DESIGNER STUDIO',
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            brand == null ? 'Create your brand' : brand.name,
            style: headingStyle(21),
          ),
          const SizedBox(height: 6),
          Text(
            brand == null
                ? 'Set up your label, then upload front and back artwork for each shirt.'
                : !brand.hasLogo
                ? 'Add your brand logo so shoppers recognise your shirts.'
                : brand.location.isEmpty
                ? 'Upload shirts and manage what shoppers see.'
                : brand.location,
            style: const TextStyle(color: muted, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => brand == null
                    ? const BrandEditorScreen()
                    : const DesignerStudioScreen(),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Colors.white,
            ),
            icon: Icon(
              brand == null
                  ? Icons.storefront_outlined
                  : Icons.checkroom_outlined,
            ),
            label: Text(brand == null ? 'Create brand' : 'Open studio'),
          ),
        ],
      ),
    );
  }
}
