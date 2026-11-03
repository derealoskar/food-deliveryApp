import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class MenuItem {
  final String id, name, category, imageUrl, description;
  final int price; // whole naira
  final int? offerPrice;
  final double rating;
  final bool available, popular, recommended;
  MenuItem(this.id, this.name, this.category, this.imageUrl, this.description, this.price,
      {this.offerPrice, this.rating = 0, this.available = true, this.popular = false, this.recommended = false});
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
        recommended: m['recommended'] ?? false);
  }
}

class Cart extends ChangeNotifier {
  final Map<String, MenuItem> items = {};
  final Map<String, int> qty = {};
  int get count => qty.values.fold(0, (a, b) => a + b);
  int get total => qty.entries.fold(0, (s, e) => s + items[e.key]!.effectivePrice * e.value);
  void add(MenuItem m) {
    items[m.id] = m;
    qty[m.id] = (qty[m.id] ?? 0) + 1;
    notifyListeners();
  }
  void remove(MenuItem m) {
    final q = (qty[m.id] ?? 0) - 1;
    q <= 0 ? qty.remove(m.id) : qty[m.id] = q;
    notifyListeners();
  }
  void clear() {
    qty.clear();
    items.clear();
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
  static Future<String> placeOrder(Cart c, String address) async {
    final r = await FirebaseFunctions.instance
        .httpsCallable('createOrder')
        .call({'items': c.qty, 'address': address});
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
