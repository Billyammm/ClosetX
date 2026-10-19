import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/closetx_repository.dart';
import '../models/account.dart';
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
    int compareFeatured(Garment first, Garment second) {
      final firstScore = first.ratingAverage * 20 + first.saveCount;
      final secondScore = second.ratingAverage * 20 + second.saveCount;
      final scoreComparison = secondScore.compareTo(firstScore);
      return scoreComparison != 0
          ? scoreComparison
          : newestOrder[first.id]!.compareTo(newestOrder[second.id]!);
    }

    final featuredGarments = [...garments]..sort(compareFeatured);

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
                  const DesignerNotificationsButton(),
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
                  child: Text('Featured designs', style: headingStyle(21)),
                ),
                Text(
                  isLoadingDatabase ? 'Loading...' : 'Top rated and saved',
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
          _designGrid(featuredGarments.take(5).toList()),
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

class CommunityDesignsScreen extends StatefulWidget {
  const CommunityDesignsScreen({super.key});

  @override
  State<CommunityDesignsScreen> createState() => _CommunityDesignsScreenState();
}

class _CommunityDesignsScreenState extends State<CommunityDesignsScreen> {
  final _searchController = TextEditingController();
  String _category = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() {
    return ClosetStoreScope.of(
      context,
    ).loadCatalog(ClosetXRepository().loadPublishedDesigns);
  }

  @override
  Widget build(BuildContext context) {
    final store = ClosetStoreScope.of(context);
    final designerId = SessionScope.of(context).userId;
    final query = _searchController.text.trim().toLowerCase();
    final otherDesigns = store.garments.where((garment) {
      return garment.designerId != null &&
          garment.designerId != designerId &&
          (_category == 'All' || garment.category == _category) &&
          (query.isEmpty ||
              garment.name.toLowerCase().contains(query) ||
              garment.designer.toLowerCase().contains(query));
    }).toList();
    final categories =
        store.garments
            .where(
              (garment) =>
                  garment.designerId != null &&
                  garment.designerId != designerId,
            )
            .map((garment) => garment.category)
            .toSet()
            .toList()
          ..sort();

    return CustomScrollView(
      key: const PageStorageKey('designer-community'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DESIGNER COMMUNITY',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Explore other designers.', style: headingStyle(27)),
                const SizedBox(height: 7),
                const Text(
                  'Browse published work from the ClosetX designer community and open a design to read its reviews.',
                  style: TextStyle(color: muted, fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: 17),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search designs or designers...',
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
              ],
            ),
          ),
        ),
        if (categories.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 64,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
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
        if (store.isLoadingCatalog)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (store.catalogError != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _CatalogError(
              message: '${store.catalogError}',
              onRetry: _reload,
            ),
          )
        else if (otherDesigns.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.groups_2_outlined,
              title: query.isNotEmpty || _category != 'All'
                  ? 'No matching designs'
                  : 'No community designs yet',
              message: query.isNotEmpty || _category != 'All'
                  ? 'Try another search or category.'
                  : 'Other designers’ published designs will appear here.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final garment = otherDesigns[index];
                return GarmentCard(
                  garment: garment,
                  isSaved: false,
                  onSave: () {},
                  showSaveButton: false,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetailScreen(garment: garment),
                    ),
                  ),
                );
              }, childCount: otherDesigns.length),
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

class DesignerNotificationsButton extends StatefulWidget {
  const DesignerNotificationsButton({super.key});

  @override
  State<DesignerNotificationsButton> createState() =>
      _DesignerNotificationsButtonState();
}

