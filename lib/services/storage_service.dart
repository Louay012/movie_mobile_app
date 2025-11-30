import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class StorageServiceException implements Exception {
  final String message;
  
  StorageServiceException(this.message);
  
  @override
  String toString() => message;
}

class StorageService {
  // Firestore document limit is 1MB, but base64 encoding increases size by ~37%
  // So we limit the original image to ~700KB to be safe
  static const int maxImageSizeBytes = 700 * 1024; // 700KB
  static const int maxImageSizeKB = 700;
  static const int maxImageSizeMB = 1; // For display purposes

  // Get image size in KB
  int getImageSizeKB(Uint8List imageBytes) {
    return (imageBytes.length / 1024).round();
  }

  // Get formatted size string - FIXED
  String getFormattedSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(0)} KB'; // Changed from 1 decimal to 0
    } else {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB';
    }
  }

  // Compress image if it's too large
  Future<Uint8List?> compressImage(Uint8List imageBytes, {int quality = 85}) async {
    try {
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw StorageServiceException('Failed to decode image');
      }

      // Resize if too large (max width/height: 800px)
      img.Image resized = image;
      if (image.width > 800 || image.height > 800) {
        resized = img.copyResize(
          image,
          width: image.width > image.height ? 800 : null,
          height: image.height > image.width ? 800 : null,
        );
      }

      // Encode as JPEG with compression
      final compressed = img.encodeJpg(resized, quality: quality);
      return Uint8List.fromList(compressed);
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  // Validate and convert image to base64
  Future<String?> imageToBase64(dynamic imageFile, {bool autoCompress = true}) async {
    try {
      Uint8List imageBytes;

      // Get image bytes based on platform
      if (kIsWeb && imageFile is Uint8List) {
        imageBytes = imageFile;
      } else if (!kIsWeb && imageFile is File) {
        imageBytes = await imageFile.readAsBytes();
      } else if (imageFile is Uint8List) {
        imageBytes = imageFile;
      } else {
        throw StorageServiceException('Invalid image file type');
      }

      // Check original size
      final originalSizeKB = getImageSizeKB(imageBytes);
      print('Original image size: ${getFormattedSize(imageBytes.length)}');

      // If image is too large, try to compress it
      if (imageBytes.length > maxImageSizeBytes) {
        if (!autoCompress) {
          throw StorageServiceException(
            'Image is too large (${getFormattedSize(imageBytes.length)}). '
            'Please select an image smaller than ${maxImageSizeKB}KB.'
          );
        }

        print('Image too large, attempting compression...');
        
        // Try compression with decreasing quality
        for (int quality in [85, 70, 60, 50]) {
          final compressed = await compressImage(imageBytes, quality: quality);
          if (compressed == null) continue;

          if (compressed.length <= maxImageSizeBytes) {
            imageBytes = compressed;
            print('Compressed to: ${getFormattedSize(imageBytes.length)} (quality: $quality)');
            break;
          }
        }

        // If still too large after compression
        if (imageBytes.length > maxImageSizeBytes) {
          throw StorageServiceException(
            'Image is too large (${getFormattedSize(imageBytes.length)}). '
            'Even after compression, the image exceeds the ${maxImageSizeKB}KB limit. '
            'Please choose a smaller image or reduce its resolution.'
          );
        }
      }

      // Convert to base64
      String base64String = base64Encode(imageBytes);
      
      // Double-check base64 size (base64 is ~37% larger)
      final base64SizeKB = (base64String.length / 1024).round();
      print('Base64 size: ${base64SizeKB}KB');

      if (base64String.length > 1048487) { // Firestore limit
        throw StorageServiceException(
          'Processed image is too large for storage. Please use a smaller image.'
        );
      }

      return base64String;
    } on StorageServiceException {
      rethrow;
    } catch (e) {
      print('Error converting image to base64: $e');
      throw StorageServiceException('Failed to process image: ${e.toString()}');
    }
  }

  // Validate image before processing
  Future<bool> validateImageSize(dynamic imageFile) async {
    try {
      Uint8List imageBytes;

      if (kIsWeb && imageFile is Uint8List) {
        imageBytes = imageFile;
      } else if (!kIsWeb && imageFile is File) {
        imageBytes = await imageFile.readAsBytes();
      } else if (imageFile is Uint8List) {
        imageBytes = imageFile;
      } else {
        return false;
      }

      return imageBytes.length <= maxImageSizeBytes;
    } catch (e) {
      print('Error validating image size: $e');
      return false;
    }
  }

  // Get image info without full processing
  Future<Map<String, dynamic>> getImageInfo(dynamic imageFile) async {
    try {
      Uint8List imageBytes;

      if (kIsWeb && imageFile is Uint8List) {
        imageBytes = imageFile;
      } else if (!kIsWeb && imageFile is File) {
        imageBytes = await imageFile.readAsBytes();
      } else if (imageFile is Uint8List) {
        imageBytes = imageFile;
      } else {
        return {'error': 'Invalid file type'};
      }

      final sizeBytes = imageBytes.length;
      final sizeKB = (sizeBytes / 1024).round();
      final sizeMB = (sizeBytes / (1024 * 1024));
      final isValid = sizeBytes <= maxImageSizeBytes;

      // Try to decode image to get dimensions
      try {
        final image = img.decodeImage(imageBytes);
        if (image != null) {
          return {
            'sizeBytes': sizeBytes,
            'sizeKB': sizeKB,
            'sizeMB': sizeMB,
            'formattedSize': getFormattedSize(sizeBytes),
            'width': image.width,
            'height': image.height,
            'isValid': isValid,
            'maxSizeKB': maxImageSizeKB,
          };
        }
      } catch (e) {
        // If can't decode, just return size info
      }

      return {
        'sizeBytes': sizeBytes,
        'sizeKB': sizeKB,
        'sizeMB': sizeMB,
        'formattedSize': getFormattedSize(sizeBytes),
        'isValid': isValid,
        'maxSizeKB': maxImageSizeKB,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Convert base64 string back to Uint8List for display
  Uint8List? base64ToImage(String base64String) {
    try {
      return base64Decode(base64String);
    } catch (e) {
      print('Error converting base64 to image: $e');
      return null;
    }
  }
}