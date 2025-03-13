import 'package:aplikasi_galeri_baru/pages/account_pages.dart';
import 'package:aplikasi_galeri_baru/pages/home.dart';
import 'package:aplikasi_galeri_baru/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primaryColor: const Color(0xFF1E1E1E),
        fontFamily: 'Roboto',
      ),
      // Tentukan halaman pertama berdasarkan status autentikasi
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthChecker(), // Halaman awal
        '/home': (context) => const Home(), // Rute untuk halaman Home
        '/login': (context) => const Login(), // Rute untuk halaman Login
      },
    );
  }
}

class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasData) {
          // Jika sudah login, arahkan ke halaman Home
          return const Home();
        } else {
          // Jika belum login, arahkan ke halaman Login
          return const Login();
        }
      },
    );
  }
}
