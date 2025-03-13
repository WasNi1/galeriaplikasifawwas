import 'dart:convert';

import 'package:aplikasi_galeri_baru/widget/grid_foto_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;

  const OptimizedNetworkImage({
    Key? key,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('Loading image: $imageUrl'); // Debug log

    if (imageUrl.isEmpty) {
      print('Empty image URL'); // Debug log
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print('Error loading image: $error'); // Debug log
        print('Stack trace: $stackTrace'); // Debug log
        return Container(
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_not_supported, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'Gagal memuat gambar',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class PinterestStyleGrid extends StatefulWidget {
  final List<DateGroup> groups;
  final Function(GridItem) onTapPhoto;
  final ScrollController? scrollController;

  const PinterestStyleGrid({
    Key? key,
    required this.groups,
    required this.onTapPhoto,
    this.scrollController,
  }) : super(key: key);

  @override
  State<PinterestStyleGrid> createState() => _PinterestStyleGridState();
}

class _PinterestStyleGridState extends State<PinterestStyleGrid> {

  @override
  Widget build(BuildContext context) {
    final allPhotos = widget.groups.expand((group) => group.items).toList();

    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: const EdgeInsets.all(8),
      itemCount: allPhotos.length,
      itemBuilder: (context, index) {
        final item = allPhotos[index];

        return Builder(
          builder: (context) => GestureDetector(
            onTap: () => widget.onTapPhoto(item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: OptimizedNetworkImage(
                    imageUrl: item.imageUrl ?? '',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class DisimpanPages extends StatefulWidget {
  final ScrollController? scrollController;

  const DisimpanPages ({
    Key? key,
    this.scrollController,
  });

  @override
  State<DisimpanPages> createState() => _DisimpanPagesState();
}

class _DisimpanPagesState extends State<DisimpanPages>{
  final List<DateGroup> groups = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getInt('user_id');

    if (savedUserId != null) {
      setState(() {
        _currentUserId = savedUserId;
      });
      _loadCachedSaved();
    }
    _fetchAndUpdateSaved();
  }

  Future<void> _loadCachedSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedSavedString = prefs.getString('cached_saved_${_currentUserId}');

    if (cachedSavedString != null) {
      final cachedSaved = json.decode(cachedSavedString) as List;
      _processSaved(cachedSaved.cast<Map<String, dynamic>>());
    }
  }

  Future<void> _fetchAndUpdateSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId != null) {
      try {
        print('Fetching saved photos for user: $userId');

        final response = await http.get(
          Uri.parse('http://10.0.2.2/gallery_api/backend/get_saved_photos.php?user_id=$userId'),
        );

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['success'] == true) {
            final savedPhotos = data['saved_photos'] as List;
            await prefs.setString('cached_saved_$userId', json.encode(savedPhotos));

            if (mounted) {
              _processSaved(List<Map<String, dynamic>>.from(savedPhotos));
            }
          } else {
            print('API returned success false: ${data['message']}');
          }
        }
      } catch (e) {
        print('Error fetching saved items: $e');
        if (mounted && groups.isEmpty) {
          setState(() {
            _errorMessage = 'Gagal memuat item tersimpan. Silakan coba lagi.';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _processSaved(List<Map<String, dynamic>> saved) {
    Map<String, List<GridItem>> groupedSaved = {};

    print('Processing saved photos: ${saved.length}');

    for (var item in saved) {
      print('Processing item:');
      print('Date: ${item['FormattedDate']}');
      print('Photo ID: ${item['FotoID']}');
      print('Location: ${item['LokasiFile']}');

      final dateStr = item['FormattedDate'] ?? DateTime.now().toString().split(' ')[0];

      if (!groupedSaved.containsKey(dateStr)) {
        groupedSaved[dateStr] = [];
      }

      final photoId = item['FotoID']?.toString() ?? '';
      var photoUrl = item['LokasiFile']?.toString() ?? '';

      const baseUrl = 'http://10.0.2.2/gallery_api/backend/uploads/';
      if (photoUrl == baseUrl) {
        print('Warning: LokasiFile only contains the base URL without filename');
      } else if (photoUrl.startsWith(baseUrl + baseUrl)) {
        photoUrl = photoUrl.replaceFirst(baseUrl, '');
      }

      if (photoId.isNotEmpty && photoUrl.isNotEmpty) {
        print('Adding photo to grid: $photoUrl');

        groupedSaved[dateStr]!.add(GridItem(
          id: int.parse(photoId),
          imageUrl: photoUrl,
          date: dateStr,

        ));
      }
    }

    if (mounted) {
      setState(() {
        groups.clear();
        groupedSaved.forEach((date, items) {
          if (items.isNotEmpty) {
            groups.add(DateGroup(date: date, items: items));
          }
        });
        groups.sort((a, b) => b.date.compareTo(a.date));

        print('Total groups: ${groups.length}');
        for (var group in groups) {
          print('Group ${group.date}: ${group.items.length} items');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
          ? _buildEmptyState()
          : _buildPhotoGrid(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Belum ada item tersimpan',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          Text('Tap ikon bookmark untuk menyimpan item',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return PinterestStyleGrid(
      groups: groups,
      scrollController: widget.scrollController,
      onTapPhoto: (item) {

      },
    );
  }
}