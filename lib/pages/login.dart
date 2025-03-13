import 'package:aplikasi_galeri_baru/pages/signup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<Login> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController loginController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool isVisible = false;

  @override
  void dispose() {
    loginController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Check if input is email or username
      String loginIdentifier = loginController.text.trim();
      UserCredential userCredential;

      // First, try to login with email
      try {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: loginIdentifier,
          password: passwordController.text.trim(),
        );
      } catch (emailLoginError) {
        // If email login fails, try to find user by username
        QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: loginIdentifier)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          String userEmail = userQuery.docs.first['email'];
          userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: userEmail,
            password: passwordController.text.trim(),
          );
        } else {
          throw FirebaseAuthException(code: 'user-not-found');
        }
      }

      // Sinkronisasi data pengguna ke Firestore jika belum ada
      final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'username': userCredential.user!.displayName ?? 'Guest',
          'email': userCredential.user!.email,
          'uid': userCredential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Sinkronisasi data pengguna ke backend
      await syncUserToDatabase();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login berhasil")),
      );

      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      switch (e.code) {
        case 'user-not-found':
          errorMessage = "Pengguna tidak ditemukan.";
          break;
        case 'wrong-password':
          errorMessage = "Password salah.";
          break;
        default:
          errorMessage = "Terjadi kesalahan: ${e.message}";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login gagal: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Method to show Forgot Password Dialog
  void showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40), // For spacing
                      const Text(
                        "Lupa Sandi Anda",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Masukkan Email",
                      hintText: "Email",
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB99470),
                    ),
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.sendPasswordResetEmail(
                            email: emailController.text.trim()
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Tautan setel ulang kata sandi telah kami kirimkan ke email Anda, silakan periksa"),
                          ),
                        );
                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Terjadi kesalahan: ${e.toString()}"),
                          ),
                        );
                      }
                      emailController.clear();
                    },
                    child: const Text(
                      "Kirim",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }

  Future<void> syncUserToDatabase() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String firebaseUid = user.uid;
      String email = user.email ?? '';
      String username = user.displayName ?? 'Guest';

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
        }
      } catch (e) {
        print("Error syncing user: $e");
      }
    } else {
      print("No user is signed in.");
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
                  const SizedBox(height: 50),
                  _buildTextFormField(
                    controller: loginController,
                    hintText: "Email",
                    icon: Icons.email,
                    validator: (value) {
                      if (value!.isEmpty) {
                        return "email dibutuhkan";
                      }
                      return null;
                    },
                  ),
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
                    validator: (value) {
                      if (value!.isEmpty) {
                        return "Password dibutuhkan";
                      } else if (value.length < 6) {
                        return "Password harus minimal 6 karakter";
                      } else if (!value.contains(RegExp(r'[0-9]'))) {
                        return "Password harus mengandung minimal satu angka";
                      }
                      return null;
                    },
                  ),
                  // Add Forgot Password link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: showForgotPasswordDialog,
                      child: Text(
                        "Lupa Sandi?",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'Lexend',
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildLoginButton(),
                  const SizedBox(height: 20),
                  _buildSignUpSection(),
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

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: isLoading ? null : handleLogin,
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
        "Login",
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSignUpSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Belum punya akun? ",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontFamily: 'Lexend',
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignUp()),
            );
          },
          child: const Text(
            "Register",
            style: TextStyle(
              color: Color(0xFFB99470),
              fontFamily: 'Lexend',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}