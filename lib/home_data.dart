import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PromoBanner {
  final String id, imageUrl, title, subtitle, category;
  PromoBanner(this.id, this.imageUrl, this.title, this.subtitle, this.category);
  factory PromoBanner.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return PromoBanner(d.id, m['imageUrl'] ?? '', m['title'] ?? '', m['subtitle'] ?? '', m['category'] ?? '');
  }
}

class FoodCategory {
  final String id, name, imageUrl;
  FoodCategory(this.id, this.name, this.imageUrl);
}

/// Everything the home screen shows comes from Firestore. Nothing is hardcoded.
class HomeRepo {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static Stream<List<PromoBanner>> banners() => _db
      .collection('banners')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((s) => (s.docs.toList()..sort((a, b) => ((a['order'] ?? 0) as num).compareTo((b['order'] ?? 0) as num)))
          .map(PromoBanner.fromDoc)
          .toList());

  static Stream<List<FoodCategory>> categories() => _db.collection('categories').orderBy('order').snapshots().map(
      (s) => s.docs.map((d) => FoodCategory(d.id, d['name'] ?? d.id, d.data()['imageUrl'] ?? '')).toList());

  static Stream<DocumentSnapshot<Map<String, dynamic>>> profile() => _db.doc('users/$_uid').snapshots();
  static Future<void> setAddress(String a) => _db.doc('users/$_uid').set({'address': a}, SetOptions(merge: true));

  static Stream<Set<String>> favoriteIds() =>
      _db.collection('users/$_uid/favorites').snapshots().map((s) => s.docs.map((d) => d.id).toSet());
  static Future<void> setFavorite(String id, bool on) {
    final r = _db.doc('users/$_uid/favorites/$id');
    return on ? r.set({'at': FieldValue.serverTimestamp()}) : r.delete();
  }

  static Stream<int> unreadCount() => _db
      .collection('users/$_uid/notifications')
      .where('read', isEqualTo: false)
      .limit(99)
      .snapshots()
      .map((s) => s.size);

  static Stream<QuerySnapshot<Map<String, dynamic>>> notifications() =>
      _db.collection('users/$_uid/notifications').orderBy('createdAt', descending: true).limit(50).snapshots();

  static Future<void> markAllRead() async {
    final q = await _db.collection('users/$_uid/notifications').where('read', isEqualTo: false).get();
    final b = _db.batch();
    for (final d in q.docs) {
      b.update(d.reference, {'read': true});
    }
    await b.commit();
  }

  /// Item ids from the user's last 5 orders (orders store items: [{itemId, qty, ...}]).
  static Stream<List<String>> recentItemIds() => _db.collection('orders').where('userId', isEqualTo: _uid).snapshots().map((s) {
        final docs = s.docs.toList()
          ..sort((a, b) => ((b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now())
              .compareTo((a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()));
        final ids = <String>[];
        for (final d in docs.take(5)) {
          for (final i in (d.data()['items'] as List? ?? [])) {
            final id = (i as Map)['itemId'] as String?;
            if (id != null && !ids.contains(id)) ids.add(id);
          }
        }
        return ids;
      });
}
