import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// DEV ONLY. Replaces the menu with your own list (old menu items are deleted first, so no duplicates).
/// Photos you already set yourself (non-picsum links) are kept for dishes with the same name.
/// Delete this file (and the button in the You tab) before you publish.
Future<void> seedSampleData() async {
  final db = FirebaseFirestore.instance;
  final b = db.batch();
  String img(String s) => 'https://picsum.photos/seed/$s/600/400'; // placeholder, replace with your own photos

  // 1. Remove the old menu, remembering any photo you already changed
  final keep = <String, String>{};
  for (final d in (await db.collection('menu').get()).docs) {
    final url = (d.data()['imageUrl'] ?? '') as String;
    if (url.isNotEmpty && !url.contains('picsum')) keep[(d.data()['name'] ?? '') as String] = url;
    b.delete(d.reference);
  }

  // 2. Categories (fixed ids, so they never duplicate)
  const cats = ['Beef', 'Chicken', 'Jollof Rice', 'Pasta', 'Fried Rice', 'Drinks'];
  for (var i = 0; i < cats.length; i++) {
    b.set(db.collection('categories').doc(cats[i].toLowerCase().replaceAll(' ', '-')),
        {'name': cats[i], 'order': i, 'imageUrl': ''});
  }

  // 3. Your menu. PRICES ARE PLACEHOLDERS: change `price` in Firestore to your real prices.
  // name, description, price, category, rating, popular, recommended, offerPrice
  final items = <(String, String, int, String, double, bool, bool, int?)>[
    ('Fried Beef', 'Crispy fried beef', 2500, 'Beef', 4.5, true, true, null),
    ('Peppered Rice', 'Spicy peppered rice', 2300, 'Beef', 4.3, false, true, null),
    ('Fried Chicken', 'Golden crispy fried chicken', 3000, 'Chicken', 4.6, true, true, null),
    ('Peppered Chicken', 'Chicken in hot pepper sauce', 3200, 'Chicken', 4.4, false, true, null),
    ('Jollof Rice', 'Smoky party jollof rice', 2000, 'Jollof Rice', 4.7, true, true, null),
    ('Jollof & Chicken', 'Jollof rice with chicken', 3500, 'Jollof Rice', 4.6, true, false, 3000),
    ('Jollof Rice & Beef', 'Jollof rice with beef', 3300, 'Jollof Rice', 4.5, false, true, null),
    ('Spaghetti & Egg', 'Spaghetti with egg', 2200, 'Pasta', 4.2, false, false, null),
    ('Spaghetti & Chicken', 'Spaghetti with chicken', 3200, 'Pasta', 4.4, true, false, null),
    ('Spaghetti & Beef', 'Spaghetti with beef', 3100, 'Pasta', 4.3, false, true, null),
    ('Fried Rice & Chicken', 'Fried rice with chicken', 3500, 'Fried Rice', 4.6, true, true, null),
    ('Fried Rice & Beef', 'Fried rice with beef', 3300, 'Fried Rice', 4.5, false, false, null),
    ('Bottled Water', 'Chilled bottled water', 300, 'Drinks', 4.0, false, false, null),
    ('Chi Exotic', 'Chilled Chi Exotic juice', 900, 'Drinks', 4.4, true, true, null),
    ('Pepsi', 'Chilled Pepsi', 500, 'Drinks', 4.5, true, false, null),
  ];
  for (final i in items) {
    b.set(db.collection('menu').doc(), {
      'name': i.$1, 'description': i.$2, 'price': i.$3, 'category': i.$4, 'rating': i.$5,
      'popular': i.$6, 'recommended': i.$7, if (i.$8 != null) 'offerPrice': i.$8,
      'available': true, 'visible': true, 'imageUrl': keep[i.$1] ?? img(i.$1.replaceAll(RegExp(r'[^A-Za-z]'), '')),
    });
  }

  // 4. Banners and welcome notification, only if you have none yet
  if ((await db.collection('banners').limit(1).get()).docs.isEmpty) {
    b.set(db.collection('banners').doc(), {
      'title': 'Free delivery today', 'subtitle': 'On orders above ₦5,000', 'imageUrl': img('banner1'),
      'category': '', 'active': true, 'order': 1});
  }
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null && (await db.collection('users/$uid/notifications').limit(1).get()).docs.isEmpty) {
    b.set(db.collection('users/$uid/notifications').doc(), {
      'title': 'Welcome!', 'body': 'Thanks for joining us.', 'read': false, 'createdAt': FieldValue.serverTimestamp()});
  }
  if (!(await db.doc('config/payment').get()).exists) {
    // PLACEHOLDER: replace with your real business account in Firestore (config > payment)
    b.set(db.doc('config/payment'), {
      'bankName': 'Your Bank Name', 'accountName': 'Your Business Name', 'accountNumber': '0000000000',
      'note': 'After transferring, tap "I\'ve made the transfer". Your wallet is credited once confirmed.'});
  }
  if (!(await db.doc('config/support').get()).exists) {
    // PLACEHOLDERS: replace in Firestore (config > support). Privacy/terms URLs are required by the app stores.
    b.set(db.doc('config/support'), {
      'phone': '', 'whatsapp': '', 'email': '', 'privacyUrl': '', 'termsUrl': ''});
  }
  await b.commit();
}
