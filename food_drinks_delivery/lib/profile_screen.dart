import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'bar_actions.dart';
import 'components.dart';
import 'home_data.dart';
import 'home_screen.dart' show NotificationsScreen;
import 'seed.dart';
import 'services.dart';
import 'theme.dart';

Future<Map<String, dynamic>> _support() async =>
    (await FirebaseFirestore.instance.doc('config/support').get()).data() ?? {};
Future<void> _open(BuildContext c, String? url) async {
  if (url == null || url.isEmpty) return toast(c, 'Not available yet');
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Sp.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title.isNotEmpty)
            Padding(padding: const EdgeInsets.only(left: Sp.sm, bottom: Sp.sm), child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800))),
          AppCard(child: Column(children: children)),
        ]),
      );
}

Widget _tile(IconData icon, String title, VoidCallback onTap, {String? sub, Color? color}) => ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      subtitle: sub == null || sub.isEmpty ? null : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );

class YouTab extends StatelessWidget {
  const YouTab({super.key});

  Future<String?> _ask(BuildContext c, String title, {bool secret = false, String initial = '', String hint = ''}) {
    final ctl = TextEditingController(text: initial);
    return showDialog<String>(
      context: c,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctl, obscureText: secret, autofocus: true, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, ctl.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext c) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    if (!await confirmDialog(c, title: 'Change password?', message: 'We will email a reset link to $email.', confirmLabel: 'Send link')) return;
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    if (c.mounted) toast(c, 'Reset link sent. Check your email.');
  }

  Future<void> _delete(BuildContext c) async {
    if (!await confirmDialog(c, title: 'Delete account?', message: 'This permanently deletes your account, wallet balance and order history.', confirmLabel: 'Delete', destructive: true)) return;
    if (!c.mounted) return;
    final pw = await _ask(c, 'Enter your password to confirm', secret: true);
    if (pw == null || pw.isEmpty) return;
    try {
      final u = FirebaseAuth.instance.currentUser!;
      await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: pw));
      await AuthService.deleteAccount();
    } on FirebaseAuthException {
      if (c.mounted) toast(c, 'Wrong password. Your account was not deleted.');
    }
  }

  void _help(BuildContext c) => showModalBottomSheet(
        context: c,
        builder: (_) => FutureBuilder<Map<String, dynamic>>(
          future: _support(),
          builder: (ctx, s) {
            final d = s.data ?? {};
            return SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const ListTile(title: Text('Help & support', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                if (!s.hasData) const Padding(padding: EdgeInsets.all(Sp.lg), child: CircularProgressIndicator()),
                if (s.hasData && d.isEmpty) const Padding(padding: EdgeInsets.all(Sp.lg), child: Text('Support details are not available yet.')),
                if ((d['phone'] ?? '') != '') ListTile(leading: const Icon(Icons.call_outlined), title: const Text('Call us'), subtitle: Text(d['phone']), onTap: () => _open(ctx, 'tel:${d['phone']}')),
                if ((d['whatsapp'] ?? '') != '') ListTile(leading: const Icon(Icons.chat_outlined), title: const Text('WhatsApp'), onTap: () => _open(ctx, 'https://wa.me/${d['whatsapp']}')),
                if ((d['email'] ?? '') != '') ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email us'), subtitle: Text(d['email']), onTap: () => _open(ctx, 'mailto:${d['email']}')),
              ]),
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final au = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: const AppTopBar(title: 'Profile', actions: [BarActions()]),
      body: StreamBuilder(
        stream: HomeRepo.profile(),
        builder: (_, s) {
          final u = s.data?.data() ?? {};
          final name = ((u['name'] ?? au?.displayName ?? '') as String).trim();
          final phone = (u['phone'] ?? '') as String;
          final addr = (u['address'] ?? '') as String;
          return ListView(padding: const EdgeInsets.all(Sp.md), children: [
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(Sp.md),
                child: Row(children: [
                  CircleAvatar(radius: 32, backgroundColor: AppTheme.brand, foregroundColor: Colors.white,
                      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name.isEmpty ? 'Your name' : name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(au?.email ?? ''),
                      if (phone.isNotEmpty) Text(phone),
                    ]),
                  ),
                  IconButton(tooltip: 'Edit profile', icon: const Icon(Icons.edit_outlined),
                      onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _EditProfile(name: name, phone: phone))),
                ]),
              ),
            ),
            const _Stats(),
            _Section('Account', [
              _tile(Icons.location_on_outlined, 'Delivery address', () async {
                final a = await _ask(context, 'Delivery address', initial: addr, hint: 'Street, area, city');
                if (a != null && a.length >= 5) await HomeRepo.setAddress(a);
              }, sub: addr.isEmpty ? 'Not set' : addr),
              _tile(Icons.favorite_border_rounded, 'Favorites', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()))),
              _tile(Icons.notifications_none_rounded, 'Notifications', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            ]),
            _Section('Appearance', [
              Padding(
                padding: const EdgeInsets.all(Sp.md),
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeMode,
                  builder: (_, m, __) => SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text('System')),
                        ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                        ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                      ],
                      selected: {m},
                      onSelectionChanged: (v) => themeMode.value = v.first,
                    ),
                  ),
                ),
              ),
            ]),
            _Section('Security', [_tile(Icons.lock_reset_rounded, 'Change password', () => _changePassword(context))]),
            _Section('Support & legal', [
              _tile(Icons.headset_mic_outlined, 'Help & support', () => _help(context)),
              _tile(Icons.privacy_tip_outlined, 'Privacy policy', () async => _open(context, (await _support())['privacyUrl'])),
            ]),
            _Section('', [
              if (kDebugMode)
                _tile(Icons.data_object, 'Load sample data (dev only)', () async {
                  try {
                    await seedSampleData();
                    if (context.mounted) toast(context, 'Sample data added. Go to Home.');
                  } catch (e) {
                    if (context.mounted) toast(context, 'Failed: $e');
                  }
                }),
              _tile(Icons.logout_rounded, 'Log out', () async {
                if (await confirmDialog(context, title: 'Log out?', message: 'You can log back in anytime.', confirmLabel: 'Log out')) AuthService.logout();
              }),
              _tile(Icons.delete_forever_outlined, 'Delete account', () => _delete(context), color: Colors.red),
            ]),
            const Padding(padding: EdgeInsets.all(Sp.lg), child: Center(child: Text('Version 1.0.0'))),
          ]);
        },
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats();
  Widget _box(BuildContext c, IconData icon, String value, String label) => Expanded(
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.md),
            child: Column(children: [
              Icon(icon, color: AppTheme.brand),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text(label, style: Theme.of(c).textTheme.labelSmall),
            ]),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Sp.md),
        child: Row(children: [
          StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: Repo.myOrders(), builder: (c, s) => _box(c, Icons.receipt_long_outlined, '${s.data?.length ?? 0}', 'Orders')),
          const SizedBox(width: Sp.sm),
          StreamBuilder<Set<String>>(
              stream: HomeRepo.favoriteIds(), builder: (c, s) => _box(c, Icons.favorite_border_rounded, '${s.data?.length ?? 0}', 'Favorites')),
          const SizedBox(width: Sp.sm),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: Repo.user(),
              builder: (c, s) => _box(c, Icons.account_balance_wallet_outlined, naira.format(((s.data?.data()?['wallet'] ?? 0) as num)), 'Wallet')),
        ]),
      );
}

