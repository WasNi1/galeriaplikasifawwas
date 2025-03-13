import 'dart:io';

class PhotoInfo {
  final int id;
  final File? file;
  final String? imageUrl;
  final String date;
  final int likes;
  final String? description;
  final String username;
  final String? userPhotoUrl;

  PhotoInfo({
    required this.id,
    this.file,
    this.imageUrl,
    required this.date,
    this.likes = 0,
    this.description,
    required this.username,
    this.userPhotoUrl,
  });
}
