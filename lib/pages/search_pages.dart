import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:aplikasi_galeri_baru/foto_screen/detail_foto_screen.dart';
import 'package:aplikasi_galeri_baru/widget/dialog_foto.dart';

class AspectRatioImage extends StatefulWidget {
  final String imageUrl;

  const AspectRatioImage({
    Key? key,
    required this.imageUrl,
  }) : super(key: key);

  @override
  State<AspectRatioImage> createState() => _AspectRatioImageState();
}

class _AspectRatioImageState extends State<AspectRatioImage> {
  late ImageProvider _imageProvider;
  double? _aspectRatio;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _imageProvider = NetworkImage(widget.imageUrl);
    _loadImage();
  }

  Future<void> _loadImage() async {
    final completer = Completer<ui.Image>();
    final imageStream = _imageProvider.resolve(ImageConfiguration.empty);

    final listener = ImageStreamListener(
          (ImageInfo info, bool _) {
        if (!completer.isCompleted) {
          completer.complete(info.image);
        }
      },
      onError: (exception, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(exception, stackTrace);
        }
      },
    );

    imageStream.addListener(listener);

    try {
      final image = await completer.future;
      if (mounted) {
        setState(() {
          _aspectRatio = image.width / image.height;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading image: $e');
      if (mounted) {
        setState(() {
          _aspectRatio = 1.0;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 150, // Default height while loading
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _aspectRatio ?? 1.0,
      child: Image(
        image: _imageProvider,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
      ),
    );
  }
}

class SearchPages extends StatefulWidget {
  const SearchPages({Key? key}) : super(key: key);

  @override
  State<SearchPages> createState() => _SearchPagesState();
}

class _SearchPagesState extends State<SearchPages> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _searchHistory = [];
  List<String> _recommendations = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _showResults = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _fetchPopularTags();

    _searchController.addListener(() {
      setState(() {
        _isSearching = _searchController.text.isNotEmpty;
      });
      if (_searchController.text.isNotEmpty) {
        _getSearchSuggestions(_searchController.text);
      }
    });
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _searchHistory);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _isLoading = true;
        _showResults = true;
      });

      await _performImageSearch();
    }
  }

  Future<void> _fetchPopularTags() async {
    try {
      String? firebaseUid = _auth.currentUser?.uid;
      if (firebaseUid == null) return;
      
      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2/gallery_api/backend/get_popular_tags.php?firebase_uid=$firebaseUid'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _recommendations = List<String>.from(data['tags']);
        });
      }
    } catch (e) {
      print('Error fetching popular tags: $e');
    }
  }
  
  Future<void> _performImageSearch() async {
    if (_selectedImage == null) return;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2/gallery_api/backend/search_similar_images.php'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          _selectedImage!.path,
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);
        var transformedResults = jsonData.map<Map<String, dynamic>>((item) => {
          'FotoID': item['foto_id'],
          'LokasiFile': item['file_path'],
          'JudulFoto': item['judul_foto'] ?? 'Untitled',
          'FormattedDate': item['upload_date'],
          'similarity_score': item['similarity_score'],
        }).toList();

        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(transformedResults);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error performing image search: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getSearchSuggestions(String query) async {
    if (query.length < 2) return;
    
    try {
      String? firebaseUid = _auth.currentUser?.uid;
      if (firebaseUid == null) return;
      
      final response = await http.get(
          Uri.parse(
              'http://10.0.2.2/gallery_api/backend/get_tag_suggestions.php?query=${Uri.encodeComponent(query)}&firebase_uid=$firebaseUid'
          ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _recommendations = List<String>.from(data['suggestions']);
        });
      }
    } catch (e) {
      print('Error getting tag suggestions: $e');
      setState(() {
        _recommendations = [
          'Balap', 'Kunci', 'Keren', 'Motor', 'Mobil',
        ].where((term) => term.toLowerCase().contains(query.toLowerCase())).toList();
      });
    }
  }

  Future<void> _performTagSearch(String tag) async {
    try {
      String? firebaseUid = _auth.currentUser?.uid;
      if (firebaseUid == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2/gallery_api/backend/search_by_tag.php?tag=${Uri.encodeComponent(tag)}&firebase_uid=$firebaseUid'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data['results']);

          _recommendations = _searchResults
              .expand((result) => (result['TagsArray'] as List? ?? []))
              .where((relatedTag) => relatedTag.toString() != tag) // Jangan rekomendasikan tag yang sedang dicari
              .map((tag) => tag.toString())
              .toSet()
              .take(5)
              .toList();
        });
      }
    } catch (e) {
      print('Error searching by tag: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error performing tag search')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _searchByTag(String tag) {
    if (tag.isEmpty) return;

    setState(() {
      _isLoading = true;
      _showResults = true;
    });

    _addToSearchHistory('#$tag');
    _performTagSearch(tag);
  }

  void _addToSearchHistory(String query) {
    if (query.isNotEmpty && !_searchHistory.contains(query)) {
      setState(() {
        _searchHistory.insert(0, query);
        if (_searchHistory.length > 10) {
          _searchHistory.removeLast();
        }
      });
      _saveSearchHistory();
    }
  }

  void _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _showResults = true;
    });

    _addToSearchHistory(query);

    try {
      String? firebaseUid = _auth.currentUser?.uid;
      if (firebaseUid == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2/gallery_api/backend/search_photos.php?query=${Uri.encodeComponent(query)}&firebase_uid=$firebaseUid'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data['results']);

          // Update recommendations based on found tags
          _recommendations = _searchResults
              .expand((result) => (result['TagsArray'] as List? ?? []))
              .map((tag) => tag.toString())
              .toSet()
              .take(5)
              .toList();
        });
      }
    } catch (e) {
      print('Error searching: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error performing search')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Search header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (_showResults) {
                        setState(() => _showResults = false);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Cari ide',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _isSearching = false;
                                      _showResults = false;
                                    });
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.camera_alt, color: Colors.white),
                                onPressed: _pickImage,
                              ),
                            ],
                          ),
                        ),
                        onSubmitted: _performSearch,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: _showResults ? _buildSearchResults() : _buildSearchHome(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHome() {
    return Column(
      children: [
        // Search history
        if (!_isSearching && _searchHistory.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _searchHistory.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text(
                    _searchHistory[index],
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _searchHistory.removeAt(index);
                      });
                      _saveSearchHistory();
                    },
                  ),
                  onTap: () {
                    _searchController.text = _searchHistory[index];
                    _performSearch(_searchHistory[index]);
                  },
                );
              },
            ),
          ),

        // Search suggestions
        if (_isSearching && _recommendations.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _recommendations.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.search, color: Colors.grey),
                  title: Text(
                    _recommendations[index],
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    _searchController.text = _recommendations[index];
                    _performSearch(_recommendations[index]);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Foto yang anda cari tidak dapat ditemukan',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Coba cari dengan kata kunci lain',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: _recommendations.map((tag) => _buildFilterChip(tag)).toList(),
          ),
        ),

        // Pinterest-style grid results
        Expanded(
          child: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            padding: const EdgeInsets.all(8),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final item = _searchResults[index];

              return GestureDetector(
                onTap: () {
                  final List<PhotoInfo> photoInfos = _searchResults.map((result) =>PhotoInfo(
                      id: int.parse(result['FotoID'].toString()),
                      file: result['LokasiFile'],
                      date: result['FormattedDate'],
                      username: '',
                      uploaderId: '',
                  )).toList();

                  final tappedPhotoIndex = _searchResults.indexWhere(
                      (photo) => photo['FotoID'] == item['FotoID']
                  );

                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => DetailFotoScreen(
                              photoInfos: photoInfos,
                            initialIndex: tappedPhotoIndex,
                            onPhotoDeleted: () {
                                setState(() {
                                  _performSearch(_searchController.text);
                                });
                            },
                          ),
                      ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image with aspect ratio preservation
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: AspectRatioImage(
                          imageUrl: item['LokasiFile'],
                        ),
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              item['JudulFoto'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // Date
                            if (item['FormattedDate'] != null)
                              Text(
                                item['FormattedDate'],
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 8),

                            // Tags
                            if ((item['TagsArray'] as List?)?.isNotEmpty ?? false)
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: (item['TagsArray'] as List)
                                    .take(3)
                                    .map((tag) => _buildTagChip(tag))
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTagChip(String tag) {
    return GestureDetector(
      onTap: () => _searchByTag(tag),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        margin: EdgeInsets.only(right: 4, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '#$tag',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        selected: false,
        onSelected: (bool selected) {
          _searchByTag(label); // Menggunakan fungsi khusus untuk pencarian tag
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}