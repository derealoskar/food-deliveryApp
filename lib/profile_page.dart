import 'package:flutter/material.dart';

/// ---------------------------------------------------------------
/// 1) BOTTOM NAVIGATION BAR – labels ALWAYS visible
/// ---------------------------------------------------------------
/// Use this in your main/home scaffold.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // Replace the placeholders with your real pages.
  final _pages = const [
    Center(child: Text('Home')),
    Center(child: Text('Wallet')),
    Center(child: Text('Orders')),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        // This is the key line: labels are shown on every tab, always.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'You',
          ),
        ],
      ),
    );
  }
}

/// If you use the older BottomNavigationBar instead, use this:
///
/// BottomNavigationBar(
///   currentIndex: _index,
///   onTap: (i) => setState(() => _index = i),
///   type: BottomNavigationBarType.fixed,
///   showSelectedLabels: true,
///   showUnselectedLabels: true,
///   items: const [ ... ],
/// )

/// ---------------------------------------------------------------
/// 2) PROFILE PAGE – modern layout
/// ---------------------------------------------------------------
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // TODO: replace with real data from Firebase Auth / Firestore.
  static const _name = 'John Doe';
  static const _email = 'john.doe@email.com';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Profile',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // ---- Header card ----
            const _HeaderCard(name: _name, email: _email),
            const SizedBox(height: 24),

            // ---- Account ----
            const _SectionLabel('Account'),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Edit profile',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.location_on_outlined,
                title: 'Delivery addresses',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.credit_card_rounded,
                title: 'Payment methods',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.favorite_border_rounded,
                title: 'Favorites',
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 24),

            // ---- Preferences ----
            const _SectionLabel('Preferences'),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: 'Dark mode',
                trailing: Switch(value: false, onChanged: (_) {}),
              ),
              _SettingsTile(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: 'English',
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 24),

            // ---- Support & legal ----
            const _SectionLabel('Support'),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & support',
                onTap: () {},
              ),
              // Terms of Service removed – Privacy Policy kept
              // (required by Google Play and the App Store).
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy policy',
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 24),

            // ---- Log out ----
            _LogoutButton(onPressed: () => _confirmLogout(context)),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Version 1.0.0',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to place orders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true) {
      // TODO: await FirebaseAuth.instance.signOut();
      // then navigate to your login page.
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.name, required this.email});
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: scheme.onPrimary.withValues(alpha: 0.2),
            // TODO: use NetworkImage(photoUrl) when the user has a photo.
            child: Text(
              initials,
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.edit_outlined, color: scheme.onPrimary),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 60,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: scheme.primary, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ??
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.logout_rounded, color: scheme.error),
        label: Text(
          'Log out',
          style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
