import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services.dart';

final naira = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
void toast(BuildContext c, String m) => ScaffoldMessenger.of(c)
    .showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

/// Spacing scale: use these everywhere for consistent rhythm.
class Sp {
  static const xs = 4.0, sm = 8.0, md = 16.0, lg = 24.0;
}

// ---------- App bar & bottom nav ----------
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final bool center;
  const AppTopBar({super.key, required this.title, this.actions = const [], this.center = false});
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) =>
      AppBar(centerTitle: center, toolbarHeight: 64, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5)), actions: [...actions, const SizedBox(width: Sp.sm)]);
}

class AppNavBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const AppNavBar({super.key, required this.selected, required this.onSelect});
  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Wallet'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      child: Container(
        height: 72,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1B1A),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 28, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: Semantics(
                button: true, selected: i == selected, label: _items[i].$3,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(color: i == selected ? cs.primary : Colors.transparent, borderRadius: BorderRadius.circular(30)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(i == selected ? _items[i].$2 : _items[i].$1, size: 25, color: i == selected ? Colors.white : Colors.white70),
                      const SizedBox(height: 3),
                      Text(_items[i].$3, style: TextStyle(fontSize: 11.5, fontWeight: i == selected ? FontWeight.w800 : FontWeight.w600, color: i == selected ? Colors.white : Colors.white70)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ---------- Basic building blocks ----------
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: onTap == null ? child : InkWell(onTap: onTap, child: child),
      );
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading, secondary;
  final IconData? icon;
  const AppButton({super.key, required this.label, this.onPressed, this.loading = false, this.secondary = false, this.icon});
  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    );
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: loading
          ? const SizedBox(key: ValueKey('l'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(key: const ValueKey('t'), mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
    );
    final tap = loading ? null : onPressed;
    return secondary
        ? OutlinedButton(onPressed: tap, style: style, child: child)
        : FilledButton(onPressed: tap, style: style, child: child);
  }
}

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  const AppTextField({super.key, required this.controller, required this.label, this.icon, this.obscure = false, this.keyboard, this.validator});
  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.md),
        child: TextFormField(
          controller: widget.controller,
          obscureText: _hidden,
          keyboardType: widget.keyboard,
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: widget.icon == null ? null : Icon(widget.icon),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hidden = !_hidden))
                : null,
          ),
        ),
      );
}

class QuantitySelector extends StatelessWidget {
  final int qty;
  final VoidCallback onAdd, onRemove;
  const QuantitySelector({super.key, required this.qty, required this.onAdd, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: 'Remove one', visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove), onPressed: onRemove),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Text('$qty', key: ValueKey(qty), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        IconButton(tooltip: 'Add one', visualDensity: VisualDensity.compact, icon: const Icon(Icons.add), onPressed: onAdd),
      ]),
    );
  }
}

// ---------- Domain components ----------
class FoodCard extends StatelessWidget {
  final MenuItem item;
  final int qty;
  final bool favorite;
  final VoidCallback onAdd, onRemove;
  final VoidCallback? onFavorite, onOpen;
  const FoodCard({super.key, required this.item, required this.qty, required this.onAdd, required this.onRemove, this.favorite = false, this.onFavorite, this.onOpen});

