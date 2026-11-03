import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'components.dart';
import 'home_data.dart';
import 'screens.dart' show CartScreen;
import 'services.dart';
import 'theme.dart';

const _grid = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 240, mainAxisExtent: 305, crossAxisSpacing: Sp.md, mainAxisSpacing: Sp.md);

// ================= Top app bar =================
class _HomeBar extends StatelessWidget implements PreferredSizeWidget {
  final int cartCount;
  const _HomeBar({required this.cartCount});
  @override
  Size get preferredSize => const Size.fromHeight(72);

  Future<void> _editAddress(BuildContext context, String current) async {
    final c = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delivery address'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Street, area, city')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && c.text.trim().length >= 5) await HomeRepo.setAddress(c.text.trim());
  }

  Widget _action(BuildContext context, IconData icon, String tip, int n, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: Sp.sm),
        child: IconButton.filledTonal(
          tooltip: tip,
          onPressed: onTap,
          style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          icon: Badge(isLabelVisible: n > 0, label: Text(n > 99 ? '99+' : '$n'), child: Icon(icon)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: HomeRepo.profile(),
      builder: (_, s) {
        final u = s.data?.data() ?? {};
        final authUser = FirebaseAuth.instance.currentUser;
        final name = ((u['name'] ?? authUser?.displayName ?? authUser?.email ?? '') as String).trim();
        final photo = (u['photoUrl'] ?? '') as String;
        final addr = (u['address'] ?? '') as String;
        return AppBar(
          toolbarHeight: 72,
          leadingWidth: 72,
          leading: Padding(
            padding: const EdgeInsets.only(left: Sp.md),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.brand, width: 2)),
              child: CircleAvatar(
                backgroundColor: AppTheme.brand,
                foregroundColor: Colors.white,
                backgroundImage: photo.isEmpty ? null : CachedNetworkImageProvider(photo),
                child: photo.isEmpty
                    ? (name.isEmpty ? const Icon(Icons.person_rounded) : Text(name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)))
                    : null,
              ),
            ),
          ),
          title: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _editAddress(context, addr),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.brand),
                const SizedBox(width: 2),
                Text('Deliver to', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
              ]),
              Row(children: [
                Flexible(
                  child: Text(addr.isEmpty ? 'Set your address' : addr,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ]),
            ]),
          ),
          actions: [
            StreamBuilder<int>(
              stream: HomeRepo.unreadCount(),
              builder: (_, n) => _action(context, Icons.notifications_none_rounded, 'Notifications', n.data ?? 0,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            ),
            _action(context, Icons.shopping_cart_rounded, 'Cart', cartCount,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()))),
            const SizedBox(width: Sp.xs),
          ],
        );
      },
    );
  }
}

// ================= Promo carousel =================
class _BannerCarousel extends StatefulWidget {
  final List<PromoBanner> banners;
  final ValueChanged<PromoBanner> onTap;
  const _BannerCarousel({required this.banners, required this.onTap});
  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _pc = PageController(viewportFraction: .9);
  int _i = 0;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pc.hasClients || widget.banners.length < 2) return;
      _pc.animateToPage((_i + 1) % widget.banners.length, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }
  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      SizedBox(
        height: 190,
        child: PageView.builder(
          controller: _pc,
          itemCount: widget.banners.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) {
            final b = widget.banners[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => widget.onTap(b),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(fit: StackFit.expand, children: [
                    CachedNetworkImage(imageUrl: b.imageUrl, fit: BoxFit.cover, placeholder: (_, __) => const Skeleton(radius: 0),
                        errorWidget: (_, __, ___) => Container(color: cs.primaryContainer)),
                    const DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xF2B71C1C), Color(0x99B71C1C), Color(0x00000000)]))),
                    Positioned(
                      left: 20, right: 110, bottom: 18,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 26, height: 1.1, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                        if (b.subtitle.isNotEmpty) Text(b.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: const Text('Order now', style: TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: Sp.sm),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < widget.banners.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _i ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == _i ? cs.primary : cs.outlineVariant, borderRadius: BorderRadius.circular(3)),
          ),
      ]),
    ]);
  }
}

