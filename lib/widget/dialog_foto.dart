import 'dart:io';
import 'package:aplikasi_galeri_baru/pages/upload_form.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class DialogFoto extends StatefulWidget {
  final Function(File) onImageSelected;
  final Function(String) onImageUploaded;
  final Function(String) onNewPhotoAdded;
  final double size;

  const DialogFoto({
    Key? key,
    required this.onImageSelected,
    required this.onImageUploaded,
    required this.onNewPhotoAdded,
    required this.size,
  }) : super(key: key);

  @override
  State<DialogFoto> createState() => _DialogFotoState();
}

class _DialogFotoState extends State<DialogFoto> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _uploadImage(File imageFile) async {
    try {
      String? firebaseUid = _auth.currentUser?.uid;

      if (firebaseUid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User not authenticated'))
        );
        return;
      }

      var request = http.MultipartRequest(
          'POST',
          Uri.parse('http://10.0.2.2/gallery_api/backend/upload_image.php')
      );

      request.fields['firebase_uid'] = firebaseUid;

      String fileName = 'Image${DateTime.now().millisecondsSinceEpoch}.${imageFile.path.split('.').last}';

      request.files.add(
          await http.MultipartFile.fromPath(
              'image',
              imageFile.path,
              filename: fileName
          )
      );

      var response = await request.send();

      var responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);

      print('Upload Response: $jsonResponse');

      if (jsonResponse['success'] == true) {
        String fullImageUrl = jsonResponse['url'];
        widget.onImageUploaded(fullImageUrl);

        if (widget.onNewPhotoAdded != null) {
          widget.onNewPhotoAdded!(fullImageUrl);
        }

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image uploaded successfully'))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(jsonResponse['message'] ?? 'Upload failed'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e'))
      );
    }
  }

  void _getFromCamera() async {
    XFile? pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      widget.onImageSelected(imageFile);

      if (context.mounted) {
        Navigator.pop(context);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UploadForm(
                imageFile: imageFile,
                onImageUploaded: (String url) {
                  widget.onImageUploaded(url);
                  widget.onNewPhotoAdded(url);
                }
            ),
          ),
        );
      }
    } else {
      Navigator.pop(context);
    }
  }

  void _getFromGallery() async {
    XFile? pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      widget.onImageSelected(imageFile);

      if (context.mounted) {
        Navigator.pop(context);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UploadForm(
                imageFile: imageFile,
                onImageUploaded: (String url) {
                  widget.onImageUploaded(url);
                  widget.onNewPhotoAdded(url);
                }
            ),
          ),
        );
      }
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showFotoBottomSheet(context);
        },
        child: Container(
          width: 45,
          height: 45,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 35,
          ),
        ),
      ),
    );
  }

  void _showFotoBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  children: [
                    Text(
                      'Tambah Foto Baru',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Pilih sumber foto yang ingin kamu tambahkan',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 32),
                    _buildOptionCard(
                      icon: Icons.camera_alt,
                      title: 'Ambil Foto',
                      subtitle: 'Gunakan kamera untuk mengambil foto baru',
                      gradient: [Colors.blue[700]!, Colors.blue[900]!],
                      onTap: _getFromCamera,
                    ),
                    SizedBox(height: 16),
                    _buildOptionCard(
                      icon: Icons.photo_library,
                      title: 'Galeri',
                      subtitle: 'Pilih foto dari galeri kamu',
                      gradient: [Colors.purple[700]!, Colors.purple[900]!],
                      onTap: _getFromGallery,
                    ),
                    SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.8),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}