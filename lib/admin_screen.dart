import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'components.dart';
import 'theme.dart';

/// True when the document admins/<your user id> exists (you create it once in the Firebase console).
Stream<bool> adminStream() {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return Stream.value(false);
  return FirebaseFirestore.instance.doc('admins/${u.uid}').snapshots().map((d) => d.exists).handleError((_) {});
}

/// Debug helper: tells you your user id and why the Admin button is or is not showing.
Future<String> adminDiagnosis() async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return 'Not logged in';
  try {
    final d = await FirebaseFirestore.instance.doc('admins/${u.uid}').get();
    return d.exists ? 'Admin: YES (user id ${u.uid})' : 'Admin: NO. There is no document admins/${u.uid}. Create it with exactly this id.';
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') return 'Admin: the app is not allowed to read the admins collection. Publish the new rules from firestore.rules.\nUser id: ${u.uid}';
    if (e.code == 'unavailable') return 'Admin: cannot reach Firebase. This is a connection problem, not your rules. Check the internet on this phone or emulator, then open Profile again.\nUser id: ${u.uid}';
    return 'Admin: error ${e.code}.\nUser id: ${u.uid}\n${e.message}';
  } catch (e) {
    return 'Admin: unexpected error.\nUser id: ${u.uid}\n$e';
  }
}

/// Shield button for the app bar. Only admins see it.
class AdminButton extends StatelessWidget {
  const AdminButton({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
        stream: adminStream(),
        builder: (c, a) => a.data == true
            ? IconButton(tooltip: 'Admin', icon: const Icon(Icons.admin_panel_settings_outlined), onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AdminHome())))
            : const SizedBox.shrink(),
      );
}

/// One editable field. type: text | multiline | number | bool | list (one item per line)
class AdminField {
  final String key, label, type;
  final String? hint;
  final bool def; // default for bool fields
  const AdminField(this.key, this.label, {this.type = 'text', this.hint, this.def = false});
}

const _menuFields = [
  AdminField('name', 'Name'),
  AdminField('description', 'Description', type: 'multiline'),
  AdminField('price', 'Price (₦)', type: 'number'),
  AdminField('offerPrice', 'Offer price (₦, optional)', type: 'number'),
  AdminField('category', 'Category', hint: 'Jollof Rice, Fried Rice, Pasta, Drinks...'),
  AdminField('imageUrl', 'Picture link', hint: 'Direct link, e.g. https://i.ibb.co/...'),
  AdminField('rating', 'Rating (0 to 5)', type: 'number'),
  AdminField('available', 'Available to order', type: 'bool', def: true),
  AdminField('visible', 'Show in the app', type: 'bool', def: true),
  AdminField('featured', 'Show in the home Menu row', type: 'bool'),
  AdminField('popular', 'Popular', type: 'bool'),
  AdminField('recommended', 'Recommended', type: 'bool'),
];
const _extraFields = [
  AdminField('name', 'Name', hint: 'Chicken, Fried plantain, Coleslaw...'),
  AdminField('group', 'Group', hint: 'Extra meat or Sides'),
  AdminField('price', 'Price (₦)', type: 'number'),
  AdminField('order', 'Order in the list (1, 2, 3...)', type: 'number'),
  AdminField('available', 'Available', type: 'bool', def: true),
];
const _bannerFields = [
  AdminField('title', 'Title'),
  AdminField('subtitle', 'Subtitle'),
  AdminField('imageUrl', 'Picture link', hint: 'Direct link'),
  AdminField('order', 'Order (1, 2, 3...)', type: 'number'),
  AdminField('active', 'Show it', type: 'bool', def: true),
];
const _categoryFields = [
  AdminField('name', 'Name'),
  AdminField('order', 'Order (1, 2, 3...)', type: 'number'),
  AdminField('imageUrl', 'Picture link (optional)'),
];
const _paymentFields = [
  AdminField('bankName', 'Bank name'),
  AdminField('accountName', 'Account name'),
  AdminField('accountNumber', 'Account number', hint: 'Digits only'),
  AdminField('note', 'Note shown to customers (optional)', type: 'multiline'),
];
const _deliveryFields = [
  AdminField('fee', 'Delivery fee (₦)', type: 'number'),
  AdminField('freeAbove', 'Free delivery above (₦, optional)', type: 'number'),
];
const _supportFields = [
  AdminField('phone', 'Phone number'),
  AdminField('whatsapp', 'WhatsApp number', hint: 'Digits with country code, e.g. 2348012345678'),
  AdminField('email', 'Email'),
  AdminField('privacyUrl', 'Privacy policy link'),
];
const _welcomeFields = [
  AdminField('title', 'Title (leave empty for Bite & Sip)'),
  AdminField('subtitle', 'Line under the title'),
  AdminField('videoUrl', 'Video link (.mp4)', hint: 'Direct link to a short video'),
  AdminField('images', 'Picture links', type: 'list', hint: 'One link per line'),
];

