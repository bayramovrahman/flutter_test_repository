import 'dart:io';
import 'package:flutter/foundation.dart';

/// Deletes cached images after successful upload
Future<void> deleteCachedImages(List<String> imagePaths) async {
  for (String imagePath in imagePaths) {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Successfully deleted: $imagePath');
      } else {
        debugPrint('File not found: $imagePath');
      }
    } catch (e) {
      debugPrint('Error deleting file $imagePath: $e');
    }
  }
}

/// Deletes a single cached image
Future<void> deleteCachedImage(String imagePath) async {
  try {
    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
      debugPrint('Successfully deleted: $imagePath');
    }
  } catch (e) {
    debugPrint('Error deleting file $imagePath: $e');
  }
}
