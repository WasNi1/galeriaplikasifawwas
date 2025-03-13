import 'package:aplikasi_galeri_baru/foto_screen/detail_foto_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FavoritPages extends StatefulWidget{
  const FavoritPages ({super.key});

  @override
  State<FavoritPages> createState() => _FavoritPageScreenState();
}

class _FavoritPageScreenState extends State<FavoritPages>{
  final List<PhotoInfo> favoritePhotos = [];
  bool _isLoading = true;

  @override
  void initState() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;

      /*
      favoritePhotos.addAll([
        PhotoInfo(file: 'your_image_url', date: '23 Dec'),
        PhotoInfo(file: 'your_image_url', date: '23 Dec'),
      ]);
      */
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFEFAE0),
        leading: IconButton(
          onPressed: (){
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_outlined),
        ),
        title: const Text('Favorit'),
      ),
      backgroundColor: Color(0xFFFEFAE0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : favoritePhotos.isEmpty
          ? _buildEmptyState()
          : _buildPhotoGrid(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey,),
          SizedBox(height: 16),
          Text(
            'Belum ada Foto yang di Favoritkan',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: favoritePhotos.length,
        itemBuilder: (context, index) {
          final photo = favoritePhotos[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailFotoScreen(
                    photoInfos: favoritePhotos,
                    initialIndex: index,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: photo.file is String
                    ? Image.network(
                  photo.file,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.error, color: Colors.grey);
                  },
                )

                    : Image.file(
                  photo.file,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          );
        }
    );
  }
}