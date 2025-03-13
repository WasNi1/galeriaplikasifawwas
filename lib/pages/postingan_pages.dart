import 'dart:convert';
import 'dart:io';
import 'package:aplikasi_galeri_baru/foto_screen/detail_foto_posting_screen.dart';
import 'package:http/http.dart' as http;
import 'package:aplikasi_galeri_baru/pages/edit_form.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../widget/grid_foto_view.dart';

class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;

  const OptimizedNetworkImage({
    Key? key,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print('Error loading image: $error');
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.image_not_supported, color: Colors.grey),
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
  final VoidCallback? onRefreshNeeded;

  const PinterestStyleGrid({
    Key? key,
    required this.groups,
    required this.onTapPhoto,
    this.scrollController,
    this.onRefreshNeeded,
  }) : super(key: key);

  @override
  State<PinterestStyleGrid> createState() => _PinterestStyleGridState();
}

class _PinterestStyleGridState extends State<PinterestStyleGrid> {
  OverlayEntry? _overlayEntry;
  bool _isDeleting = false;

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _showOptionsMenu(BuildContext context, GridItem item, Offset position) {
    _removeOverlay();

    final menuItems = [
      _MenuItem(
        icon: Icons.edit,
        title: 'Edit',
        onTap: () {
          _removeOverlay();
          _handleEditOption(context, item);
        },
      ),
      _MenuItem(
        icon: Icons.share,
        title: 'Share',
        onTap: () {
          _removeOverlay();
          _handleShareOption(context, item);
        },
      ),
      _MenuItem(
        icon: Icons.delete,
        title: 'Hapus',
        onTap: () {
          _removeOverlay();
          _handleDeleteOption(context, item);
        },
      ),
    ];

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent overlay for dismissing the menu
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
          // Menu
          Positioned(
            left: position.dx,
            top: position.dy,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        "Opsi",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ...menuItems.map((item) => _buildMenuOption(item)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildMenuOption(_MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          children: [
            Icon(item.icon, size: 20),
            const SizedBox(width: 12),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleEditOption(BuildContext context, GridItem item) async {
    try {
      final http.Response response = await http.get(Uri.parse(item.imageUrl ?? ''));

      if (response.statusCode != 200) {
        throw Exception('Gagal mengunduh gambar');
      }

      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}/temp_edit_image_${item.id}.jpg');
      await tempFile.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditForm(
              imageFile: tempFile,
              photoId: item.id,
              existingImageUrl: item.imageUrl,
              onImageUploaded: (url) {
                if (widget.onRefreshNeeded != null) {
                  widget.onRefreshNeeded!();
                }
                print('Foto berhasil diperbarui: $url');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _handleShareOption(BuildContext context, GridItem item) {
    // Implementasi untuk opsi berbagi
    print('Share item: ${item.id}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Berbagi item dengan ID: ${item.id}')),
    );
  }

  void _handleDeleteOption(BuildContext context, GridItem item) {
    // Tambahkan dialog konfirmasi dengan indikator loading
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Apakah Anda yakin ingin menghapus foto ini?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePhoto(context, item);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePhoto(BuildContext context, GridItem item) async {
    // Capture the context before the async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Set deleting state to show loading indicator if needed
    setState(() {
      _isDeleting = true;
    });

    // Optional: Show a loading snackbar
    final loadingSnackBar = SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 16),
          Text('Menghapus foto...'),
        ],
      ),
      duration: Duration(seconds: 60), // Long duration, will be dismissed manually
    );

    final loadingSnackBarController = scaffoldMessenger.showSnackBar(loadingSnackBar);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Print debugging info
      print('Sending delete request for photo ${item.id}');

      final response = await http.post(
        Uri.parse('http://10.0.2.2/gallery_api/backend/delete.php'),
        body: {
          'firebase_uid': user.uid,
          'photo_id': item.id.toString(),
        },
      );

      // Debug: Print raw response
      print('Raw response: ${response.body}');

      // Cancel the loading snackbar
      loadingSnackBarController.close();

      // Check if response is empty
      if (response.body.trim().isEmpty) {
        throw Exception('Server returned empty response');
      }

      // Check if response is valid JSON
      if (response.body.trim().startsWith('<')) {
        throw Exception('Server returned HTML instead of JSON: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success']) {
        // Show success snackbar with custom style
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 16),
                Text('Foto berhasil dihapus'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Refresh the gallery after successful deletion
        if (widget.onRefreshNeeded != null) {
          widget.onRefreshNeeded!();
        }
      } else {
        throw Exception(data['message'] ?? 'Gagal menghapus foto');
      }
    } catch (e) {
      print('Delete error: $e');  // Add logging for debugging

      // Cancel the loading snackbar
      loadingSnackBarController.close();

      // Show error snackbar with custom style
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 16),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      // Reset deleting state
      setState(() {
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPhotos = widget.groups.expand((group) => group.items).toList();

    return Stack(
      children: [
        MasonryGridView.count(
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
                onLongPress: () {
                  // Mendapatkan posisi untuk menu
                  final RenderBox renderBox = context.findRenderObject() as RenderBox;
                  final position = renderBox.localToGlobal(Offset.zero);
                  final size = renderBox.size;

                  // Menampilkan menu opsi
                  _showOptionsMenu(
                    context,
                    item,
                    Offset(position.dx + size.width / 2, position.dy + size.height / 2),
                  );
                },
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
        ),
        // Optional: Add a full-screen loading indicator when deleting
        if (_isDeleting)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

// Kelas helper untuk item menu
class _MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

class PostinganPages extends StatefulWidget {
  final Function(bool)? onScrolledToTop;
  final ScrollController? scrollController;

  const PostinganPages ({
    super. key,
    this.onScrolledToTop,
    this.scrollController,
  });

  @override
  State<PostinganPages> createState() => _PostinganPagesState();
}

class _PostinganPagesState extends State<PostinganPages> {
  final ScrollController _scrollController = ScrollController();
  final List<DateGroup> groups = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int? _currentUserId;
  bool _isAppBarVisible = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getInt('user_id');

    if (savedUserId != null) {
      setState(() {
        _currentUserId = savedUserId;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
      });

      await _loadCachedPost();
    }

    _fetchAndUpdatePost();
  }

  Future<void> _loadCachedPost() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedPostString = prefs.getString('cached_post_${_currentUserId}');

    if (cachedPostString != null) {
      final cachedPost = json.decode(cachedPostString) as List;
      _processPost(cachedPost.cast<Map<String, dynamic>>());
    }
  }

  Future<void> _fetchAndUpdatePost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final response = await http.get(
          Uri.parse('http://10.0.2.2/gallery_api/backend/get_photos.php?firebase_uid=${user.uid}'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['success'] == true) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cached_post_${data['user_id']}',
                json.encode(data['photos']));

            if (mounted) {
              _processPost(List<Map<String, dynamic>>.from(data['photos']));
              setState(() {
                _isLoading = false;
              });
            }
          }
        }
      } catch (e) {
        print('Error fetching post: $e');
        if (mounted && groups.isEmpty) {
          setState(() {
            _errorMessage = 'Gagal memuat postingan. Silakan coba lagi.';
            _isLoading = false;
          });
        }
      }
    }
  }

  void _scrollListener() {
    if (_scrollController.offset > 100 && _isAppBarVisible) {
      setState(() {
        _isAppBarVisible = false;
      });
    }
    else if (_scrollController.offset <= 100 && !_isAppBarVisible) {
      setState(() {
        _isAppBarVisible = true;
      });
    }
  }

  void _processPost(List<Map<String, dynamic>> posts) {
    Map<String, List<GridItem>> groupedPost = {};

    for (var post in posts) {
      final dateStr = post['FormattedDate'] ?? '';

      if (!groupedPost.containsKey(dateStr)) {
        groupedPost[dateStr] = [];
      }

      groupedPost[dateStr]!.add(GridItem(
        id: int.parse(post['FotoID'].toString()),
        imageUrl: post['LokasiFile'],
        date: dateStr,
      ));
    }

    setState(() {
      groups.clear();
      groupedPost.forEach((date, items) {
        groups.add(DateGroup(date: date, items: items));
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
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
          Icon(Icons.post_add_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Belum ada postingan',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          Text('Tap tombol tambah untuk membuat postingan',
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
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => DetailFotoPostingScreen(
                    photoInfos: groups
                        .expand((group) => group.items)
                        .map((gridItem) => PhotoInfo(
                          file: gridItem.imageUrl ?? '',
                          date: gridItem.date ?? '',
                          id: gridItem.id,
                          username: 'Uploader'
                      ))
                        .toList(),
                  initialIndex: groups
                    .expand((group) => group.items)
                    .toList()
                    .indexWhere((element) => element.id == item.id),
                  isOwnPost: true,
                ),
            ),
        );
      },
      onRefreshNeeded: _fetchAndUpdatePost,
    );
  }
}