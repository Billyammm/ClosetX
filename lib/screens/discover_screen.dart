import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/closetx_repository.dart';
import '../models/garment.dart';
import '../state/closet_store.dart';
import '../state/session_store.dart';
import '../supabase/supabase_config.dart';
import '../theme.dart';
import '../widgets/closet_widgets.dart';
import 'account_screens.dart';
import 'closet_screens.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _category = 'All';
  _DesignSort _designSort = _DesignSort.newest;
  final _repository = ClosetXRepository();
  String? _savedOwnerKey;
  RealtimeChannel? _designChangesChannel;
  Timer? _catalogRefreshTimer;

  @override
  void initState() {
    super.initState();
    if (isSupabaseConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadDesigns();
        _subscribeToDesignChanges();
      });
    }
  }

  void _subscribeToDesignChanges() {
    _designChangesChannel = _repository.subscribeToDesignChanges(
      onChange: _scheduleCatalogRefresh,
      onStatus: (status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _scheduleCatalogRefresh();
        } else if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          debugPrint('Design catalog realtime subscription failed: $error');
        }
      },
    );
  }

  void _scheduleCatalogRefresh() {
    _catalogRefreshTimer?.cancel();
    _catalogRefreshTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) unawaited(_loadDesigns());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    final role = session.profile?.role.name ?? 'unknown';
    final ownerKey = '${session.userId ?? 'guest'}:$role';
    if (ownerKey == _savedOwnerKey) return;
    _savedOwnerKey = ownerKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ClosetStoreScope.of(context).replaceSavedIds(const []);
      _loadSavedDesigns();
    });
  }

  Future<void> _loadDesigns() async {
    await ClosetStoreScope.of(
      context,
    ).loadCatalog(_repository.loadPublishedDesigns);
    await _loadSavedDesigns();
  }

  Future<void> _loadSavedDesigns() async {
    final session = SessionScope.of(context);
    await session.ensureProfileLoaded();
    if (!mounted) return;
    if (!session.isShopper || session.userId == null) {
      ClosetStoreScope.of(context).replaceSavedIds(const []);
      return;
    }
    try {
      final ids = await _repository.loadSavedDesignIds(session.userId!);
      if (!mounted) return;
      ClosetStoreScope.of(
        context,
      ).replaceSavedIds(ids.map((id) => 'supabase:$id'));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load saved designs: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    _catalogRefreshTimer?.cancel();
    final channel = _designChangesChannel;
    if (channel != null) {
      unawaited(_repository.removeDesignChangesSubscription(channel));
    }
    super.dispose();
  }

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
    final newestOrder = {
      for (final entry in allGarments.asMap().entries)
        entry.value.id: entry.key,
    };
    int compareByPopularity(Garment first, Garment second) {
      final countComparison = second.saveCount.compareTo(first.saveCount);
      return countComparison != 0
          ? countComparison
          : newestOrder[first.id]!.compareTo(newestOrder[second.id]!);
    }

    final featuredGarments = [...garments]..sort(compareByPopularity);
    final browseGarments = [...garments];
    if (_designSort == _DesignSort.mostSaved) {
      browseGarments.sort(compareByPopularity);
    }

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
                if (SessionScope.of(context).profile?.isDesigner == true)
                  const ApplicationStatusButton(),
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
                  'THE LOCAL DESIGNS',
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
                  child: Text('Most saved designs', style: headingStyle(21)),
                ),
                Text(
                  isLoadingDatabase ? 'Loading...' : 'Popular with shoppers',
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
        else if (!isSupabaseConfigured || allGarments.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.view_in_ar_outlined,
              title: 'No designs available yet',
              message:
                  "We're getting the latest styles ready for you. Check back "
                  'soon for new designs from local creators.',
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
        else ...[
          _designGrid(featuredGarments.take(4).toList()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Browse all designs', style: headingStyle(21)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Newest uploads'),
                        selected: _designSort == _DesignSort.newest,
                        onSelected: (_) =>
                            setState(() => _designSort = _DesignSort.newest),
                      ),
                      ChoiceChip(
                        avatar: const Icon(
                          Icons.favorite_border_rounded,
                          size: 16,
                        ),
                        label: const Text('Most liked'),
                        selected: _designSort == _DesignSort.mostSaved,
                        onSelected: (_) =>
                            setState(() => _designSort = _DesignSort.mostSaved),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _designGrid(browseGarments),
        ],
      ],
    );
  }

  SliverPadding _designGrid(List<Garment> garments) {
    return SliverPadding(
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
    );
  }

  Widget _garmentCard(BuildContext context, Garment garment) {
    final store = ClosetStoreScope.of(context);
    return GarmentCard(
      garment: garment,
      isSaved: store.isSaved(garment),
      onSave: () => toggleSavedGarment(context, garment),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(garment: garment),
        ),
      ),
    );
  }
}

class ApplicationStatusButton extends StatelessWidget {
  const ApplicationStatusButton({super.key});

  Future<void> _showStatus(BuildContext context) async {
    final session = SessionScope.of(context);
    await session.refresh();
    if (!context.mounted) return;
    final profile = session.profile;
    if (profile == null || !profile.isDesigner) return;
    final isAccepted = profile.designerStatus == 'approved';
    final isDeclined = profile.designerStatus == 'rejected';
    if (!isAccepted && !isDeclined) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isAccepted
                  ? Icons.check_circle_outline_rounded
                  : Icons.cancel_outlined,
              color: isAccepted ? accent : Colors.red.shade700,
            ),
            const SizedBox(width: 10),
            Text(isAccepted ? 'Application accepted' : 'Application declined'),
          ],
        ),
        content: Text(
          isAccepted
              ? 'Your designer application was accepted. You can now manage your brand and upload designs.'
              : profile.designerRejectionReason?.trim().isNotEmpty == true
              ? profile.designerRejectionReason!
              : 'Your designer application was not approved at this time.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = SessionScope.of(context).profile;
    final hasDecision =
        profile?.designerStatus == 'approved' ||
        profile?.designerStatus == 'rejected';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Application status',
          onPressed: hasDecision ? () => _showStatus(context) : null,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        if (hasDecision)
          Positioned(
            top: 9,
            right: 9,
            child: IgnorePointer(
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum _DesignSort { newest, mostSaved }

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
                  onSave: () => toggleSavedGarment(context, garment),
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