class _EditProfile extends StatefulWidget {
  final String name, phone;
  const _EditProfile({required this.name, required this.phone});
  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late final _n = TextEditingController(text: widget.name), _p = TextEditingController(text: widget.phone);
  bool _busy = false;
  Future<void> _save() async {
    if (_n.text.trim().isEmpty) return toast(context, 'Enter your name');
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(_n.text.trim());
      await FirebaseFirestore.instance.doc('users/${Repo.uid}').set({'name': _n.text.trim(), 'phone': _p.text.trim()}, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Try again.');
    }
    if (mounted) setState(() => _busy = false);
  }
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, MediaQuery.of(context).viewInsets.bottom + Sp.md),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Edit profile', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: Sp.md),
            AppTextField(controller: _n, label: 'Full name', icon: Icons.person_outline),
            AppTextField(controller: _p, label: 'Phone number', icon: Icons.phone_outlined, keyboard: TextInputType.phone),
            AppButton(label: 'Save', loading: _busy, onPressed: _save),
          ]),
        ),
      );
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AppTopBar(title: 'Favorites'),
        body: StreamBuilder<Set<String>>(
          stream: HomeRepo.favoriteIds(),
          builder: (_, f) => StreamBuilder<List<MenuItem>>(
            stream: Repo.menu(),
            builder: (_, m) {
              if (f.hasError || m.hasError) return const Center(child: Text('Could not load favorites'));
              if (!f.hasData || !m.hasData) return const Center(child: CircularProgressIndicator());
              final items = m.data!.where((x) => f.data!.contains(x.id)).toList();
              if (items.isEmpty) return const EmptyState(icon: Icons.favorite_border_rounded, title: 'No favorites yet', message: 'Tap the heart on any dish to save it here.');
              return Consumer<Cart>(
                builder: (_, cart, __) => GridView.builder(
                  padding: const EdgeInsets.all(Sp.md),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisExtent: 305, crossAxisSpacing: Sp.md, mainAxisSpacing: Sp.md),
                  itemCount: items.length,
                  itemBuilder: (_, i) => FoodCard(
                    item: items[i],
                    qty: cart.qty[items[i].id] ?? 0,
                    favorite: true,
                    onFavorite: () => HomeRepo.setFavorite(items[i].id, false),
                    onAdd: () => cart.add(items[i]),
                    onRemove: () => cart.remove(items[i]),
                  ),
                ),
              );
            },
          ),
        ),
      );
}
