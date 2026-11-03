import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_screen.dart';
import 'bar_actions.dart';
import 'components.dart';
import 'home_data.dart';
import 'home_screen.dart' show NotificationsScreen;
import 'services.dart';
import 'theme.dart';
import 'wallet_screen.dart' show WalletTab;

Future<Map<String, dynamic>> _support() async =>
    (await FirebaseFirestore.instance.doc('config/support').get()).data() ?? {};
Future<void> _open(BuildContext c, String? url) async {
  if (url == null || url.isEmpty) return toast(c, 'Not available yet');
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

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
                if ((d['privacyUrl'] ?? '') != '') ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy policy'), onTap: () => _open(ctx, d['privacyUrl'])),
              ]),
            );
          },
        ),
      );

  void _openFolder(BuildContext context, String title, List<Widget> Function(BuildContext) items) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.sm),
              child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            ),
            ...items(ctx),
            const SizedBox(height: Sp.sm),
          ]),
        ),
      );

  Widget _sheetTile(BuildContext ctx, IconData icon, String title, VoidCallback action, {String? sub, Color? color}) => ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        subtitle: sub == null || sub.isEmpty ? null : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.pop(ctx);
          action();
        },
      );

  @override
  Widget build(BuildContext context) {
    final au = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: const AppTopBar(title: 'Profile', center: true, actions: [AdminButton(), BarActions()]),
      body: StreamBuilder(
        stream: HomeRepo.profile(),
        builder: (_, s) {
          final u = s.data?.data() ?? {};
          final name = ((u['name'] ?? au?.displayName ?? '') as String).trim();
          final phone = (u['phone'] ?? '') as String;
          final addr = (u['address'] ?? '') as String;
          // Fits on one screen: the options open in a sheet when a folder is tapped.
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.md),
            child: Column(children: [
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(Sp.md),
                  child: Row(children: [
                    CircleAvatar(radius: 28, backgroundColor: AppTheme.brand, foregroundColor: Colors.white,
                        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
                    const SizedBox(width: Sp.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name.isEmpty ? 'Your name' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(au?.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (phone.isNotEmpty) Text(phone),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: Repo.user(),
                builder: (c, w) => _BigTile(
                  icon: Icons.account_balance_wallet_rounded, title: 'Wallet balance', filled: true, height: 150,
                  value: naira.format((w.data?.data()?['wallet'] ?? 0) as num),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletTab())),
                ),
              ),
              const SizedBox(height: 14),
              _FolderTile(Icons.person_outline_rounded, 'Account', () => _openFolder(context, 'Account', (ctx) => [
                    _sheetTile(ctx, Icons.edit_outlined, 'Edit profile', () => showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _EditProfile(name: name, phone: phone))),
                    _sheetTile(ctx, Icons.location_on_outlined, 'Delivery address', () async {
                      final a = await _ask(context, 'Delivery address', initial: addr, hint: 'Street, area, city');
                      if (a != null && a.length >= 5) await HomeRepo.setAddress(a);
                    }, sub: addr.isEmpty ? 'Not set' : addr),
                    _sheetTile(ctx, Icons.notifications_none_rounded, 'Notifications', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
                  ])),
              _FolderTile(Icons.brightness_6_outlined, 'Appearance', () {
                final m = themeMode.value;
                final isDark = m == ThemeMode.dark || (m == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
                _openFolder(context, 'Appearance', (ctx) => [
                      for (final o in const [ThemeMode.light, ThemeMode.dark])
                        ListTile(
                          leading: Icon(o == ThemeMode.light ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                          title: Text(o == ThemeMode.light ? 'Light' : 'Dark', style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: (o == ThemeMode.dark) == isDark ? const Icon(Icons.check_circle, color: AppTheme.brand) : null,
                          onTap: () {
                            themeMode.value = o;
                            Navigator.pop(ctx);
                          },
                        ),
                    ]);
              }),
              _FolderTile(Icons.lock_outline_rounded, 'Security', () => _openFolder(context, 'Security', (ctx) => [
                    _sheetTile(ctx, Icons.lock_reset_rounded, 'Change password', () => _changePassword(context)),
                    // Required by Apple for apps that let people create accounts
                    _sheetTile(ctx, Icons.delete_forever_outlined, 'Delete account', () => _delete(context), color: Colors.red),
                  ])),
              _FolderTile(Icons.support_agent_rounded, 'Support', () => _openFolder(context, 'Support', (ctx) => [
                    _sheetTile(ctx, Icons.headset_mic_outlined, 'Help & support', () => _help(context)),
                  ])),
              StreamBuilder<bool>(
                stream: adminStream(),
                builder: (_, a) => a.data == true
                    ? _FolderTile(Icons.admin_panel_settings_outlined, 'Admin', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminHome())))
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 6),
              AppButton(
                label: 'Log out', secondary: true, icon: Icons.logout_rounded,
                onPressed: () async {
                  if (await confirmDialog(context, title: 'Log out?', message: 'You can log back in anytime.', confirmLabel: 'Log out')) AuthService.logout();
                },
              ),
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(top: Sp.md),
                  child: FutureBuilder<String>(
                    future: adminDiagnosis(),
                    builder: (_, d) => SelectableText(d.data ?? 'Checking admin access...', style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

/// A folder row: tap it to open its options (the arrow points sideways).
class _FolderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _FolderTile(this.icon, this.title, this.onTap);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          onTap: onTap,
          child: ListTile(
            leading: CircleAvatar(backgroundColor: AppTheme.brand.withAlpha(30), foregroundColor: AppTheme.brand, child: Icon(icon)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      );
}

class _BigTile extends StatelessWidget {
  final IconData icon;
  final String title, value;
  final bool filled;
  final double height;
  final VoidCallback onTap;
  const _BigTile({required this.icon, required this.title, required this.value, this.filled = false, this.height = 150, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = filled ? Colors.white : cs.onSurface;
    return Material(
      color: filled ? Colors.transparent : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          height: height,
          padding: const EdgeInsets.all(Sp.md),
          decoration: filled
              ? const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7F1414), AppTheme.brand], begin: Alignment.topLeft, end: Alignment.bottomRight))
              : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: filled ? Colors.white24 : AppTheme.brand.withAlpha(30),
                foregroundColor: filled ? Colors.white : AppTheme.brand,
                child: Icon(icon, size: 22),
              ),
              const Spacer(),
              Icon(Icons.north_east_rounded, size: 18, color: fg.withAlpha(180)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: fg, fontSize: height > 170 ? 40 : (height > 110 ? 32 : 24), fontWeight: FontWeight.w900, letterSpacing: -1))),
              Text(title, style: TextStyle(color: fg.withAlpha(200), fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }
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
