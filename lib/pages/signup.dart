import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isVisible = false;
  bool isConfirmVisible = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return "Username dibutuhkan";
    }
    if (value.length < 3) {
      return "Username minimal 3 karakter";
    }
    // Add more username validation if needed
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "Email dibutuhkan";
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return "Format email tidak valid";
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Password dibutuhkan";
    }
    if (value.length < 6) {
      return "Password minimal 6 karakter";
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return "Password harus mengandung minimal satu angka";
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return "Password harus mengandung minimal satu huruf kapital";
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != passwordController.text) {
      return "Konfirmasi password tidak cocok";
    }
    return null;
  }

  void signUpUser() async {
    if (formKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
      });

      try {
        // Check if username is already taken
        final usernameQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: usernameController.text.trim())
            .get();

        if (usernameQuery.docs.isNotEmpty) {
          _showSnackBar("Username sudah digunakan");
          return;
        }

        // Registrasi pengguna ke Firebase
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        // Simpan data pengguna ke Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'username': usernameController.text.trim(),
          'email': emailController.text.trim(),
          'uid': userCredential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Sinkronisasi data pengguna ke database backend
        await syncUserToDatabase(
          firebaseUid: userCredential.user!.uid,
          email: emailController.text.trim(),
          username: usernameController.text.trim(),
        );

        _showSnackBar("Registrasi berhasil!");
        Navigator.of(context).pushReplacementNamed('/home');
      } on FirebaseAuthException catch (e) {
        _handleFirebaseAuthError(e);
      } catch (e) {
        _showSnackBar("Registrasi gagal: $e");
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    String errorMessage;
    switch (e.code) {
      case 'email-already-in-use':
        errorMessage = "Email sudah terdaftar";
        break;
      case 'weak-password':
        errorMessage = "Password terlalu lemah";
        break;
      default:
        errorMessage = "Terjadi kesalahan: ${e.message}";
    }
    _showSnackBar(errorMessage);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> syncUserToDatabase({
    required String firebaseUid,
    required String email,
    required String username,
  }) async {
    final uri = Uri.parse('http://10.0.2.2/gallery_api/backend/sync_user.php');
    try {
      final response = await http.post(uri, body: {
        'firebase_uid': firebaseUid,
        'username': username,
        'email': email,
      });

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success') {
          print("Sinkronisasi berhasil: ${jsonResponse['message']}");
        } else {
          print("Gagal sinkronisasi: ${jsonResponse['message']}");
        }
      } else {
        print("Error HTTP ${response.statusCode}: ${response.reasonPhrase}");
      }
    } catch (e) {
      print("Exception occurred: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Pinspire",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'MadimiOne',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Username Field
                  _buildTextFormField(
                    controller: usernameController,
                    hintText: "Username",
                    icon: Icons.person,
                    validator: _validateUsername,
                  ),

                  // Email Field
                  _buildTextFormField(
                    controller: emailController,
                    hintText: "Email",
                    icon: Icons.email,
                    validator: _validateEmail,
                  ),

                  // Password Field
                  _buildTextFormField(
                    controller: passwordController,
                    hintText: "Password",
                    icon: Icons.lock,
                    isPassword: true,
                    obscureText: !isVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        isVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        setState(() {
                          isVisible = !isVisible;
                        });
                      },
                    ),
                    validator: _validatePassword,
                  ),

                  // Confirm Password Field
                  _buildTextFormField(
                    controller: confirmPasswordController,
                    hintText: "Konfirmasi Password",
                    icon: Icons.lock,
                    isPassword: true,
                    obscureText: !isConfirmVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        isConfirmVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        setState(() {
                          isConfirmVisible = !isConfirmVisible;
                        });
                      },
                    ),
                    validator: _validateConfirmPassword,
                  ),

                  const SizedBox(height: 30),

                  // Register Button
                  ElevatedButton(
                    onPressed: isLoading ? null : signUpUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB99470),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "Register",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Login Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Sudah punya akun? ",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'Lexend',
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            color: Color(0xFFB99470),
                            fontFamily: 'Lexend',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
    bool isPassword = false,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white54),
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        ),
      ),
    );
  }
}