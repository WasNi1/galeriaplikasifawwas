import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:aplikasi_galeri_baru/widget/dialog_foto.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aplikasi_galeri_baru/foto_screen/detail_foto_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CustomPinterestRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  const CustomPinterestRefresh({
    Key? key,
    required this.child,
    required this.onRefresh,
    required this.isRefreshing,
  }) : super(key: key);

  @override
  State<CustomPinterestRefresh> createState() => _CustomPinterestRefreshState();
}

class _CustomPinterestRefreshState extends State<CustomPinterestRefresh> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isRefreshing = false;
  static const double _maxDragOffset = 150.0;
  static const double _refreshTriggerOffset = 100.0;
  static const double _resistance = 0.5;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isDragging = false;
  bool _isAtTop = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.addListener(() {
      setState(() {
        _dragOffset = _animation.value;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _resetPosition() {
    _animation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController
      ..reset()
      ..forward();
  }

  void _startRefresh() async {
    setState(() {
      _isRefreshing = true;
      _dragOffset = _refreshTriggerOffset;
    });

    await widget.onRefresh();

    setState(() {
      _isRefreshing = false;
    });
    _resetPosition();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          setState(() {
            _isAtTop = notification.metrics.pixels <= 0;
          });
        }
        return false;
      },
      child: Listener(
        onPointerDown: (event) {
          if (_isAtTop) {
            _isDragging = true;
            _animationController.stop();
          }
        },
        onPointerUp: (event) {
          if (_isDragging) {
            _isDragging = false;
            if (_dragOffset > _refreshTriggerOffset && !_isRefreshing) {
              _startRefresh();
            } else {
              _resetPosition();
            }
          }
        },
        onPointerMove: (event) {
          if (!_isDragging || _isRefreshing) return;

          // Only allow pulling when at the top
          if (!_isAtTop && _dragOffset <= 0) return;

          final delta = event.delta.dy * _resistance;

          if (delta > 0) {
            setState(() {
              final resistance = 1.0 - (_dragOffset / _maxDragOffset * 0.5);
              _dragOffset += delta * resistance;
              _dragOffset = _dragOffset.clamp(0.0, _maxDragOffset);
            });
          } else if (_dragOffset > 0) {
            setState(() {
              _dragOffset += delta * 1.2;
              _dragOffset = _dragOffset.clamp(0.0, _maxDragOffset);
            });
          }
        },
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: widget.child,
            ),
            if (_dragOffset > 0 || widget.isRefreshing)
              Positioned(
                top: -60 + _dragOffset,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _dragOffset > 0 ? (_dragOffset / _refreshTriggerOffset).clamp(0.0, 1.0) : 0.0,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Transform.rotate(
                        angle: (_dragOffset / _refreshTriggerOffset * pi).clamp(0.0, pi),
                        child: Icon(
                          _isRefreshing ? Icons.refresh : Icons.arrow_downward,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _handleOverscroll(OverscrollNotification notification) {
    if (_isAtTop && notification.overscroll < 0 && !_isRefreshing) {
      setState(() {
        _dragOffset -= notification.overscroll;
        _dragOffset = _dragOffset.clamp(0.0, _maxDragOffset);
      });
    }
    return false;
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (_dragOffset > _refreshTriggerOffset && !_isRefreshing) {
      _startRefresh();
    } else {
      _resetPosition();
    }
    return false;
  }
}

class PinterestStyleGrid extends StatelessWidget {
  final List<DateGroup> groups;
  final Function(GridItem) onTapPhoto;

  const PinterestStyleGrid({
    Key? key,
    required this.groups,
    required this.onTapPhoto,
  }) : super(key: key);

  String getThumbnailUrl(String originalUrl) {
    return "$originalUrl?w=300";
  }

  @override
  Widget build(BuildContext context) {
    final allPhotos = groups.expand((group) => group.items).toList();

    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: EdgeInsets.all(8),
      itemCount: allPhotos.length,
      itemBuilder: (context, index) {
        final item = allPhotos[index];

        return GestureDetector(
          onTap: () => onTapPhoto(item),
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
        );
      },
    );
  }
}

class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;

  const OptimizedNetworkImage({
    Key? key,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: imageUrl,
      memCacheWidth: 300,
      maxWidthDiskCache: 300,
      fit: BoxFit.cover,
      placeholder: (context, url) => AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: Colors.grey[200],
        ),
      ),
      errorWidget: (context, url, error) => AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: Colors.grey[300],
          child: const Icon(Icons.error_outline),
        ),
      ),
    );
  }
}

class FotoGroupedGridView extends StatefulWidget {
  const FotoGroupedGridView({super.key});

  @override
  State<FotoGroupedGridView> createState() => _FotoGroupedGridViewState();
}

