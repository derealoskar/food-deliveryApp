import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'components.dart';
import 'services.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';


// ---------- Auth ----------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  final _k = GlobalKey<FormState>();
  final _n = TextEditingController(), _e = TextEditingController(), _p = TextEditingController();
  bool _reg = false, _busy = false;

  Future<void> _go() async {
    if (!_k.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_reg) {
        await AuthService.register(_n.text.trim(), _e.text.trim(), _p.text);
      } else {
        await AuthService.login(_e.text.trim(), _p.text);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) toast(context, e.message ?? 'Authentication failed');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _k,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Bite & Sip', style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 24),
                  if (_reg)
                    TextFormField(
                        controller: _n,
                        decoration: const InputDecoration(labelText: 'Full name'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
                  TextFormField(
                      controller: _e,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email'),
                  TextFormField(
                      controller: _p,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) => (v ?? '').length < 6 ? 'Min 6 characters' : null),
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: _busy ? null : _go,
                      child: Text(_busy ? 'Please wait…' : (_reg ? 'Create account' : 'Log in'))),
                  TextButton(
                      onPressed: () => setState(() => _reg = !_reg),
                      child: Text(_reg ? 'Have an account? Log in' : 'New here? Register')),
                ]),
              ),
            ),
          ),
        ),
      );
}

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

// ---------- Cart + checkout ----------
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _addr = TextEditingController();
  bool _busy = false;

  Future<void> _checkout(Cart cart) async {
    if (_addr.text.trim().length < 5) return toast(context, 'Enter a delivery address');
    setState(() => _busy = true);
    try {
      final id = await Repo.placeOrder(cart, _addr.text.trim());
      final url = await Repo.payUrl(id);
      cart.clear();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackScreen(orderId: id)));
      }
    } catch (_) {
      if (mounted) toast(context, 'Checkout failed. Please try again.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _checkoutWallet(Cart cart) async {
    if (_addr.text.trim().length < 5) return toast(context, 'Enter a delivery address');
    setState(() => _busy = true);
    try {
      final bal = ((await Repo.user().first).data()?['wallet'] ?? 0) as num;
      if (bal < cart.total) {
        if (mounted) toast(context, 'Not enough wallet balance. Add money in the Wallet tab.');
      } else {
        final id = await Repo.placeOrder(cart, _addr.text.trim());
        await Repo.payWithWallet(id);
        cart.clear();
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackScreen(orderId: id)));
      }
    } catch (_) {
      if (mounted) toast(context, 'Payment failed. Please try again.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      body: cart.count == 0
          ? const EmptyState(icon: Icons.shopping_cart_outlined, title: 'Your cart is empty', message: 'Add something tasty from the menu.')
          : Column(children: [
              Expanded(
                child: ListView(children: [
                  for (final e in cart.qty.entries)
                    ListTile(
                      title: Text(cart.items[e.key]!.name),
                      subtitle: Text(naira.format(cart.items[e.key]!.price)),
                      trailing: QuantitySelector(qty: e.value, onAdd: () => cart.add(cart.items[e.key]!), onRemove: () => cart.remove(cart.items[e.key]!)),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  AppTextField(controller: _addr, label: 'Delivery address', icon: Icons.location_on_outlined),
                  AppButton(label: 'Pay ${naira.format(cart.total)} by card', loading: _busy, onPressed: () => _checkout(cart)),
                  const SizedBox(height: Sp.sm),
                  AppButton(label: 'Pay with wallet', secondary: true, icon: Icons.account_balance_wallet_outlined, onPressed: _busy ? null : () => _checkoutWallet(cart)),
                ]),
              ),
            ]),
    );
  }
}
