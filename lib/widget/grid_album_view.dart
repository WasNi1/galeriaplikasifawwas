import 'package:aplikasi_galeri_baru/pages/favorit_pages.dart';
import 'package:flutter/material.dart';

class AlbumGalleryView extends StatelessWidget {
  final List<AlbumItem> albums = [
    AlbumItem(
      title: "Kamera",
      itemCount: 20,
      thumbnail: Colors.grey[300],
    ),
    AlbumItem(
      title: "Screenshots",
      itemCount: 8,
      thumbnail: Colors.grey[300],
    ),
    AlbumItem(
      title: "WhatsApp Image",
      itemCount: 2,
      thumbnail: Colors.grey[300],
    ),
    AlbumItem(
      title: "Download",
      itemCount: 9,
      thumbnail: Colors.grey[300],
    ),
  ];

  AlbumGalleryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Action buttons row (Favorit & Sampah)
            Row(
              children: [
                Expanded(child: TextButton(
                    onPressed: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritPages()),);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.favorite,
                        size: 20,
                          color: Colors.black,
                        ),
                        SizedBox(width: 8),
                        Text('Favorit',
                        style: TextStyle(
                          color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 16),
            // Albums grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: albums.where((album) => !album.isAction).length,
                itemBuilder: (context, index) {
                  final album = albums.where((album) => !album.isAction).elementAt(index);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: album.thumbnail,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        album.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${album.itemCount} items",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlbumItem {
  final String title;
  final int itemCount;
  final Color? thumbnail;
  final IconData? icon;
  final bool isAction;

  AlbumItem({
    required this.title,
    required this.itemCount,
    this.thumbnail,
    this.icon,
    this.isAction = false,
  });
}
