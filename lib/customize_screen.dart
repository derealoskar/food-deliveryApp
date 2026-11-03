import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'components.dart';
import 'services.dart';
import 'theme.dart';

/// Menu card: dish name on top (first line black, "WITH ..." line red), photo in the middle, red price tag below.
class MenuCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;
  const MenuCard({super.key, required this.item, required this.onTap});

  /// "Jollof & Chicken" -> ("Jollof", "WITH CHICKEN"); a name without "&" / "with" -> (name, description)
  (String, String) _lines() {
    final parts = item.name.split(RegExp(r'\s*(?:&|\bwith\b)\s*', caseSensitive: false));
    if (parts.length >= 2 && parts.first.trim().isNotEmpty) {
      return (parts.first.trim(), 'WITH ${parts.sublist(1).map((p) => p.trim()).where((p) => p.isNotEmpty).join(' & ')}');
    }
    return (item.name, item.description);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (a, b) = _lines();
    final withLine = b.startsWith('WITH ');
    return AppCard(
      onTap: item.available ? onTap : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -0.3, color: cs.onSurface)),
            if (b.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(b.toUpperCase(), maxLines: withLine ? 2 : 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: withLine ? 22 : 12, fontWeight: withLine ? FontWeight.w900 : FontWeight.w700, height: 1.05, letterSpacing: withLine ? -0.3 : 0.4, color: AppTheme.brand)),
              ),
          ]),
        ),
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 500, // decode small: much lighter on memory and faster to scroll
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => const ColoredBox(color: Color(0x11000000)),
                errorWidget: (_, __, ___) => Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.fastfood_outlined, size: 40)),
              ),
              if (!item.available)
                Container(color: Colors.white70, alignment: Alignment.center, child: const Text('UNAVAILABLE', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red))),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.brand, borderRadius: BorderRadius.circular(14)),
            child: Text(naira.format(item.effectivePrice), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
    );
  }
}
