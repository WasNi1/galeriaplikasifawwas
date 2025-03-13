import 'dart:convert';
import 'package:aplikasi_galeri_baru/pages/edit_form.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:aplikasi_galeri_baru/widget/bottom_navigation_foto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pinch_zoom_release_unzoom/pinch_zoom_release_unzoom.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhotoInfo {
  final dynamic file;
  final String date;
  final int id;
  int likes;
  bool isLiked;
  bool isSaved;
  String? judul;
  String? deskripsi;
  final String? description;
  final String username;
  final String? userPhotoUrl;

  PhotoInfo({
    required this.file,
    required this.date,
    required this.id,
    this.likes = 0,
    this.isSaved = false,
    this.isLiked = false,
    this.judul,
    this.deskripsi,
    this.description,
    required this.username,
    this.userPhotoUrl,
  });
}

class CommentModel {
  final int id;
  final int userId;
  final String username;
  final String comment;
  final String? userProfilePic; // Bisa null
  int likes;
  final List<ReplyModel> replies;
  final DateTime timestamp;
  bool showReplies;
  bool isLiked;

  CommentModel({
    this.id = 0,
    this.userId = 0,
    required this.username,
    required this.comment,
    this.userProfilePic, // Bisa null
    this.likes = 0,
    this.replies = const [],
    DateTime? timestamp,
    this.showReplies = false,
    this.isLiked = false,
  }) : timestamp = timestamp ?? DateTime.now();

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: int.parse(json['KomentarID'].toString()),
      userId: int.parse(json['UserID'].toString()),
      username: json['Username'] ?? 'Unknown User',
      comment: json['IsiKomentar'] ?? '',
      userProfilePic: json['profile_photo'], // Bisa null
      likes: json['LikeCount'] != null ? int.parse(json['LikeCount'].toString()) : 0,
      timestamp: json['TanggalKomentar'] != null
          ? DateTime.parse(json['TanggalKomentar'])
          : DateTime.now(),
    );
  }
}

class ReplyModel {
  final int id;
  final int userId;
  final String username;
  final String reply;
  final String? userProfilePic; // Bisa null
  int likes;
  final DateTime timestamp;
  bool isLiked;
  final int parentCommentId;

  ReplyModel({
    this.id = 0,
    this.userId = 0,
    required this.username,
    required this.reply,
    this.userProfilePic, // Bisa null
    this.likes = 0,
    DateTime? timestamp,
    this.isLiked = false,
    required this.parentCommentId,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ReplyModel.fromJson(Map<String, dynamic> json) {
    return ReplyModel(
      id: int.parse(json['BalasanID'].toString()),
      userId: int.parse(json['UserID'].toString()),
      username: json['Username'] ?? 'Unknown User',
      reply: json['IsiBalasan'] ?? '',
      userProfilePic: json['profile_photo'], // Bisa null
      likes: json['LikeCount'] != null ? int.parse(json['LikeCount'].toString()) : 0,
      timestamp: json['TanggalBalasan'] != null
          ? DateTime.parse(json['TanggalBalasan'])
          : DateTime.now(),
      parentCommentId: int.parse(json['KomentarID'].toString()),
    );
  }
}

class DetailFotoPostingScreen extends StatefulWidget {
  final List<PhotoInfo> photoInfos;
  final int initialIndex;
  final Function? onPhotoDeleted;
  final Function(int page)? onLoadMore;
  final bool isOwnPost;

  const DetailFotoPostingScreen({
    super.key,
    required this.photoInfos,
    this.initialIndex = 0,
    this.onPhotoDeleted,
    this.onLoadMore,
    this.isOwnPost = false,
  });

  @override
  State<DetailFotoPostingScreen> createState() => _DetailFotoPostingScreenState();
}

class _DetailFotoPostingScreenState extends State<DetailFotoPostingScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int currentIndex;
  bool _showAppBarAndBottomBar = true;
  final TransformationController transformationController = TransformationController();
  bool _isZooming = false;
  ScrollPhysics pageScrollPhysics = const BouncingScrollPhysics();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  final TransformationController _transformationController = TransformationController();
  final TextEditingController _commentController = TextEditingController();
  late ScrollController _scrollController;
  bool _isLoadingReplies = false;
  bool isLoadingMore = false;
  bool _isLoadingPhotoData = false;
  String? uploaderUsername;
  String? uploaderPhotoUrl;
  String? userId;
  bool blockScroll = false;
  ScrollController controller = ScrollController();
  bool _isCommentSheetOpen = false;
  bool _isDeleting = false;
  bool _isLoadingCommentReplies = false;
  int? _currentLoadingCommentId;
  Map<int, List<ReplyModel>> _repliesMap = {};
  bool _isLoadingComments = false;
  List<CommentModel> _comments = [];
  int? userIdInt;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )..addListener((){
      if (_animation != null) {
        _transformationController.value = _animation!.value;
      }
    });

