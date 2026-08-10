import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _db.collection('users').doc(uid);
  }

  Future<void> saveData({
    required String uid,
    required List<AllocationCategory> categories,
    required List<TransactionRecord> history,
  }) async {
    try {
      await _userDoc(uid).set({
        'categories': categories.map((c) => c.toJson()).toList(),
        'history': history.map((r) => r.toJson()).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreService: saveData failed: $e');
    }
  }

  Future<Map<String, dynamic>?> loadData(String uid) async {
    try {
      final doc = await _userDoc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return doc.data();
    } catch (e) {
      debugPrint('FirestoreService: loadData failed: $e');
      return null;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchData(String uid) {
    return _userDoc(uid).snapshots();
  }

  Future<void> deleteAllData(String uid) async {
    try {
      await _userDoc(uid).delete();
    } catch (e) {
      debugPrint('FirestoreService: deleteAllData failed: $e');
    }
  }
}
