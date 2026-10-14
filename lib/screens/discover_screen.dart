import 'package:flutter/material.dart';

import '../data/closetx_repository.dart';
import '../models/garment.dart';
import '../state/closet_store.dart';
import '../supabase/supabase_config.dart';
import '../theme.dart';
import '../widgets/closet_widgets.dart';
import 'closet_screens.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _category = 'All';
  final _repository = ClosetXRepository();

  @override
  void initState() {
    super.initState();
    if (isSupabaseConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDesigns());
    }
  }

  Future<void> _loadDesigns() => ClosetStoreScope.of(
    context,
  ).loadCatalog(_repository.loadPublishedDesigns);

  @override
  Widget build(BuildContext context) {
    final store = ClosetStoreScope.of(context);
    final isLoadingDatabase = store.isLoadingCatalog;
    final databaseError = store.catalogError;
    final allGarments = store.garments;
    final categories = allGarments.map((item) => item.category).toSet().toList()
      ..sort();
    final garments = allGarments.where((garment) {
      return _category == 'All' || garment.category == _category;
    }).toList();

    return CustomScrollView(
      key: const PageStorageKey('showroom'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
            child: Row(
              children: [
                const ClosetLogo(),
                const Spacer(),
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SearchScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.search_rounded),
                ),
                CartCountButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const CartScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THE LOCAL EDIT',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Find your next\nfavourite.', style: headingStyle(31)),
                const SizedBox(height: 15),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SearchScreen(),
                    ),
                  ),
                  child: IgnorePointer(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search designers, pieces...',
                        prefixIcon: Icon(Icons.search_rounded, color: muted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _LocalEditCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ImpactScreen(showAppBar: true),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 60,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              scrollDirection: Axis.horizontal,
              children: [
                for (final category in ['All', ...categories])
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
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text('Featured designs', style: headingStyle(21)),
                ),
                Text(
                  isLoadingDatabase
                      ? 'Loading...'
                      : '${garments.length} designs',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (isLoadingDatabase)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (databaseError != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _CatalogError(
              message: databaseError.toString(),
              onRetry: _loadDesigns,
            ),
          )
        else if (!isSupabaseConfigured)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _SupabaseRequired(),
          )
        else if (garments.isEmpty && isSupabaseConfigured)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.view_in_ar_outlined,
              title: 'No designs yet',
              message: 'Designs published by ClosetX brands will appear here.',
            ),
          )
        else if (garments.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_rounded,
              title: 'No pieces found',
              message: 'Try another category.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _garmentCard(context, garments[index]),
                childCount: garments.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 20,
                childAspectRatio: 0.60,
              ),
            ),
          ),
      ],
    );
  }

  Widget _garmentCard(BuildContext context, Garment garment) {
    final store = ClosetStoreScope.of(context);
    return GarmentCard(
      garment: garment,
      isSaved: store.isSaved(garment),
      onSave: () => store.toggleSaved(garment),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(garment: garment),
        ),
      ),
    );
  }
}

class _SupabaseRequired extends StatelessWidget {
  const _SupabaseRequired();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 36, color: accent),
            SizedBox(height: 12),
            Text(
              'Connect to your ClosetX database',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No sample products are bundled. Launch with '
              '--dart-define-from-file=supabase.env.json to load published '
              'designs from your Supabase project.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 36, color: accent),
            const SizedBox(height: 12),
            Text('Could not load designs', style: headingStyle(19)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ClosetStoreScope.of(context);
    final garments = store.savedGarments;
    return CustomScrollView(
      key: const PageStorageKey('saved'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR EDIT',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Saved pieces', style: headingStyle(31)),
              ],
            ),
          ),
        ),
        if (garments.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Your edit is waiting',
              message: 'Tap the bookmark on any piece to save it here.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final garment = garments[index];
                return GarmentCard(
                  garment: garment,
                  isSaved: true,
                  onSave: () => store.toggleSaved(garment),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetailScreen(garment: garment),
                    ),
                  ),
                );
              }, childCount: garments.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 20,
                childAspectRatio: 0.60,
              ),
            ),
          ),
      ],
    );
  }
}

class _LocalEditCard extends StatelessWidget {
  const _LocalEditCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 190,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const FashionImage(
              imageUrl:
                  'https://images.unsplash.com/photo-1525507119028-ed4c629a60a3?w=1200&auto=format&fit=crop&q=85',
              background: Color(0xFFD8CDC1),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF201D19).withValues(alpha: 0.75),
                    const Color(0xFF201D19).withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'MADE HERE. WORN EVERYWHERE.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Meet the makers\nbehind the pieces.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onTap,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Our local edit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
