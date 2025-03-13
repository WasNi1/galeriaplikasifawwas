import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageHandler {
  static const String _photosKey = 'cached_photos';
  static const String _userIdKey = 'last_user_id';

  // Menyimpan data foto ke penyimpanan lokal
  static Future<void> cachePhotos(List<Map<String, dynamic>> photos, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = json.encode(photos);
    await prefs.setString('${_photosKey}_$userId', photosJson);
    await prefs.setString(_userIdKey, userId);
  }

  // Mengambil data foto dari penyimpanan lokal
  static Future<List<Map<String, dynamic>>> getCachedPhotos(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = prefs.getString('${_photosKey}_$userId');

    if (photosJson != null) {
      final List<dynamic> decoded = json.decode(photosJson);
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // Menyimpan foto ke penyimpanan lokal
  static Future<String> saveImageLocally(String imageUrl, String userId, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final folderPath = '${directory.path}/cached_images/$userId';
      await Directory(folderPath).create(recursive: true);

      final localPath = '$folderPath/$fileName';
      final response = await http.get(Uri.parse(imageUrl));
      final file = File(localPath);
      await file.writeAsBytes(response.bodyBytes);

      return localPath;
    } catch (e) {
      print('Error menyimpan gambar: $e');
      return imageUrl; // Kembalikan URL asli jika gagal
    }
  }

  // Menghapus cache untuk user tertentu
  static Future<void> clearUserCache(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_photosKey}_$userId');
  }
}