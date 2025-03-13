import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhotoManager {
  static const String _currentUserKey = 'current_user_id';
  static const String _userPhotosPrefix = 'user_photos_';

  static Future<void> setCurrentUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, userId);
  }

  static Future<List<Map<String, dynamic>>> getUserPhotos(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = prefs.getString('$_userPhotosPrefix$userId');
    if (photosJson != null) {
      return List<Map<String, dynamic>>.from(json.decode(photosJson));
    }
    return [];
  }

  static Future<void> saveUserPhotos(String userId, List<Map<String, dynamic>> photos) async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = json.encode(photos);
    await prefs.setString('$_userPhotosPrefix$userId', photosJson);

    final directory = await getApplicationDocumentsDirectory();
    final userPhotoDir = Directory('${directory.path}/photos/$userId');
    if (!await userPhotoDir.exists()) {
      await userPhotoDir.create(recursive: true);
    }

    for (var photo in photos) {
      if (photo['LokasiFile'] != null) {
        final fileName = 'photo${photo['FotoID']}.jpg';
        final file = File('${userPhotoDir.path}/$fileName');

        if (!await file.exists()) {
          try {
            final response = await http.get(Uri.parse(photo['LokasiFile']));
            await file.writeAsBytes(response.bodyBytes);

            photo['LokasiFile'] = file.path;
          } catch (e) {
            print('Error menyimpan foto: $e');
          }
        }
      }
    }

    await prefs.setString('$_userPhotosPrefix$userId', json.encode(photos));
  }

  static Future<void> clearCurrentUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }
}
