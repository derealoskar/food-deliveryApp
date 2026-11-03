import 'package:flutter/material.dart';
import 'components.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';


// ---------- Shell with bottom nav ----------
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  static const _tabs = [HomeTab(), WalletTab(), OrdersTab(), YouTab()];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _i, children: _tabs),
        bottomNavigationBar: AppNavBar(selected: _i, onSelect: (i) => setState(() => _i = i)),
      );
}
