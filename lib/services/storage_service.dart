// lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  /// Uploads profile image and returns download URL
  Future<String> uploadProfileImage(File file, {required String uid}) async {
    final ext = file.path.split('.').last;
    final filename = 'profiles/$uid/${_uuid.v4()}.$ext';
    final ref = _storage.ref().child(filename);

    final uploadTask = await ref.putFile(file);
    final url = await ref.getDownloadURL();
    return url;
  }
}