// ================= Home tab =================
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Stream<List<MenuItem>> _menu = Repo.menu();
  late Stream<List<PromoBanner>> _banners = HomeRepo.banners();
  late Stream<List<FoodCategory>> _cats = HomeRepo.categories();
  final _search = TextEditingController();
  final _favs = ValueNotifier<Set<String>>({});
  String _cat = 'All';
  StreamSubscription? _favSub;

  @override
  void initState() {
    super.initState();
    _favSub = HomeRepo.favoriteIds().listen((v) => _favs.value = v, onError: (_) {});
  }
  @override
  void dispose() {
    _favSub?.cancel();
    _search.dispose();
    _favs.dispose();
    super.dispose();
  }

  void _retry() => setState(() {
        _menu = Repo.menu();
        _banners = HomeRepo.banners();
        _cats = HomeRepo.categories();
      });

  Widget _card(MenuItem m, Cart cart) => ValueListenableBuilder<Set<String>>(
        valueListenable: _favs,
        builder: (_, f, __) => FoodCard(
          item: m,
          qty: cart.qty[m.id] ?? 0,
          favorite: f.contains(m.id),
          onFavorite: () => HomeRepo.setFavorite(m.id, !f.contains(m.id)),
          onAdd: () => cart.add(m),
          onRemove: () => cart.remove(m),
        ),
      );

  void _seeAll(String title, List<MenuItem> items) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Consumer<Cart>(
          builder: (_, cart, __) => Scaffold(
            appBar: AppTopBar(title: title),
            body: GridView.builder(
                padding: const EdgeInsets.all(Sp.md), gridDelegate: _grid, itemCount: items.length, itemBuilder: (_, i) => _card(items[i], cart)),
          ),
        ),
      ));

  Widget _header(String title, {IconData? icon, Color? color, VoidCallback? onSeeAll}) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.lg, Sp.sm, Sp.sm),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, size: 22, color: color), const SizedBox(width: 6)],
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ]),
      );

  Widget _row(String title, List<MenuItem> items, Cart cart, {IconData? icon, Color? color}) {
    if (items.isEmpty) return const SizedBox.shrink(); // hides itself when the backend has nothing for it
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(title, icon: icon, color: color, onSeeAll: items.length > 2 ? () => _seeAll(title, items) : null),
      SizedBox(
        height: 305,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Sp.md),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: Sp.md),
          itemBuilder: (_, i) => SizedBox(width: 190, child: _card(items[i], cart)),
        ),
      ),
    ]);
  }

  Widget _popularGrid(List<MenuItem> items, Cart cart) {
    if (items.isEmpty) return const SizedBox.shrink();
    final top = items.take(4).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header('Popular', icon: Icons.local_fire_department_rounded, color: Colors.deepOrange, onSeeAll: items.length > 4 ? () => _seeAll('Popular', items) : null),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: Sp.md),
        gridDelegate: _grid,
        itemCount: top.length,
        itemBuilder: (_, i) => _card(top[i], cart),
      ),
    ]);
  }

  Widget _categories() => SizedBox(
        height: 100,
        child: StreamBuilder<List<FoodCategory>>(
          stream: _cats,
          builder: (_, s) => ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: Sp.md), children: [
            CategoryCard(label: 'All', icon: Icons.apps_rounded, selected: _cat == 'All', onTap: () => setState(() => _cat = 'All')),
            if (!s.hasData && !s.hasError)
              for (var i = 0; i < 4; i++)
                const Padding(padding: EdgeInsets.only(right: Sp.md), child: Skeleton(width: 62, height: 62, radius: 31)),
            for (final c in s.data ?? <FoodCategory>[])
              CategoryCard(label: c.name, icon: Icons.restaurant_rounded, imageUrl: c.imageUrl, selected: _cat == c.name, onTap: () => setState(() => _cat = c.name)),
          ]),
        ),
      );

  Widget _loading() => ListView(physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.all(Sp.md), children: [
        const Skeleton(height: 56, radius: 16),
        const SizedBox(height: Sp.md),
        const Skeleton(height: 160, radius: 20),
        const SizedBox(height: Sp.lg),
        SizedBox(
          height: 305,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(right: Sp.md), child: SizedBox(width: 190, child: CardSkeleton())),
          ]),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final cs = Theme.of(context).colorScheme;
    final q = _search.text.trim().toLowerCase();
    final filtering = q.isNotEmpty || _cat != 'All';
    final first = (FirebaseAuth.instance.currentUser?.displayName ?? '').split(' ').first;
    return Scaffold(
      appBar: _HomeBar(cartCount: cart.count),
      body: StreamBuilder<List<MenuItem>>(
        stream: _menu,
        builder: (_, s) {
          if (s.hasError) return ErrorState(onRetry: _retry);
          if (!s.hasData) return _loading();
          final all = s.data!;
          final byId = {for (final m in all) m.id: m};
          final results = all
              .where((m) => (_cat == 'All' || m.category == _cat) && (q.isEmpty || m.name.toLowerCase().contains(q) || m.description.toLowerCase().contains(q)))
              .toList();
          return ListView(padding: const EdgeInsets.only(bottom: Sp.lg), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(first.isEmpty ? 'Hungry?' : 'Hi $first,', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                Text('What would you like to eat today?', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: Sp.md),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search for food or drinks',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: q.isEmpty ? null : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close_rounded), onPressed: () => setState(_search.clear)),
                  ),
                ),
              ]),
            ),
            _categories(),
            if (!filtering)
              StreamBuilder<List<PromoBanner>>(
                stream: _banners,
                builder: (_, b) => (b.data ?? []).isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: Sp.md),
                        child: _BannerCarousel(banners: b.data!, onTap: (x) => x.category.isEmpty ? null : setState(() => _cat = x.category)),
                      ),
              ),
            if (filtering) ...[
              _header(_cat == 'All' ? 'Results' : _cat),
              if (results.isEmpty)
                EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matches',
                    message: 'Try a different word or category.',
                    actionLabel: 'Clear filters',
                    onAction: () => setState(() {
                          _search.clear();
                          _cat = 'All';
                        }))
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: Sp.md),
                  gridDelegate: _grid,
                  itemCount: results.length,
                  itemBuilder: (_, i) => _card(results[i], cart),
                ),
            ] else ...[
              StreamBuilder<List<String>>(
                stream: HomeRepo.recentItemIds(),
                builder: (_, r) => _row('Order again', [for (final id in r.data ?? <String>[]) if (byId[id] != null) byId[id]!], cart, icon: Icons.history_rounded, color: cs.primary),
              ),
              _popularGrid(all.where((m) => m.popular).toList(), cart),
              _row('Special offers', all.where((m) => m.hasOffer).toList(), cart, icon: Icons.local_offer_rounded, color: Colors.red),
              _row('Recommended for you', all.where((m) => m.recommended).toList(), cart, icon: Icons.thumb_up_alt_rounded, color: cs.primary),
              _row('Drinks', all.where((m) => m.category == 'Drinks').toList(), cart, icon: Icons.local_drink_rounded, color: Colors.blue),
              if (all.isEmpty) const EmptyState(icon: Icons.restaurant_menu, title: 'Menu coming soon', message: 'Check back in a moment.'),
            ],
          ]);
        },
      ),
    );
  }
}

// ================= Notifications =================
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void dispose() {
    HomeRepo.markAllRead(); // mark read on leaving, so unread items stay highlighted while viewing
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AppTopBar(title: 'Notifications'),
        body: StreamBuilder(
          stream: HomeRepo.notifications(),
          builder: (_, s) {
            if (s.hasError) return ErrorState(onRetry: () => setState(() {}));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final docs = s.data!.docs;
            if (docs.isEmpty) return const EmptyState(icon: Icons.notifications_none, title: 'All caught up', message: 'Order updates and offers will appear here.');
            return ListView.separated(
              padding: const EdgeInsets.all(Sp.md),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: Sp.sm),
              itemBuilder: (_, i) {
                final d = docs[i].data();
                final ts = d['createdAt'];
                return NotificationCard(
                  title: d['title'] ?? '',
                  body: d['body'] ?? '',
                  time: ts == null ? '' : DateFormat('d MMM, h:mm a').format(ts.toDate()),
                  unread: d['read'] != true,
                );
              },
            );
          },
        ),
      );
}
