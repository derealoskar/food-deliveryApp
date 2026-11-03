import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class MenuItem {
  final String id, name, category, imageUrl, description;
  final int price; // whole naira
  final int? offerPrice;
  final double rating;
  final bool available, popular, recommended, featured;
  final int order;
  MenuItem(this.id, this.name, this.category, this.imageUrl, this.description, this.price,
      {this.offerPrice, this.rating = 0, this.available = true, this.popular = false, this.recommended = false, this.featured = false, this.order = 9999});
  bool get hasOffer => offerPrice != null && offerPrice! < price;
  int get effectivePrice => hasOffer ? offerPrice! : price;
  factory MenuItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return MenuItem(d.id, m['name'] ?? '', m['category'] ?? '', m['imageUrl'] ?? '', m['description'] ?? '',
        (m['price'] ?? 0 as num).toInt(),
        offerPrice: (m['offerPrice'] as num?)?.toInt(),
        rating: ((m['rating'] ?? 0) as num).toDouble(),
        available: m['available'] ?? true,
        popular: m['popular'] ?? false,
        recommended: m['recommended'] ?? false,
        featured: m['featured'] ?? false,
        order: ((m['order'] ?? 9999) as num).toInt());
  }
}

class Extra {
  final String id, name, group;
  final int price;
  Extra(this.id, this.name, this.group, this.price);
}

class CartLine {
  final MenuItem item;
  final List<Extra> extras;
  int qty;
  CartLine(this.item, this.extras, this.qty);
  String get key => '${item.id}|${(extras.map((e) => e.id).toList()..sort()).join(',')}';
  int get unit => item.effectivePrice + extras.fold(0, (s, e) => s + e.price);
  Map<String, dynamic> toMap() => {'itemId': item.id, 'qty': qty, 'extras': extras.map((e) => e.id).toList()};
}

class Cart extends ChangeNotifier {
  final List<CartLine> lines = [];
  int get count => lines.fold(0, (s, l) => s + l.qty);
  int get total => lines.fold(0, (s, l) => s + l.unit * l.qty);

  /// Quantity of each dish across all its lines (used by food cards).
  Map<String, int> get qty {
    final m = <String, int>{};
    for (final l in lines) {
      m[l.item.id] = (m[l.item.id] ?? 0) + l.qty;
    }
    return m;
  }

  void addLine(MenuItem m, List<Extra> extras, {int qty = 1}) {
    final probe = CartLine(m, extras, qty);
    final i = lines.indexWhere((l) => l.key == probe.key);
    if (i >= 0) {
      lines[i].qty += qty;
    } else {
      lines.add(probe);
    }
    notifyListeners();
  }

  void add(MenuItem m) => addLine(m, const []);
  void remove(MenuItem m) {
    final i = lines.lastIndexWhere((l) => l.item.id == m.id);
    if (i >= 0) changeQty(lines[i], -1);
  }

  void changeQty(CartLine l, int delta) {
    l.qty += delta;
    if (l.qty <= 0) lines.remove(l);
    notifyListeners();
  }

  void clear() {
    lines.clear();
    notifyListeners();
  }
}

class AuthService {
  static final _a = FirebaseAuth.instance;
  static Future<void> register(String name, String email, String pass) async {
    final c = await _a.createUserWithEmailAndPassword(email: email, password: pass);
    await c.user!.updateDisplayName(name);
    await FirebaseFirestore.instance.doc('users/${c.user!.uid}').set(
        {'name': name, 'email': email, 'wallet': 0, 'createdAt': FieldValue.serverTimestamp()});
  }
  static Future<void> login(String email, String pass) =>
      _a.signInWithEmailAndPassword(email: email, password: pass);
  static Future<void> logout() => _a.signOut();
  // Required by Apple (guideline 5.1.1v) for apps with account creation.
  static Future<void> deleteAccount() async {
    final u = _a.currentUser!;
    await FirebaseFirestore.instance.doc('users/${u.uid}').delete();
    await u.delete(); // may throw requires-recent-login: re-authenticate, then retry
  }
}

class Repo {
  static final _db = FirebaseFirestore.instance;
  static String get uid => FirebaseAuth.instance.currentUser!.uid;

  /// All menu items not hidden by the admin (`visible: false`). Unavailable ones are kept so the UI can label them.
  static Stream<List<MenuItem>> menu() => _db.collection('menu').snapshots().map((s) =>
      s.docs.where((d) => d.data()['visible'] != false).map(MenuItem.fromDoc).toList());

  /// Extras (extra meat, plantain, coleslaw, drinks...) from Firestore `extras`.
  /// Extras from the `extras` collection, plus every available Drinks item from `menu` (id "menu:<id>").
  /// If `extras` cannot be read (e.g. Firestore rules), the drinks are still offered.
  static Stream<List<Extra>> extras() async* {
    Future<List<Extra>> drinks() async {
      try {
        final snap = await _db.collection('menu').where('category', isEqualTo: 'Drinks').get();
        return [
          for (final d in snap.docs)
            if (d.data()['available'] != false && d.data()['visible'] != false)
              Extra('menu:${d.id}', (d.data()['name'] ?? '') as String, 'Drinks', ((d.data()['offerPrice'] is num && d.data()['offerPrice'] < d.data()['price'] ? d.data()['offerPrice'] : d.data()['price']) ?? 0 as num).toInt())
        ];
      } catch (_) {
        return [];
      }
    }

    try {
      await for (final s in _db.collection('extras').snapshots()) {
        final docs = s.docs.where((d) => d.data()['available'] != false).toList()
          ..sort((a, b) => ((a.data()['order'] ?? 999) as num).compareTo((b.data()['order'] ?? 999) as num));
        yield [
          for (final d in docs)
            Extra(d.id, (d.data()['name'] ?? '') as String, (d.data()['group'] ?? 'Extras') as String, ((d.data()['price'] ?? 0) as num).toInt()),
          ...await drinks(),
        ];
      }
    } catch (_) {
      yield await drinks();
    }
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> user() => _db.doc('users/$uid').snapshots();

  /// Newest first. Sorted here on the device, so no Firestore composite index is needed.
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> myOrders() => _db
      .collection('orders')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.toList()..sort((a, b) => orderTime(b.data()).compareTo(orderTime(a.data()))));

  static Stream<DocumentSnapshot<Map<String, dynamic>>> order(String id) =>
      _db.doc('orders/$id').snapshots();

  /// Server recomputes prices from Firestore; the client total is never trusted.
  static Future<String> placeOrder(Cart c, String address, {String note = ''}) async {
    final r = await FirebaseFunctions.instance
        .httpsCallable('createOrder')
        .call({'lines': [for (final l in c.lines) l.toMap()], 'address': address, 'note': note});
    return r.data['orderId'] as String;
  }

  /// Server cancels (only while not yet being prepared) and refunds to the wallet.
  static Future<void> cancelOrder(String id) =>
      FirebaseFunctions.instance.httpsCallable('cancelOrder').call({'orderId': id});

  /// Server checks the balance, debits the wallet and marks the order paid.
  static Future<void> payWithWallet(String orderId) =>
      FirebaseFunctions.instance.httpsCallable('payWithWallet').call({'orderId': orderId});

  /// Cloud Function calls Paystack/Flutterwave with the SECRET key and returns a checkout URL.
  static Future<String> payUrl(String orderId) async {
    final r = await FirebaseFunctions.instance.httpsCallable('initPayment').call({'orderId': orderId});
    return r.data['authorizationUrl'] as String;
  }
}

DateTime orderTime(Map<String, dynamic> m) => (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
