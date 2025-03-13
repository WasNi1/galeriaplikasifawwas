import 'dart:convert';
import 'package:flutter/material.dart';


class DetailFotoProfilScreen extends StatelessWidget {
  final String imageUrl;

  const DetailFotoProfilScreen({super.key, required this.imageUrl});


  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (imageUrl.startsWith('data:image')) {
      try {
        String base64Image = imageUrl.split(',')[1];
        imageWidget = Image.memory(
          base64Decode(base64Image),
          fit: BoxFit.cover,
          width: 350,
          height: 350,
        );
      } catch (e) {
        print('Error loading base64 image in detail: $e');
        imageWidget = const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 100,
        );
      }
    } else {
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: 350,
        height: 350,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(
            Icons.clear,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Center(
          child: Hero(
            tag: 'imageHero',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1000.0),
              child: imageWidget,
            ),
          ),
        ),
      ),
    );
  }
}