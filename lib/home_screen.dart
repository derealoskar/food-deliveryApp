import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'components.dart';
import 'home_data.dart';
import 'cart_screen.dart' show CartScreen;
import 'customize_screen.dart' show MenuCard;
import 'dish_screen.dart';
import 'services.dart';
import 'theme.dart';

const _grid = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 240, mainAxisExtent: 305, crossAxisSpacing: Sp.md, mainAxisSpacing: Sp.md);

// ================= Top app bar =================
class _HomeBar extends StatefulWidget implements PreferredSizeWidget {
  const _HomeBar();
  @override
  Size get preferredSize => const Size.fromHeight(72 + 64);
  @override
  State<_HomeBar> createState() => _HomeBarState();
}

class _HomeBarState extends State<_HomeBar> {
  late final _profile = HomeRepo.profile();
  late final _unread = HomeRepo.unreadCount();


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
    final cartCount = context.select<Cart, int>((c) => c.count);
    return StreamBuilder(
      stream: _profile,
      builder: (_, s) {
        final u = s.data?.data() ?? {};
        final authUser = FirebaseAuth.instance.currentUser;
        final name = ((u['name'] ?? authUser?.displayName ?? authUser?.email ?? '') as String).trim();
        final who = ((u['name'] ?? authUser?.displayName ?? '') as String).trim().split(' ').first;
        final photo = (u['photoUrl'] ?? '') as String;
        return AppBar(
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(Sp.md, 2, Sp.md, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(who.isEmpty ? 'Welcome' : 'Welcome, $who', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                Text.rich(
                  const TextSpan(children: [
                    TextSpan(text: 'What are you '),
                    TextSpan(text: 'craving', style: TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w800)),
                    TextSpan(text: ' today?'),
                  ]),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ]),
            ),
          ),
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
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Bite', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                const TextSpan(text: ' & ', style: TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic)),
                const TextSpan(text: 'Sip', style: TextStyle(color: AppTheme.brand)),
              ]),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1, height: 1.05),
            ),
            Text('FOOD & DRINKS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.8, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          actions: [
            StreamBuilder<int>(
              stream: _unread,
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
  final double height;
  const _BannerCarousel({required this.banners, required this.onTap, required this.height});
  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _pc = PageController(viewportFraction: 1);
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
        height: widget.height,
        child: PageView.builder(
          controller: _pc,
          itemCount: widget.banners.length,
          onPageChanged: (i) => _i = i,
          itemBuilder: (_, i) {
            final b = widget.banners[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md),
              child: GestureDetector(
                onTap: () => widget.onTap(b),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(fit: StackFit.expand, children: [
                    CachedNetworkImage(imageUrl: b.imageUrl, fit: BoxFit.cover, memCacheWidth: 900, placeholder: (_, __) => const ColoredBox(color: Color(0x11000000)),
                        errorWidget: (_, __, ___) => Container(color: cs.primaryContainer)),
                    const DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xF2B71C1C), Color(0x99B71C1C), Color(0x00000000)]))),
                    Positioned(
                      left: 22, right: 70, bottom: 24,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 36, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
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
  final _favs = ValueNotifier<Set<String>>({});
  final _menuCtl = ScrollController();
  late final Stream<List<String>> _recent = HomeRepo.recentItemIds();
  StreamSubscription? _favSub;

  @override
  void initState() {
    super.initState();
    _favSub = HomeRepo.favoriteIds().listen((v) => _favs.value = v, onError: (_) {});
  }
  @override
  void dispose() {
    _favSub?.cancel();
    _favs.dispose();
    _menuCtl.dispose();
    super.dispose();
  }

  void _retry() => setState(() {
        _menu = Repo.menu();
        _banners = HomeRepo.banners();
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
          onOpen: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DishScreen(item: m))),
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

  List<MenuItem> _menuDishes(List<MenuItem> all) {
    const cats = ['Jollof Rice', 'Fried Rice', 'Pasta'];
    final protein = RegExp('chicken|beef', caseSensitive: false);
    final l = all.where((m) => m.featured || (cats.contains(m.category) && protein.hasMatch(m.name))).toList();
    const order = ['Jollof Rice|chicken', 'Jollof Rice|beef', 'Fried Rice|beef', 'Fried Rice|chicken', 'Pasta|chicken', 'Pasta|beef'];
    int rank(MenuItem m) {
      final i = order.indexOf('${m.category}|${m.name.toLowerCase().contains('chicken') ? 'chicken' : 'beef'}');
      return i < 0 ? 99 : i;
    }
    l.sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return l;
  }

  Widget _menuRow(List<MenuItem> all, double height) {
    final dishes = _menuDishes(all);
    if (dishes.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.sm),
        child: Row(children: [
          const Expanded(child: Divider(thickness: 2, height: 2, color: AppTheme.brand)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.md),
            child: Text('MENU', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 5)),
          ),
          const Expanded(child: Divider(thickness: 2, height: 2, color: AppTheme.brand)),
        ]),
      ),
      SizedBox(
        height: height,
        child: Stack(children: [
          ListView.separated(
            controller: _menuCtl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Sp.md),
            itemCount: dishes.length,
            separatorBuilder: (_, __) => const SizedBox(width: Sp.md),
            itemBuilder: (_, i) => SizedBox(
              width: (height * 0.75).clamp(168.0, 240.0).toDouble(),
              child: RepaintBoundary(
                child: MenuCard(item: dishes[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DishScreen(item: dishes[i])))),
              ),
            ),
          ),
          Positioned(
            right: 10, top: 0, bottom: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _menuCtl,
                builder: (_, __) {
                  final pos = _menuCtl.hasClients && _menuCtl.position.hasPixels && _menuCtl.position.hasContentDimensions ? _menuCtl.position : null;
                  final more = pos == null || pos.pixels < pos.maxScrollExtent - 8;
                  return AnimatedOpacity(
                    opacity: more ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !more,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _menuCtl.animateTo((_menuCtl.offset + 250).clamp(0.0, _menuCtl.position.maxScrollExtent).toDouble(), duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                          child: const Padding(padding: EdgeInsets.all(14), child: Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

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
    final cart = context.read<Cart>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const _HomeBar(),
      body: LayoutBuilder(builder: (context, box) {
        // Banner and menu share the visible space, so both are fully visible without scrolling.
        final room = box.maxHeight - 44 - 40; // menu title + spacing
        final bannerH = (room * 0.45).clamp(150.0, 340.0).toDouble();
        final menuH = (room - bannerH).clamp(215.0, 330.0).toDouble();
        return StreamBuilder<List<MenuItem>>(
        stream: _menu,
        builder: (_, s) {
          if (s.hasError) return ErrorState(onRetry: _retry);
          if (!s.hasData) return _loading();
          final all = s.data!;
          final byId = {for (final m in all) m.id: m};
          return ListView(physics: const ClampingScrollPhysics(), padding: const EdgeInsets.only(top: Sp.md, bottom: Sp.lg), children: [
            StreamBuilder<List<PromoBanner>>(
                stream: _banners,
                builder: (_, b) => (b.data ?? []).isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: Sp.md),
                        child: _BannerCarousel(banners: b.data!, onTap: (_) {}, height: bannerH),
                      ),
              ),
            _menuRow(all, menuH),
              StreamBuilder<List<String>>(
                stream: _recent,
                builder: (_, r) => _row('Order again', [for (final id in r.data ?? <String>[]) if (byId[id] != null) byId[id]!], cart, icon: Icons.history_rounded, color: cs.primary),
              ),
              if (all.isEmpty) const EmptyState(icon: Icons.restaurant_menu, title: 'Menu coming soon', message: 'Check back in a moment.'),
          ]);
        },
      );
      }),
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
