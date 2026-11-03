import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'components.dart';
import 'seed.dart';
import 'services.dart';
import 'theme.dart';

/// Dish page: everything on one screen. Photo on top, then each extra / drink with its own plus and minus.
class DishScreen extends StatefulWidget {
  final MenuItem item;
  const DishScreen({super.key, required this.item});
  @override
  State<DishScreen> createState() => _DishScreenState();
}

class _DishScreenState extends State<DishScreen> {
  final Map<String, int> _n = {}; // extra id -> how many
  int _qty = 1;
  late final Stream<List<Extra>> _extras = Repo.extras();

  void _change(Extra e, int d) => setState(() {
        final v = (_n[e.id] ?? 0) + d;
        if (v <= 0) {
          _n.remove(e.id);
        } else {
          _n[e.id] = v;
        }
      });

  Widget _stepper(Extra e) {
    final n = _n[e.id] ?? 0;
    Widget btn(IconData i, VoidCallback? f, String tip) => IconButton(
        tooltip: tip, onPressed: f, icon: Icon(i, size: 18), padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36), visualDensity: VisualDensity.compact);
    return Container(
      decoration: BoxDecoration(
          color: n > 0 ? AppTheme.brand.withAlpha(30) : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove_rounded, n > 0 ? () => _change(e, -1) : null, 'Remove one ${e.name}'),
        SizedBox(width: 22, child: Text('$n', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
        btn(Icons.add_rounded, () => _change(e, 1), 'Add one ${e.name}'),
      ]),
    );
  }

  Widget _row(Extra e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          Expanded(child: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text('+${naira.format(e.price)}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 10),
          _stepper(e),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final m = widget.item;
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      body: StreamBuilder<List<Extra>>(
        stream: _extras,
        builder: (_, s) {
          final extras = s.data ?? [];
          final chosen = [for (final e in extras) for (var i = 0; i < (_n[e.id] ?? 0); i++) e];
          final unit = m.effectivePrice + chosen.fold<int>(0, (a, e) => a + e.price);
          final groups = <String, List<Extra>>{};
          for (final e in extras) {
            groups.putIfAbsent(e.group, () => []).add(e);
          }
          const first = ['Extra meat', 'Sides', 'Extras'];
          int rank(String g) => g == 'Drinks' ? 99 : (first.contains(g) ? first.indexOf(g) : 50);
          final names = groups.keys.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
          return Column(children: [
            SizedBox(
              height: (h * 0.17).clamp(110.0, 150.0),
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                  child: CachedNetworkImage(
                    imageUrl: m.imageUrl, fit: BoxFit.cover, memCacheWidth: 900,
                    placeholder: (_, __) => const ColoredBox(color: Color(0x11000000)),
                    errorWidget: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.fastfood_outlined, size: 48)),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context))),
                    ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.xs),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5))),
                  const SizedBox(width: 8),
                  Text(naira.format(m.effectivePrice), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.brand)),
                ]),
                if (m.description.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: Sp.sm),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
                    child: Text(m.description, maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, height: 1.3, color: Theme.of(context).colorScheme.onSurface)),
                  ),
              ]),
            ),
            // scrolls only if there are more extras than the screen can hold
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, 0), children: [
                if (!s.hasData && !s.hasError) for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(top: Sp.sm), child: Skeleton(height: 34, radius: 12)),
                if (s.hasData && extras.where((e) => e.group != 'Drinks').isEmpty && kDebugMode)
                  Padding(
                    padding: const EdgeInsets.only(top: Sp.sm),
                    child: AppButton(label: 'Add sample extras (dev only)', secondary: true, onPressed: () async {
                      try {
                        await seedExtras();
                      } catch (e) {
                        if (context.mounted) toast(context, 'Failed: $e');
                      }
                    }),
                  ),
                for (final g in names) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 0),
                    child: Text(g.toUpperCase(), style: const TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
                  ),
                  for (final e in groups[g]!) _row(e),
                ],
              ]),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Sp.md),
                child: Row(children: [
                  QuantitySelector(qty: _qty, onAdd: () => setState(() => _qty++), onRemove: () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1)),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: AppButton(
                      label: m.available ? 'Add to cart · ${naira.format(unit * _qty)}' : 'Unavailable',
                      onPressed: m.available
                          ? () {
                              context.read<Cart>().addLine(m, chosen, qty: _qty);
                              toast(context, '${m.name} added to cart');
                              Navigator.pop(context);
                            }
                          : null,
                    ),
                  ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
