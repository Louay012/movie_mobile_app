import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // kIsWeb

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Mobile upload
  Future<String> uploadProfileImage(String uid, File file) async {
    final ref = _storage.ref().child('profile_images/$uid.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  // Web upload
  Future<String> uploadProfileImageWeb(String uid, Uint8List bytes) async {
    final ref = _storage.ref().child('profile_images/$uid.jpg');
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }
}
