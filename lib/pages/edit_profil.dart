import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfil extends StatefulWidget {
  final Function? onProfileUpdated;

  const EditProfil({
    Key? key,
    this.onProfileUpdated,
  }) : super(key: key);

  @override
  State<EditProfil> createState() => _EditProfilState();
}

class _EditProfilState extends State<EditProfil> {
  final TextEditingController usernameController = TextEditingController();
  File? _imageFile;
  String? _currentPhotoURL;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _checkPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted) {
        _pickImage();
      } else if (await Permission.storage.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan aktifkan permission di pengaturan'),
          ),
        );
        await openAppSettings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission diperlukan untuk memilih gambar'),
          ),
        );
      }
    } else if (Platform.isIOS) {
      if (await Permission.photos.request().isGranted) {
        _pickImage();
      } else if (await Permission.photos.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan aktifkan permission di pengaturan'),
          ),
        );
        await openAppSettings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission diperlukan untuk memilih gambar'),
          ),
        );
      }
    }
  }

  Future<void> _loadCurrentData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        setState(() {
          usernameController.text = userDoc.get('username') ?? '';
          // Prioritaskan base64PhotoURL, lalu photoURL
          _currentPhotoURL = userDoc.get('base64PhotoURL') ??
              userDoc.get('photoURL');
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        print('Picked image path: ${pickedFile.path}');
        print('Image file size: ${await File(pickedFile.path).length()}');
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memilih gambar')),
      );
    }
  }

  Future<String> _imageToBase64(File imageFile) async {
    List<int> imageBytes = await imageFile.readAsBytes();
    String base64Image = base64Encode(imageBytes);
    return base64Image;
  }

  Future<void> _uploadImageAndUpdateProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User tidak terautentikasi');

      String? photoUrl;
      String? base64Photo;

      if (_imageFile != null) {
        // Konversi gambar ke base64 terlebih dahulu
        base64Photo = await _imageToBase64(_imageFile!);

        // Generate nama file unik yang lebih robust
        String fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        try {
          // Buat referensi penyimpanan
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_photos')
              .child(fileName);

          // Upload file dengan metode putFile
          TaskSnapshot uploadTask = await storageRef.putFile(_imageFile!);

          // Dapatkan URL download
          photoUrl = await uploadTask.ref.getDownloadURL();
        } catch (e) {
          print('Firebase Storage Error: $e');
          // Jika gagal upload ke Firebase Storage, tetap lanjutkan dengan base64
          photoUrl = null;
        }
      }

      // Update Firestore
      Map<String, dynamic> updateData = {
        'username': usernameController.text.trim(),
      };

      if (photoUrl != null) {
        updateData['photoURL'] = photoUrl;
        setState(() {
          _currentPhotoURL = photoUrl;
        });
      }

      // Tambahkan base64 photo untuk backup
      if (base64Photo != null) {
        updateData['base64PhotoURL'] = 'data:image/jpeg;base64,$base64Photo';
        setState(() {
          _currentPhotoURL = 'data:image/jpeg;base64,$base64Photo';
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      // Kirim data ke server MySQL
      await _sendUserToServer(
          firebaseUid: user.uid,
          username: usernameController.text.trim(),
          email: user.email ?? '',
          profilePhoto: base64Photo
      );

      if (widget.onProfileUpdated != null) {
        widget.onProfileUpdated!();
      }

      print('Debug: Profile berhasil diupdate');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      print('Debug: Error updating profile: $e');
      String errorMessage = 'Gagal memperbarui profil';

      if (e is FirebaseException) {
        errorMessage = 'Firebase Error: ${e.message}';
      } else if (e is Exception) {
        errorMessage = e.toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

// Tambahkan metode baru untuk mengirim data ke server
  Future<void> _sendUserToServer({
    required String firebaseUid,
    required String username,
    required String email,
    String? profilePhoto,
  }) async {
    final uri = Uri.parse('http://10.0.2.2/gallery_api/backend/sync_user.php');
    try {
      final response = await http.post(uri, body: {
        'firebase_uid': firebaseUid,
        'username': username,
        'email': email,
        'profile_photo': profilePhoto, // Kirim base64 photo
      });

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print("Response from server: $jsonResponse");
      } else {
        print("Failed to sync user. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Error syncing user: $e");
    }
  }

  Widget _buildProfileImage() {
    ImageProvider? imageProvider;

    // Prioritaskan foto yang baru dipilih
    if (_imageFile != null) {
      // Jika ada file baru yang dipilih, gunakan FileImage
      imageProvider = FileImage(_imageFile!);
    }
    // Jika tidak ada file baru, coba gunakan foto yang tersimpan
    else if (_currentPhotoURL != null) {
      try {
        // Cek jika foto adalah base64
        if (_currentPhotoURL!.startsWith('data:image')) {
          String base64Image = _currentPhotoURL!.split(',')[1];
          imageProvider = MemoryImage(base64Decode(base64Image));
        }
        // Cek jika foto adalah URL web
        else if (_currentPhotoURL!.startsWith('http')) {
          imageProvider = NetworkImage(_currentPhotoURL!);
        }
        // Cek jika foto adalah path lokal
        else if (_currentPhotoURL!.startsWith('uploads/')) {
          String fullUrl = 'http://10.0.2.2/gallery_api/backend/${_currentPhotoURL!}';
          imageProvider = NetworkImage(fullUrl);
        }
      } catch (e) {
        print('Error loading profile image: $e');
      }
    }

    return CircleAvatar(
      radius: 75,
      backgroundColor: Colors.grey[300],
      backgroundImage: imageProvider,
      child: (imageProvider == null)
          ? const Icon(Icons.account_circle, size: 150, color: Colors.white)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, false);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF1E1E1E),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Lexend',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1E1E1E),
                const Color(0xFF3028CC).withOpacity(0.1),
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: _checkPermission,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3028CC).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: _buildProfileImage(),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3028CC),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3028CC).withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Username',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Lexend',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: usernameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Lexend',
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[900],
                      hintText: 'Enter your username',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        fontFamily: 'Lexend',
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: const Color(0xFF3028CC),
                          width: 2,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3028CC).withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _uploadImageAndUpdateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3028CC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
