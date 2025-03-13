import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aplikasi_galeri_baru/widget/grid_album_view.dart';

class AlbumPages extends StatefulWidget {
  const AlbumPages ({super.key});

  @override
  State<AlbumPages> createState() => _AlbumPagesScreenState();
}

class _AlbumPagesScreenState extends State<AlbumPages> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Color(0xFFFEFAE0),
        child: Center(
          child: AlbumGalleryView(),
        ),
      ),
    );
  }
}