// ======================= Admin home =======================
class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  Widget _tile(BuildContext c, IconData icon, String title, String sub, Widget page) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: AppTheme.brand.withAlpha(30), foregroundColor: AppTheme.brand, child: Icon(icon)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(sub),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      );

  CollectionAdmin _coll(String title, String collection, String titleKey, List<AdminField> f, String Function(Map<String, dynamic>) sub) =>
      CollectionAdmin(title: title, collection: collection, titleKey: titleKey, fields: f, subtitle: sub);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AppTopBar(title: 'Admin', center: true),
        body: ListView(padding: const EdgeInsets.all(Sp.md), children: [
          _tile(context, Icons.restaurant_menu_rounded, 'Menu items', 'Add dishes, prices, pictures, availability',
              _coll('Menu items', 'menu', 'name', _menuFields, (m) => '₦${m['price'] ?? 0} · ${m['category'] ?? ''}${m['available'] == false ? ' · unavailable' : ''}${m['visible'] == false ? ' · hidden' : ''}')),
          _tile(context, Icons.add_circle_outline_rounded, 'Extras', 'Extra meat, plantain, coleslaw',
              _coll('Extras', 'extras', 'name', _extraFields, (m) => '₦${m['price'] ?? 0} · ${m['group'] ?? ''}')),
          _tile(context, Icons.photo_library_outlined, 'Home banners', 'The big pictures on the home page',
              _coll('Home banners', 'banners', 'title', _bannerFields, (m) => '${m['subtitle'] ?? ''}${m['active'] == false ? ' · hidden' : ''}')),
          _tile(context, Icons.category_outlined, 'Categories', 'Food groups',
              _coll('Categories', 'categories', 'name', _categoryFields, (m) => 'Order ${m['order'] ?? '-'}')),
          _tile(context, Icons.movie_creation_outlined, 'Welcome page', 'Video or pictures shown before login',
              const SettingEdit(title: 'Welcome page', path: 'config/welcome', fields: _welcomeFields)),
          _tile(context, Icons.account_balance_rounded, 'Bank account', 'Where customers send transfers',
              const SettingEdit(title: 'Bank account', path: 'config/payment', fields: _paymentFields)),
          _tile(context, Icons.delivery_dining_outlined, 'Delivery fee', 'Fee and free-delivery amount',
              const SettingEdit(title: 'Delivery fee', path: 'config/delivery', fields: _deliveryFields)),
          _tile(context, Icons.support_agent_rounded, 'Support details', 'Phone, WhatsApp, email, privacy link',
              const SettingEdit(title: 'Support details', path: 'config/support', fields: _supportFields)),
        ]),
      );
}