class _DesignerNotificationsButtonState
    extends State<DesignerNotificationsButton> {
  final _repository = ClosetXRepository();
  List<DesignerNotification> _notifications = const [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadNotifications();
      _subscribe();
    });
  }

  void _subscribe() {
    final designerId = SessionScope.of(context).userId;
    if (designerId == null) return;
    _channel = _repository.subscribeToDesignerNotifications(
      designerId: designerId,
      onChange: () => unawaited(_loadNotifications()),
      onStatus: (status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          unawaited(_loadNotifications());
        } else if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          debugPrint('Designer notification subscription failed: $error');
        }
      },
    );
  }

  Future<void> _loadNotifications() async {
    final designerId = SessionScope.of(context).userId;
    if (designerId == null) return;
    try {
      final notifications = await _repository.loadDesignerNotifications(
        designerId,
      );
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } catch (error) {
      if (!mounted) return;
      debugPrint('Could not load designer notifications: $error');
    }
  }

  Future<void> _openNotifications() async {
    final designerId = SessionScope.of(context).userId;
    if (designerId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DesignerNotificationHistory(
        designerId: designerId,
        repository: _repository,
        onChanged: _loadNotifications,
      ),
    );
    if (mounted) await _loadNotifications();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      unawaited(_repository.removeDesignerNotificationsSubscription(channel));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((item) => !item.isRead).length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: _openNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 3,
            right: 1,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DesignerNotificationHistory extends StatefulWidget {
  const _DesignerNotificationHistory({
    required this.designerId,
    required this.repository,
    required this.onChanged,
  });

  final String designerId;
  final ClosetXRepository repository;
  final Future<void> Function() onChanged;

  @override
  State<_DesignerNotificationHistory> createState() =>
      _DesignerNotificationHistoryState();
}

class _DesignerNotificationHistoryState
    extends State<_DesignerNotificationHistory> {
  List<DesignerNotification> _notifications = const [];
  Object? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final notifications = await widget.repository.loadDesignerNotifications(
        widget.designerId,
      );
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(DesignerNotification notification) async {
    if (notification.isRead) return;
    try {
      await widget.repository.markDesignerNotificationRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = [
          for (final item in _notifications)
            if (item.id == notification.id)
              DesignerNotification(
                id: item.id,
                type: item.type,
                status: item.status,
                createdAt: item.createdAt,
                isRead: true,
                rejectionReason: item.rejectionReason,
                designTitle: item.designTitle,
              )
            else
              item,
        ];
      });
      await widget.onChanged();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not mark notification as read: $error'),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final dateText = MaterialLocalizations.of(context).formatMediumDate(local);
    final timeText = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$dateText · $timeText';
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notifications', style: headingStyle(23)),
                        const SizedBox(height: 3),
                        const Text(
                          'Application updates and shopper activity',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined, color: accent),
                            const SizedBox(height: 10),
                            const Text(
                              'Could not load notifications.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _notifications.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 36,
                              color: muted,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No notifications yet',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Application updates and design saves will appear here.',
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        final isSaved = notification.isDesignSaved;
                        final isDesignReview =
                            notification.isDesignReviewDecision;
                        final accepted = notification.isAccepted;
                        return Material(
                          color: notification.isRead
                              ? Colors.white
                              : const Color(0xFFF2F6F2),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _markRead(notification),
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: line),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 21,
                                    backgroundColor: isSaved || accepted
                                        ? sage
                                        : const Color(0xFFFFEEEE),
                                    child: Icon(
                                      isSaved
                                          ? Icons.bookmark_rounded
                                          : accepted
                                          ? Icons.check_rounded
                                          : Icons.close_rounded,
                                      color: isSaved || accepted
                                          ? accent
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isSaved
                                              ? 'A shopper saved your design'
                                              : isDesignReview
                                              ? accepted
                                                    ? 'Your design was approved'
                                                    : 'Your design was declined'
                                              : accepted
                                              ? 'Your designer application was accepted'
                                              : 'Your designer application was declined',
                                          style: TextStyle(
                                            fontWeight: notification.isRead
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                            color: ink,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          isSaved
                                              ? '“${notification.designTitle ?? 'Your design'}” was added to a shopper’s saved designs.'
                                              : isDesignReview
                                              ? accepted
                                                    ? '“${notification.designTitle ?? 'Your design'}” was approved and is now available to shoppers.'
                                                    : '“${notification.designTitle ?? 'Your design'}” was declined. Reason: ${notification.rejectionReason?.trim().isNotEmpty == true ? notification.rejectionReason! : 'No reason was provided.'}'
                                              : accepted
                                              ? 'You can now manage your brand and upload designs.'
                                              : notification.rejectionReason
                                                        ?.trim()
                                                        .isNotEmpty ==
                                                    true
                                              ? notification.rejectionReason!
                                              : 'Your application was not approved at this time.',
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatDate(notification.createdAt),
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!notification.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(
                                        top: 5,
                                        left: 8,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