  Widget _pill(String text, {IconData? icon, Color bg = Colors.black54}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) Icon(icon, size: 13, color: Colors.amber),
          if (icon != null) const SizedBox(width: 3),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(
              imageUrl: item.imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 500,
              color: item.available ? null : Colors.black45,
              colorBlendMode: BlendMode.darken,
              fadeInDuration: const Duration(milliseconds: 250),
              placeholder: (_, __) => const ColoredBox(color: Color(0x11000000)),
              errorWidget: (_, __, ___) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.fastfood_outlined, size: 40)),
            ),
            Positioned(
              top: 4, right: 4,
              child: IconButton.filledTonal(
                tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
                visualDensity: VisualDensity.compact,
                icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? Colors.red : null, size: 20),
                onPressed: onFavorite,
              ),
            ),
            if (item.rating > 0) Positioned(left: 8, bottom: 8, child: _pill(item.rating.toStringAsFixed(1), icon: Icons.star_rounded)),
            if (item.hasOffer)
              Positioned(left: 8, top: 8, child: _pill('-${(100 - item.offerPrice! * 100 / item.price).round()}%', bg: Colors.red)),
          ]),
        ))),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.circle, size: 8, color: item.available ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Text(item.available ? 'Available' : 'Unavailable',
                  style: t.labelSmall?.copyWith(color: item.available ? Colors.green : Colors.red, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(naira.format(item.effectivePrice), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    if (item.hasOffer)
                      Text(naira.format(item.price), style: t.labelSmall?.copyWith(decoration: TextDecoration.lineThrough)),
                  ]),
                ),
              ),
              qty == 0 || onOpen != null
                  ? IconButton.filled(
                      tooltip: item.available ? 'Add ${item.name} to cart' : '${item.name} is unavailable',
                      icon: const Icon(Icons.add),
                      onPressed: item.available ? (onOpen ?? onAdd) : null)
                  : QuantitySelector(qty: qty, onAdd: onAdd, onRemove: onRemove),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String imageUrl; // from backend; falls back to icon
  final bool selected;
  final VoidCallback onTap;
  const CategoryCard({super.key, required this.label, required this.icon, this.imageUrl = '', required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? cs.onPrimary : cs.onSurfaceVariant;
    return Semantics(
      button: true, selected: selected, label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(right: Sp.md),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 62, height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? cs.primary : cs.surfaceContainerHigh,
                boxShadow: selected ? [BoxShadow(color: cs.primary.withAlpha(90), blurRadius: 14, offset: const Offset(0, 6))] : null,
              ),
              child: Center(
                child: imageUrl.isEmpty
                    ? Icon(icon, color: fg)
                    : ClipOval(child: CachedNetworkImage(imageUrl: imageUrl, width: 40, height: 40, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(icon, color: fg))),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 68,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? cs.primary : cs.onSurface)),
            ),
          ]),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  static const _m = {
    'pending_payment': ('Awaiting payment', Colors.orange),
    'paid': ('Confirmed', Colors.blue),
    'preparing': ('Preparing', Colors.amber),
    'on_the_way': ('On the way', Colors.purple),
    'delivered': ('Delivered', Colors.green),
    'cancelled': ('Cancelled', Colors.red),
  };
  @override
  Widget build(BuildContext context) {
    final (label, color) = _m[status] ?? (status, Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color.shade700, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class OrderCard extends StatelessWidget {
  final String id, status, summary;
  final double? progress;
  final int total;
  final DateTime? date;
  final VoidCallback onTap;
  const OrderCard({super.key, required this.id, required this.status, required this.total, this.date, this.summary = '', this.progress, required this.onTap});
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Sp.md),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Order #${id.substring(0, id.length < 6 ? id.length : 6).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(date == null ? '' : DateFormat('d MMM, h:mm a').format(date!), style: Theme.of(context).textTheme.bodySmall),
                if (summary.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(height: Sp.sm),
                StatusBadge(status),
                if (progress != null) Padding(padding: const EdgeInsets.only(top: Sp.sm, right: Sp.md), child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 6))),
              ]),
            ),
            Text(naira.format(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Icon(Icons.chevron_right),
          ]),
        ),
      );
}

class NotificationCard extends StatelessWidget {
  final String title, body, time;
  final IconData icon;
  final bool unread;
  const NotificationCard({super.key, required this.title, required this.body, required this.time, this.icon = Icons.notifications_outlined, this.unread = false});
  @override
  Widget build(BuildContext context) => AppCard(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(icon)),
          title: Text(title, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
          subtitle: Text('$body\n$time'),
          isThreeLine: true,
          trailing: unread ? Icon(Icons.circle, size: 10, color: Theme.of(context).colorScheme.primary) : null,
        ),
      );
}

// ---------- Loading / empty / error / confirm ----------
class Skeleton extends StatefulWidget {
  final double? width, height;
  final double radius;
  const Skeleton({super.key, this.width, this.height, this.radius = 12});
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .45, end: 1.0).animate(_c),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(widget.radius)),
        ),
      );
}

class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Skeleton(radius: 0, width: double.infinity)),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skeleton(width: 110, height: 14),
              SizedBox(height: 8),
              Skeleton(width: 70, height: 12),
              SizedBox(height: 14),
              Skeleton(width: 90, height: 24),
            ]),
          ),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: Sp.md),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: Sp.sm),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: Sp.lg),
              SizedBox(width: 200, child: AppButton(label: actionLabel!, onPressed: onAction)),
            ],
          ]),
        ),
      );
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, this.message = 'Something went wrong. Check your connection and try again.', required this.onRetry});
  @override
  Widget build(BuildContext context) => EmptyState(
      icon: Icons.wifi_off_rounded, title: 'Oops!', message: message, actionLabel: 'Retry', onAction: onRetry);
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirmLabel = 'Confirm', bool destructive = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// ["Plantain","Plantain","Coleslaw"] -> "2× Plantain, Coleslaw"
String extrasLabel(Iterable<String> names) {
  final c = <String, int>{};
  for (final n in names) {
    c[n] = (c[n] ?? 0) + 1;
  }
  return c.entries.map((e) => e.value > 1 ? '${e.value}× ${e.key}' : e.key).join(', ');
}
