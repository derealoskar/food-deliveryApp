import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'components.dart';
import 'home_data.dart';
import 'home_screen.dart' show NotificationsScreen;
import 'screens.dart' show CartScreen;
import 'services.dart';

/// Notification + cart buttons (with live counters). Drop into any AppBar: actions: [BarActions()]
class BarActions extends StatelessWidget {
  const BarActions({super.key});

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
    final count = context.watch<Cart>().count;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      StreamBuilder<int>(
        stream: HomeRepo.unreadCount(),
        builder: (c, n) => _btn(c, Icons.notifications_none_rounded, 'Notifications', n.data ?? 0, const NotificationsScreen()),
      ),
      _btn(context, Icons.shopping_cart_rounded, 'Cart', count, const CartScreen()),
    ]);
  }
}
