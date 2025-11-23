import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class StorageService {

  // Convert image file to base64 string (no size limits or resizing)
  Future<String?> imageToBase64(dynamic imageFile) async {
    try {
      Uint8List imageBytes;

      if (kIsWeb && imageFile is Uint8List) {
        imageBytes = imageFile;
      } else if (!kIsWeb && imageFile is File) {
        imageBytes = await imageFile.readAsBytes();
      } else if (imageFile is Uint8List) {
        imageBytes = imageFile;
      } else {
        return null;
      }

      String base64String = base64Encode(imageBytes);
      return base64String;
    } catch (e) {
      print('[v0] Error converting image to base64: $e');
      return null;
    }
  }

  // Convert base64 string back to Uint8List for display
  Uint8List? base64ToImage(String base64String) {
    try {
      return base64Decode(base64String);
    } catch (e) {
      print('[v0] Error converting base64 to image: $e');
      return null;
    }
  }
}
