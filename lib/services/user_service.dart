import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final CollectionReference users =
      FirebaseFirestore.instance.collection('users');

  Future<void> createUser({
    required String uid,
    required String fullName,
    required int age,
    required String email,
    required String? photoURL,
  }) async {
    await users.doc(uid).set({
      "fullName": fullName,
      "age": age,
      "email": email,
      "photoURL": photoURL,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }
}
