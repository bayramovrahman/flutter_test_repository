import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class PhotoUtils {
  // Just empty column

  static Future<File?> compressImage(
      File file, int empId, String cardCode) async {
    try {
      final directory = await getTemporaryDirectory();
      final date = DateTime.now();
      final formattedDate =
          "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
      final randomNumber =
          (10000000 + (DateTime.now().millisecondsSinceEpoch % 90000000))
              .toString();
      final fileName =
          "IMG_${formattedDate}_${empId}_CC_${cardCode}_$randomNumber.jpg";
      final targetPath = path.join(directory.path, fileName);

      final XFile? compressedXFile =
          await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 80,
      );

      return compressedXFile != null ? File(compressedXFile.path) : null;
    } catch (e) {
      throw Exception('Error compressing image: $e');
    }
  }

  static Future<String> getBase64FromFile(File photoFile) async {
    final bytes = await photoFile.readAsBytes();
    return base64Encode(bytes);
  }

  static Future<File?> saveVerificationCustomerPhotoToDevice(
    int userEmpID,
    File photo,
    String mainFolder,
    String folderName,
    String customerCardCode,
    
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final folderPath = '${directory.path}/$mainFolder/$folderName';
      final folder = Directory(folderPath);

      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final fileName = photo.path.split('/').last;
      final savedPhoto = File('${folder.path}/$fileName');
      await photo.copy(savedPhoto.path);

      final photoMeta = {
        'empId': userEmpID,
        'cardCode': customerCardCode,
        'photoName': fileName,
        'photoType': folderName,
      };

      final metaFile = File('${folder.path}/$fileName.json');
      await metaFile.writeAsString(jsonEncode(photoMeta));
      return savedPhoto;
    } catch (e) {
      return null;
    }
  }

  static Future<File?> saveNewCustomerPhotoToDevice(
      File photo, String mainFolder, String folderName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final folderPath = '${directory.path}/$mainFolder/$folderName';
      final folder = Directory(folderPath);

      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final fileName = photo.path.split('/').last;
      final savedPhoto = File('${folder.path}/$fileName');
      await photo.copy(savedPhoto.path);
      return savedPhoto;
    } catch (e) {
      // debugPrint("An error occurred while saving the photo: $e");
      return null;
    }
  }

  static Future<void> deleteVerificationCustomerPhotos(int userEmpID,
      String customerCardCode, String mainFolder, String folderName) async {
    final directory = await getApplicationDocumentsDirectory();
    final folderPath = '${directory.path}/$mainFolder/$folderName';
    final folder = Directory(folderPath);
    if (await folder.exists()) {
      final files = folder.listSync().whereType<File>().toList();
      for (var file in files) {
        if (file.path.endsWith('.json')) {
          // Check only metadata files
          final metaFile = file;
          final metaContent = await metaFile.readAsString();
          final metaData = jsonDecode(metaContent);
          final savedEmpId = metaData['empId'];
          final savedCardCode = metaData['cardCode'];
          final savedPhotoType = metaData['photoType'];
          if (savedEmpId == userEmpID &&
              savedCardCode == customerCardCode &&
              savedPhotoType == folderName) {
            // Delete photo file
            final photoFileName = metaData['photoName'];
            final photoFile = File('${folder.path}/$photoFileName');
            if (await photoFile.exists()) {
              await photoFile.delete();
            }
            await metaFile.delete(); // Delete metadata file
          }
        }
      }

      // If the folder is empty, delete the folder too
      if (folder.listSync().isEmpty) {
        await folder.delete(recursive: true);
      }
    } else {
      // debugPrint("Folder $folderName does not exist.");
      return;
    }
  }

  static Future<void> deleteNewCustomerPhotosFormLocal(
      String mainFolder, String folderName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final folderPath = '${directory.path}/$mainFolder/$folderName';
      final folder = Directory(folderPath);

      if (await folder.exists()) {
        final files = folder.listSync();
        for (var file in files) {
          if (file is File) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      // debugPrint("An error occurred while deleting photos: $e");
      return;
    }
  }

  static String getFileName(File file) {
    return file.path.split('/').last;
  }

  static Future<String> getFileSize(File file) async {
    final bytes = await file.length();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1048576).toStringAsFixed(2)} MB';
  }

  // Just empty column
}
