import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cart_screen.dart' show CartScreen;
import 'components.dart';
import 'home_data.dart';
import 'home_screen.dart' show NotificationsScreen;
import 'services.dart';

/// Notification + cart buttons (with live counters). Drop into any AppBar: actions: [BarActions()]
class BarActions extends StatefulWidget {
  const BarActions({super.key});
  @override
  State<BarActions> createState() => _BarActionsState();
}

class _BarActionsState extends State<BarActions> {
  late final Stream<int> _unread = HomeRepo.unreadCount(); // created once, not on every rebuild

  Widget _btn(BuildContext c, IconData icon, String tip, int n, Widget page) => Padding(
        padding: const EdgeInsets.only(right: Sp.sm),
        child: IconButton.filledTonal(
          tooltip: tip,
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
          style: IconButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.surfaceContainerHigh,
              foregroundColor: Theme.of(c).colorScheme.onSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          icon: Badge(isLabelVisible: n > 0, label: Text(n > 99 ? '99+' : '$n'), child: Icon(icon)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final count = context.select<Cart, int>((c) => c.count);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      StreamBuilder<int>(
        stream: _unread,
        builder: (c, n) => _btn(c, Icons.notifications_none_rounded, 'Notifications', n.data ?? 0, const NotificationsScreen()),
      ),
      _btn(context, Icons.shopping_cart_rounded, 'Cart', count, const CartScreen()),
    ]);
  }
}