class _FotoGroupedGridViewState extends State<FotoGroupedGridView> {
  final List<DateGroup> groups = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';
  int? _currentUserId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializedData();
  }

  Future<void> _initializedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getInt('user_id');

    if (savedUserId != null) {
      setState(() {
        _currentUserId = savedUserId;
      });

      _loadCachedPhotos();
    }

    _fetchAndUpdatePhotos();
  }

  Future<void> _loadCachedPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedPhotoString = prefs.getString('cached_photos_${_currentUserId}');

    if (cachedPhotoString != null) {
      final cachedPhotos = json.decode(cachedPhotoString) as List;
      _processPhotos(cachedPhotos.cast<Map<String, dynamic>>());
    }
  }

  Future<void> _fetchAndUpdatePhotos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Tambahkan delay 3 detik
    await Future.delayed(const Duration(seconds: 3));

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final response = await http.get(
          Uri.parse('http://10.0.2.2/gallery_api/backend/get_public_photos.php?firebase_uid=${user.uid}'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['success'] == true) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('user_id', data['user_id']);
            setState(() {
              _currentUserId = data['user_id'];
            });

            await prefs.setString('cached_photos_${data['user_id']}',
                json.encode(data['photos']));

            _processPhotos(List<Map<String, dynamic>>.from(data['photos']));
          }
        }
      } catch (e) {
        print('Error fetching photos: $e');
        if (groups.isEmpty) {
          setState(() {
            _errorMessage = 'Gagal memuat foto. Silakan coba lagi.';
          });
        }
      }
    }

    setState(() {
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
    });

    await _fetchAndUpdatePhotos();
  }

  void _processPhotos(List<Map<String, dynamic>> photos) {
    Map<String, List<GridItem>> groupedPhotos = {};

    for (var photo in photos) {
      final dateStr = photo['FormattedDate'] ?? '';

      if (!groupedPhotos.containsKey(dateStr)) {
        groupedPhotos[dateStr] = [];
      }

      groupedPhotos[dateStr]!.add(GridItem(
        id: int.parse(photo['FotoID'].toString()),
        imageUrl: photo['LokasiFile'],
        date: dateStr,
      ));
    }

    setState(() {
      groups.clear();
      groupedPhotos.forEach((date, items) {
        groups.add(DateGroup(date: date, items: items));
      });
    });
  }

  void _addNewPhoto(String imageUrl) {
    final now = DateTime.now();
    final dateStr = "${now.day} ${_getMonthName(now.month)}";

    final existingGroupIndex = groups.indexWhere((group) => group.date == dateStr);

    if (existingGroupIndex != -1) {
      setState(() {
        groups[existingGroupIndex].items.insert(0, GridItem(
          id: DateTime.now().millisecondsSinceEpoch,
          imageUrl: imageUrl,
          date: dateStr,
        ));
      });
    } else {
      setState(() {
        groups.insert(0, DateGroup(
            date: dateStr,
            items: [
              GridItem(
                id: DateTime.now().millisecondsSinceEpoch,
                imageUrl: imageUrl,
                date: dateStr,
              )
            ]
        ));
      });
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: CustomPinterestRefresh(
        isRefreshing: _isRefreshing,
        onRefresh: _onRefresh,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _fetchAndUpdatePhotos,
              child: const Text('Retry'),
            )
          ],
        ),
      );
    }

    return groups.isEmpty ? _buildEmptyState() : _buildPhotoGrid();
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Belum ada foto', style: TextStyle(color: Colors.grey, fontSize: 16)),
          Text('Tap logo kamera untuk menambah foto', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return PinterestStyleGrid(
        groups: groups,
        onTapPhoto: (item) {
          final List<PhotoInfo> allPhotos = [];
          for (var g in groups) {
            for (var photoItem in g.items) {
              allPhotos.add(PhotoInfo(
                id: photoItem.id,
                file: photoItem.imageUrl ?? '',
                date: photoItem.date,
                username: '',
                uploaderId: '',
              ));
            }
          }
          DateTime parseCustomDate(String date) {
            final parts = date.split(' ');
            final day = int.parse(parts[0]);
            final month = {
              'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'Mei': 5,
              'Jun': 6, 'Jul': 7, 'Agu': 8, 'Sep': 9, 'Okt': 10,
              'Nov': 11, 'Des': 12,
            }[parts[1]];

            return DateTime(DateTime.now().year, month!, day);
          }

          allPhotos.sort((a, b) => parseCustomDate(a.date).compareTo(parseCustomDate(b.date)));

          final tappedPhotoIndex = allPhotos.indexWhere(
                  (photo) => photo.file == item.imageUrl
          );

          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => DetailFotoScreen(
                    photoInfos: allPhotos,
                    initialIndex: tappedPhotoIndex,
                    onPhotoDeleted: (){
                      setState(() {});
                    },
                  )
              )
          );
        }
    );
  }
}

// Model classes
class DateGroup {
  final String date;
  final List<GridItem> items;

  DateGroup({required this.date, required this.items});
}

class GridItem {
  final int id;
  final String? imageUrl;
  final String date;

  GridItem({required this.id, this.imageUrl, required this.date});
}
