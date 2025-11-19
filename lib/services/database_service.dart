// lib/services/database_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createUserDocument({
    required User user,
    required String prenom,
    required String nom,
    required int age,
    String? photoUrl,
  }) async {
    final doc = _db.collection('users').doc(user.uid);
    await doc.set({
      'prenom': prenom,
      'nom': nom,
      'age': age,
      'email': user.email,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return _db.collection('users').doc(uid).get();
  }
}