// ======================= A list you can add to, edit and delete from =======================
class CollectionAdmin extends StatelessWidget {
  final String title, collection, titleKey;
  final List<AdminField> fields;
  final String Function(Map<String, dynamic>) subtitle;
  const CollectionAdmin({super.key, required this.title, required this.collection, required this.titleKey, required this.fields, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppTopBar(title: title),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _EditDoc(title: 'New', ref: db.collection(collection).doc(), fields: fields))),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection(collection).snapshots(),
        builder: (_, s) {
          if (s.hasError) return const Center(child: Padding(padding: EdgeInsets.all(Sp.lg), child: Text('Could not load. Make sure your account is set up as an admin and the new rules are published.', textAlign: TextAlign.center)));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final docs = s.data!.docs.toList()..sort((a, b) => '${a.data()[titleKey]}'.toLowerCase().compareTo('${b.data()[titleKey]}'.toLowerCase()));
          if (docs.isEmpty) return const EmptyState(icon: Icons.inbox_outlined, title: 'Nothing here yet', message: 'Tap Add to create the first one.');
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, 88),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i], m = d.data();
              return AppCard(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _EditDoc(title: 'Edit', ref: d.reference, fields: fields))),
                child: ListTile(
                  title: Text('${m[titleKey] ?? '(no name)'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(subtitle(m), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.edit_outlined),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SettingEdit extends StatelessWidget {
  final String title, path;
  final List<AdminField> fields;
  const SettingEdit({super.key, required this.title, required this.path, required this.fields});
  @override
  Widget build(BuildContext context) => _EditDoc(title: title, ref: FirebaseFirestore.instance.doc(path), fields: fields, isSetting: true);
}

// ======================= The edit form =======================
class _EditDoc extends StatefulWidget {
  final String title;
  final DocumentReference<Map<String, dynamic>> ref;
  final List<AdminField> fields;
  final bool isSetting;
  const _EditDoc({required this.title, required this.ref, required this.fields, this.isSetting = false});
  @override
  State<_EditDoc> createState() => _EditDocState();
}

class _EditDocState extends State<_EditDoc> {
  final _c = <String, TextEditingController>{};
  final _b = <String, bool>{};
  bool _loading = true, _exists = false, _busy = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      f.type == 'bool' ? _b[f.key] = f.def : _c[f.key] = TextEditingController();
    }
    widget.ref.get().then((d) {
      final m = d.data() ?? {};
      for (final f in widget.fields) {
        final v = m[f.key];
        if (f.type == 'bool') {
          _b[f.key] = v is bool ? v : f.def;
        } else if (f.type == 'list') {
          _c[f.key]!.text = v is List ? v.join('\n') : (v == null ? '' : '$v');
        } else {
          _c[f.key]!.text = v == null ? '' : '$v';
        }
      }
      if (mounted) setState(() { _exists = d.exists; _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final data = <String, dynamic>{};
    for (final f in widget.fields) {
      if (f.type == 'bool') {
        data[f.key] = _b[f.key];
        continue;
      }
      final t = _c[f.key]!.text.trim();
      if (t.isEmpty) {
        data[f.key] = FieldValue.delete();
      } else if (f.type == 'number') {
        final n = num.tryParse(t.replaceAll(',', ''));
        if (n == null) return toast(context, '${f.label} must be a number');
        data[f.key] = n;
      } else if (f.type == 'list') {
        data[f.key] = [for (final l in t.split('\n')) if (l.trim().isNotEmpty) l.trim()];
      } else {
        data[f.key] = t;
      }
    }
    if (!widget.isSetting && (_c[widget.fields.first.key]!.text.trim().isEmpty)) return toast(context, '${widget.fields.first.label} is required');
    setState(() => _busy = true);
    try {
      await widget.ref.set(data, SetOptions(merge: true));
      if (!mounted) return;
      toast(context, 'Saved');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, 'Could not save. Check that your admin access and the rules are set up.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, title: 'Delete this?', message: 'This cannot be undone.', confirmLabel: 'Delete', destructive: true)) return;
    try {
      await widget.ref.delete();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) toast(context, 'Could not delete.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppTopBar(title: widget.title, actions: [if (_exists && !widget.isSetting) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _delete)]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(Sp.md), children: [
                for (final f in widget.fields)
                  f.type == 'bool'
                      ? SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppTheme.brand,
                          title: Text(f.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                          value: _b[f.key]!,
                          onChanged: (v) => setState(() => _b[f.key] = v),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(bottom: Sp.md),
                          child: TextField(
                            controller: _c[f.key],
                            keyboardType: f.type == 'number' ? TextInputType.number : (f.type == 'text' ? TextInputType.text : TextInputType.multiline),
                            minLines: f.type == 'multiline' || f.type == 'list' ? 3 : 1,
                            maxLines: f.type == 'multiline' || f.type == 'list' ? 6 : 1,
                            decoration: InputDecoration(labelText: f.label, hintText: f.hint),
                          ),
                        ),
                const SizedBox(height: Sp.sm),
                AppButton(label: 'Save', loading: _busy, onPressed: _save),
              ]),
      );
}
