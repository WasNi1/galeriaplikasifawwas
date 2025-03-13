import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:aplikasi_galeri_baru/foto_screen/detail_foto_profil_screen.dart';
import 'package:aplikasi_galeri_baru/pages/edit_profil.dart';
import 'package:aplikasi_galeri_baru/pages/login.dart';
import 'package:aplikasi_galeri_baru/services/authentication.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountPages extends StatefulWidget {
  final Function? onProfileUpdated;

  const AccountPages({
    Key? key,
    this.onProfileUpdated,
  }) : super(key: key);

  @override
  State<AccountPages> createState() => _AccountPagesScreenState();
}

class _AccountPagesScreenState extends State<AccountPages> {
  String username = '';
  String? profilePhotoUrl;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isObscure = true;
  Future<void>? _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _getUserData();
  }

  Future<void> syncUserToDatabase({
    required String firebaseUid,
    required String email,
    required String username,
    String? profilePhoto,
  }) async {
    final uri = Uri.parse('http://10.0.2.2/gallery_api/backend/sync_user.php');
    try {
      final response = await http.post(uri, body: {
        'firebase_uid': firebaseUid,
        'username': username,
        'email': email,
        'profile_photo': profilePhoto,
      });

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success') {
          print("User synced successfully: ${jsonResponse['message']}");
        } else {
          print("Error syncing user: ${jsonResponse['message']}");
        }
      } else {
        print("Failed to sync user. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing user: $e");
    }
  }


  Future<void> sendUserToServer(String firebaseUid, String username, String email) async {
    final uri = Uri.parse('http://10.0.2.2/gallery_api/backend/sync_user.php');
    try {
      final response = await http.post(uri, body: {
        'firebase_uid': firebaseUid,
        'username': username,
        'email': email,
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

  Future<void> _refreshWithCallback() async {
    await _refreshData();
    if (widget.onProfileUpdated != null) {
      widget.onProfileUpdated!();
    }
  }

  Future<void> _refreshData() {
    setState(() {
      _userDataFuture = _getUserData();
    });
    return _userDataFuture!;
  }

  Future<void> _getUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          emailController.text = user.email ?? '';
        });

        String uid = user.uid;

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          setState(() {
            username = userData['username'] ?? user.displayName ?? 'User';
            // Coba ambil foto dari base64PhotoURL atau photoURL
            profilePhotoUrl = userData['base64PhotoURL'] ?? userData['photoURL'];
          });
        } else {
          setState(() {
            username = user.displayName ?? 'User';
          });
        }
        await sendUserToServer((uid), username, user.email ?? '');
      }
    } catch (e) {
      print('Error getting user data: $e');

      print('Error details: ${e.toString()}');

      setState(() {
        username = 'User';
        emailController.text = '';
      });
    }
  }

  Widget _buildProfilePhoto() {
    ImageProvider? imageProvider;

    if (profilePhotoUrl != null) {
      try {
        if (profilePhotoUrl!.startsWith('data:image')) {
          String base64Image = profilePhotoUrl!.split(',')[1];
          imageProvider = MemoryImage(base64Decode(base64Image));
        }
        else if (profilePhotoUrl!.startsWith('http')) {
          imageProvider = NetworkImage(profilePhotoUrl!);
        }
        else if (profilePhotoUrl!.startsWith('uploads/')) {
          String fullUrl = 'http://10.0.2.2/gallery_api/backend/${profilePhotoUrl!}';
          imageProvider = NetworkImage(fullUrl);
        }
      } catch (e) {
        print('Error loading image: $e');
      }
    }

    return GestureDetector(
      onTap: () {
        if (profilePhotoUrl != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailFotoProfilScreen(
                imageUrl: profilePhotoUrl!,
              ),
            ),
          );
        }
      },
      child: Hero(
        tag: 'imageHero',
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 75,
            backgroundColor: Colors.grey[300],
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? const Icon(
              Icons.account_circle,
              size: 150,
              color: Colors.white,
            )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontFamily: 'Lexend',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            color: Colors.white,
            Icons.arrow_back_outlined,
            size: 30,
          ),
        ),
        title: const Text(
          'Profil',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Lexend',
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder(
          future: _userDataFuture,
          builder: (context, snapshot) {
            /*if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }*/

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        _buildProfilePhoto(),
                        const SizedBox(height: 16),
                        Text(
                          username.isNotEmpty ? username : 'Loading...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Lexend',
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            final bool result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfil(
                                  onProfileUpdated: () {
                                    _refreshData();
                                    if (widget.onProfileUpdated != null) {
                                      widget.onProfileUpdated!();
                                    }
                                  },
                                ),
                              ),
                            ) ?? false;

                            if (result == true) {
                              await _refreshData();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3028CC),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 5,
                          ),
                          child: const Text(
                            "Edit Profil",
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Lexend',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoCard('Email', emailController.text),
                  _buildInfoCard('Password', _isObscure ? '••••••••' : passwordController.text),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: const Color(0xFF2A2A2A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              title: const Text(
                                'Konfirmasi Logout',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: const Text(
                                'Apakah Anda yakin ingin logout?',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    'Tidak',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                    await AuthServices().signOut();
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) => const Login(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0XFFCC3328),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                      'Ya',
                                    style: TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0XFFCC3328),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        minimumSize: const Size(double.infinity, 60),
                        elevation: 5,
                      ),
                      child: const Text(
                        "Log Out",
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'Lexend',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}