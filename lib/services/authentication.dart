import 'package:aplikasi_galeri_baru/global/common/toast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;


  // signup
  Future<String> signUpUser({
    required String email,
    required String password,
    required String username,
  }) async {
    String res = "Some Error Occurred";
    try {
      if (email.isNotEmpty && password.isNotEmpty && username.isNotEmpty) {
        UserCredential credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await _firestore.collection('users').doc(credential.user!.uid).set({
          'username': username,
          'email': email,
          'uid': credential.user!.uid,
        });

        showToast(message: "Selamat Datang di Halaman Home");
        res = "success";
      } else {
        showToast(message: "Semua Bidang Harus di isi");
        res = "error";
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        res = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        showToast(message: "The account already exists for that email.");
      } else {
        res = e.message ?? "Some error Occurred";
      }
      print(e.toString());
    } catch (e) {
      return e.toString();
    }
    return res;
  }


  // login
  Future<String> loginUser({
    required String email,
      required String password,
    }) async {
        String res = "Some Error Occurred";
        try {
          if(email.isNotEmpty || password.isNotEmpty){
            await _auth.signInWithEmailAndPassword(
                email: email, password: password,
            );

            showToast(message: "Selamat Datang");
            res = "success";
          } else {
            showToast(message: "Semua Bidang Harus di isi");
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-not-found') {
            showToast(message: "email-not-found");
            res = "error";
          } else if (e.code == 'wrong-password') {
            showToast(message: "wrong-password");
            res = "error";
          } else {
            showToast(message: 'Invalid email or password');
          }
        }
        catch(e){
          return e.toString();
        }
        return res;
      }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}