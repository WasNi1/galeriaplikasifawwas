import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class PhotoUploadService {
  static const String baseUrl = 'http://your-backend-url.com/api';

  static Future<XFile?> pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    return await picker.pickImage(source: ImageSource.gallery);
  }

  static Future<XFile?> captureFromCamera() async {
    final ImagePicker picker = ImagePicker();
    return await picker.pickImage(source: ImageSource.camera);
  }

  static Future<bool> uploadPhoto({
    required XFile imageFile,
    required String userId,
    required String judul,
    required String deskripsi,
  }) async {
    try {
      var uploadRequest = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/upload_photo.php')
      );

      var multipartFile = await http.MultipartFile.fromPath(
          'photo',
          imageFile.path,
          filename: path.basename(imageFile.path)
      );
      uploadRequest.files.add(multipartFile);

      uploadRequest.fields['user_id'] = userId;
      uploadRequest.fields['judul'] = judul;
      uploadRequest.fields['deskripsi'] = deskripsi;

      var response = await uploadRequest.send();

      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        print('Upload berhasil: $responseBody');
        return true;
      } else {
        var responseBody = await response.stream.bytesToString();
        print('Upload gagal: $responseBody');
        return false;
      }
    } catch (e) {
      print('Error saat upload: $e');
      return false;
    }
  }
}