    transformationController.addListener(_onTransformationChange);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadUploaderData();

    _loadUserData().then((_) {
      // Setelah user data dimuat, muat status like
      _loadInitialLikeStatus();
    });

    _loadPhotoData();

    // Fetch comments for the current photo
    _fetchComments();
  }

  @override
  void dispose() {
    _pageController.dispose();
    transformationController.removeListener(_onTransformationChange);
    transformationController.dispose();
    _animationController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500 && !isLoadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadPhotoData() async {
    setState(() {
      _isLoadingPhotoData = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print('User not logged in');
        return;
      }

      final response = await http.get(
        Uri.parse('http://10.0.2.2/gallery_api/backend/get_public_photos.php?firebase_uid=${user.uid}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final photos = data['photos'] as List;
          final currentPhoto = photos.firstWhere(
                (photo) => photo['FotoID'].toString() == widget.photoInfos[currentIndex].id.toString(),
            orElse: () => null,
          );

          if (currentPhoto != null) {
            setState(() {
              widget.photoInfos[currentIndex].judul = currentPhoto['JudulFoto'];
              widget.photoInfos[currentIndex].deskripsi = currentPhoto['DeskripsiFoto'];
            });
          }
        }
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoadingPhotoData = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (widget.onLoadMore != null) {
      setState(() {
        isLoadingMore = true;
      });
      await widget.onLoadMore!(widget.photoInfos.length ~/ 10);

      setState(() {
        isLoadingMore = false;
      });
    }
  }

  Future<void> _loadUploaderData() async {
    try {
      DocumentSnapshot photoDoc = await FirebaseFirestore.instance
          .collection('photos')
          .doc(widget.photoInfos[widget.initialIndex].id.toString())
          .get();

      if (photoDoc.exists) {
        Map<String, dynamic> photoData = photoDoc.data() as Map<String, dynamic>;
        String userId = photoData['user_id'];
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          uploaderUsername = userData['username'];
          uploaderPhotoUrl = userData['base64PhotoURL'] ?? userData['photoURL'];
        });
      }
    } catch (e) {
      print('Error loading uploader data: $e');
    }
  }

  Future<void> _deletePhoto(int photoId) async {
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
      print('Sending delete request for photo $photoId');

      final response = await http.post(
        Uri.parse('http://10.0.2.2/gallery_api/backend/delete.php'),
        body: {
          'firebase_uid': user.uid,
          'photo_id': photoId.toString(),
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

        // Remove the photo from the list
        setState(() {
          widget.photoInfos.removeWhere((photo) => photo.id == photoId);
        });

        // Notify the parent widget that a photo has been deleted
        if (widget.onPhotoDeleted != null) {
          widget.onPhotoDeleted!();
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

  Future<void> _handleEditOption(PhotoInfo photo) async {
    try {
      // Jika foto adalah file lokal (misalnya dari File), langsung gunakan file tersebut
      File? imageFile;
      if (photo.file is File) {
        imageFile = photo.file as File;
      } else if (photo.file is String) {
        // Jika foto adalah URL, unduh dan simpan sebagai file sementara
        final http.Response response = await http.get(Uri.parse(photo.file));

        if (response.statusCode != 200) {
          throw Exception('Gagal mengunduh gambar');
        }

        final Directory tempDir = await getTemporaryDirectory();
        imageFile = File('${tempDir.path}/temp_edit_image_${photo.id}.jpg');
        await imageFile.writeAsBytes(response.bodyBytes);
      }

      // Navigasi ke EditForm
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditForm(
              imageFile: imageFile!,
              photoId: photo.id,
              existingImageUrl: photo.file is String ? photo.file : null,
              onImageUploaded: (url) {
                // Callback ketika gambar berhasil diunggah
                if (widget.onPhotoDeleted != null) {
                  widget.onPhotoDeleted!();
                }
                print('Foto berhasil diperbarui: $url');
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Menangani error dan menampilkan pesan ke pengguna
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _onTransformationChange() {
    final scale = transformationController.value.getMaxScaleOnAxis();
    setState(() {
      _isZooming= scale > 1.0;
      pageScrollPhysics = _isZooming
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics();
    });
  }

  void _updateLikeInDatabase(PhotoInfo photo) async {
    try {

      String currentUserId = userId ?? '';

      DocumentReference photoRef = FirebaseFirestore.instance
          .collection('photos')
          .doc(photo.id.toString());

      if (photo.isLiked) {
        await photoRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([currentUserId])
        });
      } else {
        await photoRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([currentUserId])
        });
      }
    } catch (e) {
      print('Error updating like: $e');

      setState(() {
        photo.isLiked = !photo.isLiked;
        photo.likes += photo.isLiked ? 1 : -1;
      });
    }
  }

  void _showCommentSheet() {
    // Pastikan komentar diambil terlebih dahulu
    setState(() {
      _isLoadingComments = true;
    });

    _fetchComments().then((_) {
      setState(() {
        _isLoadingComments = false;
      });

      // Setelah komentar diambil, tampilkan comment sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildCommentsSection(),
      ).then((_) {
        setState(() {
          _isCommentSheetOpen = false;
        });
      });
    });
  }

  void _showRepliesBottomSheet(List<ReplyModel> replies) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: ListView.builder(
            controller: scrollController,
            itemCount: replies.length,
            itemBuilder: (context, index) {
              final reply = replies[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey,
                  backgroundImage: reply.userProfilePic != null
                      ? NetworkImage(reply.userProfilePic!)
                      : null,
                  child: reply.userProfilePic == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                title: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${reply.username} ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: reply.reply,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite_border, color: Colors.white),
                  onPressed: () {
                    // Logika like balasan
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showReplyInputField(int commentId) {
    final replyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Balas Komentar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Tulis balasan...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () async {
                        if (replyController.text.isNotEmpty) {
                          // Tutup bottom sheet terlebih dahulu
                          Navigator.pop(context);

                          // Tampilkan loading indicator
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mengirim balasan...'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          // Kirim balasan
                          await _addReplyToComment(commentId, replyController.text);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendComment() async {
    if (_commentController.text.isEmpty) return;
    if (userIdInt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus login untuk mengirim komentar')),
      );
      return;
    }

    try {
      final photoId = widget.photoInfos[currentIndex].id;

      // Debug log
      print('Sending comment: user_id=$userIdInt, foto_id=$photoId, isi_komentar=${_commentController.text}');

      final response = await http.post(
        Uri.parse('http://10.0.2.2/gallery_api/backend/add_comment.php'),
        body: json.encode({
          'user_id': userIdInt,
          'foto_id': photoId,
          'isi_komentar': _commentController.text,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      // Debug log
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Clear input and refresh comments
          _commentController.clear();

          // Add the new comment to the list immediately for better UX
          if (data['comment'] != null) {
            setState(() {
              _comments.insert(0, CommentModel.fromJson(data['comment']));
            });
          } else {
            // If the comment data isn't returned, just refresh all comments
            _fetchComments();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Komentar berhasil dikirim')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengirim komentar: ${data['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim komentar: Kesalahan server')),
        );
      }
    } catch (e) {
      print('Error posting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim komentar: $e')),
      );
    }
  }

  Future<void> _addReplyToComment(int commentId, String replyText) async {
    if (replyText.isEmpty) return;
    if (userIdInt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus login untuk mengirim balasan')),
      );
      return;
    }

    try {
      // Debug log
      print('Sending reply: user_id=$userIdInt, komentar_id=$commentId, isi_balasan=$replyText');

      final response = await http.post(
        Uri.parse('http://10.0.2.2/gallery_api/backend/add_reply.php'),
        body: json.encode({
          'user_id': userIdInt,
          'komentar_id': commentId,
          'isi_balasan': replyText,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      // Debug log
      print('Reply response status: ${response.statusCode}');
      print('Reply response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Refresh jumlah balasan dan balasan
          await _fetchReplyCount(commentId);
          await _fetchReplies(commentId);

          // Pastikan UI diperbarui dengan menampilkan balasan
          int commentIndex = _comments.indexWhere((comment) => comment.id == commentId);
          if (commentIndex != -1) {
            setState(() {
              _comments[commentIndex].showReplies = true;
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Balasan berhasil dikirim')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengirim balasan: ${data['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim balasan: Kesalahan server')),
        );
      }
    } catch (e) {
      print('Error posting reply: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim balasan: $e')),
      );
    }
  }

  Future<void> _likeComment(CommentModel comment) async {
    if (userIdInt == null) return;

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2/gallery_api/backend/like_comment.php'),
        body: json.encode({
          'user_id': userIdInt,
          'komentar_id': comment.id,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            comment.isLiked = !comment.isLiked;
            comment.likes += comment.isLiked ? 1 : -1;
          });
        }
      }
    } catch (e) {
      print('Error liking comment: $e');
    }
  }

  int _countTotalComments() {
    int totalComments = _comments.length;

    // Tambahkan jumlah balasan dari setiap komentar
    _repliesMap.forEach((commentId, replies) {
      totalComments += replies.length;
    });

    return totalComments;
  }

  void _toggleRepliesImproved(int commentId) async {
    int commentIndex = _comments.indexWhere((comment) => comment.id == commentId);
    if (commentIndex == -1) return;

    // Jika balasan sudah ditampilkan, sembunyikan saja
    if (_comments[commentIndex].showReplies) {
      setState(() {
        _comments[commentIndex].showReplies = false;
      });
      return;
    }

    // Jika balasan belum diambil, tampilkan loading dan ambil balasan
    if (!_repliesMap.containsKey(commentId) || _repliesMap[commentId]!.isEmpty) {
      setState(() {
        _currentLoadingCommentId = commentId;
        _isLoadingCommentReplies = true;
      });

      try {
        await _fetchReplies(commentId);
      } finally {
        // Pastikan loading indicator dihilangkan dan balasan ditampilkan
        setState(() {
          _isLoadingCommentReplies = false;
          _currentLoadingCommentId = null;
          _comments[commentIndex].showReplies = true;
        });
      }
    } else {
      // Jika balasan sudah diambil, tampilkan saja
      setState(() {
        _comments[commentIndex].showReplies = true;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userId = user.uid;

        // Get numeric user ID from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        userIdInt = prefs.getInt('user_id');

        if (userIdInt == null) {
          // If not found in SharedPreferences, try to get it from the database
          final response = await http.get(
            Uri.parse('http://10.0.2.2/gallery_api/backend/get_user_id.php?firebase_uid=${user.uid}'),
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              userIdInt = data['user_id'];
              // Save to SharedPreferences for future use
              await prefs.setInt('user_id', userIdInt!);
            }
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadInitialLikeStatus() async {
    if (userIdInt == null) return;

    try {
      final photoId = widget.photoInfos[currentIndex].id;

      // Gunakan API untuk memeriksa status like
      final isLiked = await _checkPhotoLike(photoId);

      setState(() {
        widget.photoInfos[currentIndex].isLiked = isLiked;
      });

      // Ambil jumlah like terbaru
      await _loadPhotoLikes(photoId);
    } catch (e) {
      print('Error loading like status: $e');
    }
  }

  Future<bool> _checkPhotoLike(int photoId) async {
    if (userIdInt == null) return false;

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2/gallery_api/backend/check_photo_like.php?user_id=$userIdInt&foto_id=$photoId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['liked'] == true;
        }
      }
      return false;
    } catch (e) {
      print('Error checking photo like: $e');
      return false;
    }
  }

  Future<void> _loadPhotoLikes(int photoId) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2/gallery_api/backend/get_photo_likes.php?foto_id=$photoId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            widget.photoInfos[currentIndex].likes = data['like_count'];
          });
        }
      }
    } catch (e) {
      print('Error loading photo likes: $e');
    }
  }

  Future<void> _togglePhotoLike(PhotoInfo photo) async {
    if (userIdInt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus login untuk menyukai foto')),
      );
      return;
    }

    try {
      // Optimistic update untuk UX yang lebih responsif
      setState(() {
        photo.isLiked = !photo.isLiked;
        photo.likes += photo.isLiked ? 1 : -1;
      });

      final response = await http.post(
        Uri.parse('http://10.0.2.2/gallery_api/backend/toggle_photo_like.php'),
        body: json.encode({
          'user_id': userIdInt,
          'foto_id': photo.id,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      print('Toggle like response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Update jumlah like dengan nilai dari server
          if (data['like_count'] != null) {
            setState(() {
              photo.likes = int.parse(data['like_count'].toString());
            });
          }

          // Tampilkan snackbar jika diperlukan
          if (data['action'] == 'liked') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Foto disukai')),
            );
          }
        } else {
          // Jika gagal, kembalikan state
          setState(() {
            photo.isLiked = !photo.isLiked;
            photo.likes += photo.isLiked ? 1 : -1;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: ${data['message']}')),
          );
        }
      } else {
        // Jika gagal, kembalikan state
        setState(() {
          photo.isLiked = !photo.isLiked;
          photo.likes += photo.isLiked ? 1 : -1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyukai foto: Kesalahan server')),
        );
      }
    } catch (e) {
      // Jika error, kembalikan state
      setState(() {
        photo.isLiked = !photo.isLiked;
        photo.likes += photo.isLiked ? 1 : -1;
      });

      print('Error toggling photo like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyukai foto: $e')),
      );
    }
  }

  Future<void> _fetchComments() async {
    if (_isLoadingComments) return;

    setState(() {
      _isLoadingComments = true;
    });

    try {
      final photoId = widget.photoInfos[currentIndex].id;

      // Debug log
      print('Fetching comments for photo ID: $photoId');

      final response = await http.get(
        Uri.parse('http://10.0.2.2/gallery_api/backend/get_comments.php?foto_id=$photoId'),
      );

      // Debug log
      print('Comments response status: ${response.statusCode}');
      print('Comments response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<CommentModel> fetchedComments = [];

          for (var comment in data['comments']) {
            CommentModel commentModel = CommentModel.fromJson(comment);
            fetchedComments.add(commentModel);
          }

          setState(() {
            _comments = fetchedComments;
          });

          // Setelah mendapatkan komentar, ambil jumlah balasan untuk setiap komentar
          for (var comment in _comments) {
            int replyCount = await _fetchReplyCount(comment.id);
            print('Comment ID: ${comment.id} has $replyCount replies');
          }
        }
      }
    } catch (e) {
      print('Error fetching comments: $e');
    } finally {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  Future<int> _fetchReplyCount(int commentId) async {
    try {
      // Debug log
      print('Fetching reply count for comment ID: $commentId');

      final response = await http.get(
        Uri.parse('http://10.0.2.2/gallery_api/backend/get_reply_count.php?komentar_id=$commentId'),
      );

      // Debug log
      print('Reply count response status: ${response.statusCode}');
      print('Reply count response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          int count = data['count'];

          // Debug log
          print('Reply count for comment ID $commentId: $count');

          // Inisialisasi map balasan jika belum ada
          if (!_repliesMap.containsKey(commentId)) {
            setState(() {
              _repliesMap[commentId] = [];
            });
          }

          // Jika ada balasan, pra-ambil balasan
          if (count > 0) {
            // Jika belum ada balasan yang diambil, ambil balasan
            if (_repliesMap[commentId]!.isEmpty) {
              // Ambil balasan secara langsung untuk memastikan data tersedia
              await _fetchReplies(commentId);
            }
          }

          return count;
        }
      }
      return 0;
    } catch (e) {
      print('Error fetching reply count: $e');
      return 0;
    }
  }

  Future<void> _fetchReplies(int commentId) async {
    try {
      // Log untuk debugging
      print('Fetching replies for comment ID: $commentId');

      final response = await http.get(
        Uri.parse('http://10.0.2.2/gallery_api/backend/get_replies.php?komentar_id=$commentId'),
      );

      // Log response untuk debugging
      print('Get replies response status: ${response.statusCode}');
      print('Get replies response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<ReplyModel> fetchedReplies = [];

          for (var reply in data['replies']) {
            ReplyModel replyModel = ReplyModel.fromJson(reply);
            fetchedReplies.add(replyModel);
          }

          // Update state secara global
          setState(() {
            _repliesMap[commentId] = fetchedReplies;
          });

          // Log untuk debugging
          print('Fetched ${fetchedReplies.length} replies for comment ID: $commentId');
          return;
        }
      }

      // Jika gagal, pastikan map tetap ada meskipun kosong
      setState(() {
        if (!_repliesMap.containsKey(commentId)) {
          _repliesMap[commentId] = [];
        }
      });
    } catch (e) {
      print('Error fetching replies: $e');
      // Jika error, pastikan map tetap ada meskipun kosong
      setState(() {
        if (!_repliesMap.containsKey(commentId)) {
          _repliesMap[commentId] = [];
        }
      });
    }
  }

  void _toggleReplies(int commentIndex) {
    setState(() {
      _comments[commentIndex].showReplies = !_comments[commentIndex].showReplies;
      if (_comments[commentIndex].showReplies) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final photoInfo = widget.photoInfos[currentIndex];
    final hasTitleOrDescription = photoInfo.judul?.isNotEmpty == true ||
        photoInfo.deskripsi?.isNotEmpty == true;

    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            currentIndex = index;
          });
          _loadPhotoData();
          _fetchComments(); // Fetch comments for the new photo
        },
        itemCount: widget.photoInfos.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              CustomScrollView(
                physics: _isZooming
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    pinned: true,
                    expandedHeight: 0,
                    leading: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    actions: [
                      if (widget.isOwnPost)
                        PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          color: Colors.grey[900],
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _handleEditOption(widget.photoInfos[currentIndex]);
                                break;
                              case 'delete':
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: Colors.grey[900],
                                    title: const Text(
                                      'Hapus Foto',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    content: const Text(
                                      'Apakah Anda yakin ingin menghapus foto ini?',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Batal'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deletePhoto(photoInfo.id);
                                        },
                                        child: const Text(
                                          'Hapus',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: const [
                                  Icon(Icons.edit, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Edit foto',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: const [
                                  Icon(Icons.delete, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Hapus foto',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        Hero(
                          tag: 'image${currentIndex}',
                          child: _buildMainImage(photoInfo),
                        ),
                        if (_isZooming)
                          Positioned.fill(
                            child: Container(
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context).size.width * 4 / 3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: AnimatedOpacity(
                      opacity: _isZooming ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildActionsBar(photoInfo),
                          if (hasTitleOrDescription) ...[
                            if (photoInfo.judul?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  photoInfo.judul!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (photoInfo.deskripsi?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  photoInfo.deskripsi!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16), // Extra spacing when there's content
                          ],
                          Padding(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              top: hasTitleOrDescription ? 0 : 24,
                            ),
                            child: Text(
                              'More like this',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          if (index >= widget.photoInfos.length) {
                            return null;
                          }
                          return _buildGridItem(widget.photoInfos[index], index);
                        },
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.8,
                      ),
                    ),
                  ),
                  if (isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainImage(PhotoInfo photo) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: _calculateImageHeight(photo, constraints.maxWidth),
          color: Colors.grey[900],
          child: Stack(
            fit: StackFit.expand,
            children: [
              PinchZoomReleaseUnzoomWidget(
                child: photo.file is String
                    ? Image.network(
                  photo.file,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                )
                    : Image.file(
                  photo.file,
                  fit: BoxFit.contain,
                ),
                twoFingersOn: () => setState(() => blockScroll = true),
                twoFingersOff: () => Future.delayed(
                  PinchZoomReleaseUnzoomWidget.defaultResetDuration,
                      () => setState(() => blockScroll = false),
                ),
              ),
              if (!_isZooming && widget.isOwnPost && uploaderUsername != null)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: uploaderPhotoUrl != null
                              ? _getImageProvider(uploaderPhotoUrl!)
                              : null,
                          child: uploaderPhotoUrl == null
                              ? const Icon(Icons.person, size: 20, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          uploaderUsername ?? 'Loading...',  // Tetap menampilkan username pengguna
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3.0,
                                color: Color.fromARGB(150, 0, 0, 0),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionsBar(PhotoInfo photo) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _togglePhotoLike(photo);
                    },
                    icon: Icon(
                      photo.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: photo.isLiked ? Colors.red : Colors.white,
                    ),
                  ),
                  Text(
                    _formatLikes(photo.likes),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isCommentSheetOpen = true;
                      });
                      _showCommentSheet();
                    },
                    icon: const Icon(Icons.comment_outlined, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.share, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    // Gunakan _countTotalComments() di sini
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Komentar ${_countTotalComments()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isLoadingComments
                          ? Center(
                        child: CircularProgressIndicator(
                          color: Colors.grey[400],
                        ),
                      )
                          : _comments.isEmpty
                          ? _buildEmptyCommentState()
                          : ListView.builder(
                        controller: scrollController,
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          return _buildCommentItemDirect(
                              _comments[index],
                              index,
                              scrollController,
                                  (fn) => setSheetState(fn)
                          );
                        },
                      ),
                    ),
                    _buildCommentInputField(),
                  ],
                ),
              );
            },
          );
        }
    );
  }

  Widget _buildEmptyCommentState() {
    return const Center(
      child: Text(
        'Belum ada komentar',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildCommentItemDirect(
      CommentModel comment,
      int commentIndex,
      ScrollController scrollController,
      Function(Function()) setSheetState
      ) {
    // Ambil jumlah balasan dari _repliesMap
    final replyCount = _repliesMap.containsKey(comment.id) ?
    (_repliesMap[comment.id]?.length ?? 0) : 0;

    // Periksa apakah komentar dari pemilik foto
    final bool isPhotoOwner = widget.isOwnPost && comment.userId.toString() == userIdInt.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                backgroundImage: comment.userProfilePic != null
                    ? NetworkImage(comment.userProfilePic!)
                    : null,
                child: comment.userProfilePic == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username dengan label kreator jika pemilik foto
                    Row(
                      children: [
                        Text(
                          comment.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isPhotoOwner)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Kreator',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Isi komentar di baris kedua
                    Text(
                      comment.comment,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          '${DateTime.now().difference(comment.timestamp).inMinutes} menit',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${comment.likes} suka',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            _showReplyInputField(comment.id);
                          },
                          child: const Text(
                            'Balas',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Tampilkan tombol "Lihat balasan" jika ada balasan
                    if (replyCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () async {
                            // Jika balasan sudah ditampilkan, sembunyikan
                            if (comment.showReplies) {
                              setSheetState(() {
                                comment.showReplies = false;
                              });
                              return;
                            }

                            // Tampilkan loading
                            setSheetState(() {
                              _currentLoadingCommentId = comment.id;
                              _isLoadingCommentReplies = true;
                            });

                            // Ambil balasan jika belum ada
                            if (!_repliesMap.containsKey(comment.id) || _repliesMap[comment.id]!.isEmpty) {
                              await _fetchReplies(comment.id);
                            }

                            // Tampilkan balasan dan sembunyikan loading
                            setSheetState(() {
                              _isLoadingCommentReplies = false;
                              _currentLoadingCommentId = null;
                              comment.showReplies = true;
                            });

                            // Pendekatan scrolling yang lebih sederhana
                            // Tunggu sebentar untuk UI diperbarui
                            Future.delayed(Duration(milliseconds: 100), () {
                              // Scroll sedikit ke bawah untuk menampilkan balasan
                              double currentPosition = scrollController.position.pixels;
                              scrollController.animateTo(
                                currentPosition + 10, // Scroll sedikit ke bawah
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            alignment: Alignment.centerLeft,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 24,
                                height: 1.5,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                comment.showReplies
                                    ? 'Sembunyikan balasan'
                                    : 'Lihat $replyCount balasan',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  comment.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: comment.isLiked ? Colors.red : Colors.white,
                ),
                onPressed: () {
                  // Like comment logic
                  _likeComment(comment);
                },
              ),
            ],
          ),

          // Loading indicator
          if (_isLoadingCommentReplies && _currentLoadingCommentId == comment.id)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),

          // Balasan
          if (replyCount > 0 && comment.showReplies)
            Column(
              children: [
                ..._repliesMap[comment.id]?.map((reply) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 48, top: 12),
                    child: _buildReplyItemWithCreatorLabel(reply),
                  );
                }).toList() ?? [],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReplyItemWithCreatorLabel(ReplyModel reply) {
    // Periksa apakah balasan dari pemilik foto
    final bool isPhotoOwner = widget.isOwnPost && reply.userId.toString() == userIdInt.toString();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey,
          backgroundImage: reply.userProfilePic != null
              ? NetworkImage(reply.userProfilePic!)
              : null,
          child: reply.userProfilePic == null
              ? const Icon(Icons.person, color: Colors.white, size: 16)
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Username dengan label kreator jika pemilik foto
              Row(
                children: [
                  Text(
                    reply.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isPhotoOwner)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Kreator',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              // Isi balasan di baris kedua
              Text(
                reply.reply,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${DateTime.now().difference(reply.timestamp).inMinutes} menit',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${reply.likes} suka',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.favorite_border,
            size: 14,
            color: Colors.white,
          ),
          onPressed: () {
            // Like reply logic
          },
        ),
      ],
    );
  }

  Widget _buildCommentInputField() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.grey[900],
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _commentController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tulis Komentar...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              onPressed: _sendComment,
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateImageHeight(PhotoInfo photo, double width) {
    return width * (4 / 3);
  }

  String _formatLikes(int likes) {
    if (likes >= 1000000) {
      double m = likes / 1000000;
      return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}m';
    } else if (likes >= 1000) {
      double k = likes / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    }
    return likes.toString();
  }

  Widget _buildGridItem(PhotoInfo photo, int index) {
    return GestureDetector(
      onTap: (){
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DetailFotoPostingScreen(
              photoInfos: widget.photoInfos,
              initialIndex: index,
              onLoadMore: (int page) async {

              },
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Color(0xFF1E1E1E),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            photo.file is String
                ? Image.network(
              photo.file,
              fit: BoxFit.cover,
            )
                : Image.file(
              photo.file,
              fit: BoxFit.cover,
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Row(
                  children: [
                    Icon(
                      photo.isLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color:
                      photo.isLiked
                          ? Colors.red
                          : Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatLikes(photo.likes),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12
                      ),
                    ),
                  ]
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getImageProvider(String photoUrl) {
    try {
      if (photoUrl.startsWith('data:image')) {
        String base64Image = photoUrl.split(',')[1];
        return MemoryImage(base64Decode(base64Image));
      } else if (photoUrl.startsWith('http')) {
        return NetworkImage(photoUrl);
      } else if (photoUrl.startsWith('uploads/')) {
        String fullUrl = 'http://10.0.2.2/gallery_api/backend/$photoUrl';
        return NetworkImage(fullUrl);
      }
    } catch (e) {
      print('Error loading image provider: $e');
    }
    return null;
  }
}