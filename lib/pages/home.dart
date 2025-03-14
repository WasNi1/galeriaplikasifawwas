import 'dart:convert';
import 'dart:io';
import 'package:aplikasi_galeri_baru/controllers/sync_scroll_controller.dart';
import 'package:aplikasi_galeri_baru/foto_screen/detail_foto_profil_screen.dart';
import 'package:aplikasi_galeri_baru/foto_screen/detail_foto_screen.dart';
import 'package:aplikasi_galeri_baru/pages/disimpan_pages.dart';
import 'package:aplikasi_galeri_baru/pages/postingan_pages.dart';
import 'package:aplikasi_galeri_baru/pages/search_pages.dart';
import 'package:aplikasi_galeri_baru/pages/upload_form.dart';
import 'package:aplikasi_galeri_baru/widget/dialog_foto.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aplikasi_galeri_baru/pages/profil_pages.dart';
import 'package:aplikasi_galeri_baru/pages/foto_pages.dart';
import 'package:image_picker/image_picker.dart';
import 'account_pages.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  bool _isLoadingProfilePhoto = true;
  bool _hasLoadedOnce = false;
  bool _showProfileSelection = true;
  String username = '';
  String? profilePhotoUrl;
  int currentTab = 0;
  late TabController _tabController;
  final List<Widget> screens = [
    const FotoPages(),
    const Profil(),
  ];

  String? userId;
  Future<void>? _userDataFuture;
  ImageProvider? _cachedImageProvider;
  final ScrollController _mainScrollController = ScrollController();
  late final ScrollController _postinganScrollController;
  late final ScrollController _disimpanScrollController;
  bool _isAppBarExpanded = true;


  @override
  void initState() {
    super.initState();
    _userDataFuture = _getUserData();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);

    FirebaseAuth.instance.authStateChanges().listen((User? user){
      if (user != null) {
        _refreshData();
      }
    });
    _initializeProfilePhoto();

    _postinganScrollController = SyncScrollController(parentController: _mainScrollController);
    _disimpanScrollController = SyncScrollController(parentController: _mainScrollController);
    _mainScrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final bool isExpanded = _mainScrollController.offset < 200; // threshold untuk collapse/expand
    if (_isAppBarExpanded != isExpanded) {
      setState(() {
        _isAppBarExpanded = isExpanded;
      });
    }
  }

  ImageProvider? _getImageProvider() {
    if (_cachedImageProvider != null) return _cachedImageProvider;

    if (profilePhotoUrl != null) {
      try {
        if (profilePhotoUrl!.startsWith('data:image')) {
          String base64Image = profilePhotoUrl!.split(',')[1];
          _cachedImageProvider = MemoryImage(base64Decode(base64Image));
        } else if (profilePhotoUrl!.startsWith('http')) {
          _cachedImageProvider = NetworkImage(profilePhotoUrl!);
        } else if (profilePhotoUrl!.startsWith('uploads/')) {
          String fullUrl = 'http://10.0.2.2/gallery_api/backend/${profilePhotoUrl!}';
          _cachedImageProvider = NetworkImage(fullUrl);
        }
        return _cachedImageProvider;
      } catch (e) {
        print('Error loading image: $e');
      }
    }
    return null;
  }

  Future<void> _initializeProfilePhoto() async {
    if (!_hasLoadedOnce) {
      setState(() => _isLoadingProfilePhoto = true);

      await Future.delayed(const Duration(seconds: 2));

      await _getUserData();

      if (mounted) {
        setState(() {
          _isLoadingProfilePhoto = false;
          _hasLoadedOnce = true;
        });
      }
    }
  }

  Future<void> _getUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userId = user.uid;
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          username = userData['username'] ?? 'User';
          profilePhotoUrl = userData['base64PhotoURL'] ?? userData['photoURL'];
          _cachedImageProvider = null;
        }
      }
    } catch (e) {
      print('Error getting user data: $e');
      // Don't rethrow - we'll handle the error state in the FutureBuilder
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _mainScrollController.dispose();
    _postinganScrollController.dispose();
    _disimpanScrollController.dispose();
    super.dispose();
  }

  Widget _buildProfilePhoto() {
    final imageProvider = _getImageProvider();

    return GestureDetector(
      onTap: () {
        if (profilePhotoUrl != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailFotoProfilScreen(
                imageUrl: profilePhotoUrl!,
              ),
            ),
          );
        }
      },
      child: Container(
        width: 110, // Ukuran container tetap
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: imageProvider != null
            ? CircleAvatar(
          radius: 55,
          backgroundImage: imageProvider,
        )
            : Center( // Gunakan Center untuk memastikan icon berada di tengah
          child: Icon(
            Icons.account_circle,
            size: 110, // Sesuaikan dengan ukuran container
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavProfileIcon() {
    if (_isLoadingProfilePhoto) {
      return SizedBox(
        width: 35,
        height: 35,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
        ),
      );
    }

    final imageProvider = _getImageProvider();
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: currentTab == 1
            ? Border.all(color: Colors.red, width: 2)
            : null,
      ),
      child: imageProvider != null
          ? CircleAvatar(
        radius: 17.5,
        backgroundColor: Colors.transparent,
        backgroundImage: imageProvider,
      )
          : _buildDefaultProfileIcon(),
    );
  }


  Widget _buildDefaultProfileIcon() {
    return CircleAvatar(
      radius: 17.5,
      backgroundColor: Colors.transparent,
      child: Icon(
        Icons.account_circle,
        size: 35,
        color: currentTab == 1 ? Colors.white : Colors.grey,
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.red, size: 30),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        _isLoadingProfilePhoto = true;
        _cachedImageProvider = null;
      });

      // Simulate 2 second loading time
      await Future.delayed(const Duration(seconds: 2));

      await _getUserData();

      if (mounted) {
        setState(() {
          _isLoadingProfilePhoto = false;
        });
      }
    }
  }

  Future<void> _navigateToAccount() async {
    if (userId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountPages(
            onProfileUpdated: () {
              _refreshData();
            }
        ),
      ),
    );
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  void _updateHomeScreen() {
    setState(() {
      _cachedImageProvider = null;
      _userDataFuture = _getUserData();
    });
  }

  void _getFromCamera() async {
    XFile? pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      if (context.mounted) {
        Navigator.pop(context);
        await Navigator.push(
            context, MaterialPageRoute(
            builder: (context) => UploadForm(
                imageFile: imageFile,
                onImageUploaded: (String url) {
                  _refreshData();
                }
            )
        )
        );
      }
    } else {
      Navigator.pop(context);
    }
  }

  void _getFromGallery() async {
    XFile? pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      if (context.mounted);
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => UploadForm(
                  imageFile: imageFile,
                  onImageUploaded: (String url) {
                    _refreshData();
                  }
              )
          )
      );
    }
  }

  PreferredSizeWidget _buildAppBar() {
    if (currentTab == 0) {
      return AppBar(
        elevation: 4,
        backgroundColor: const Color(0xFF1E1E1E), // Warna gelap modern
        centerTitle: true,
        title: const Text(
          'Home',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto', // Ganti dengan font modern
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchPages(),
                ),
              );
            },
          ),
        ],
      );
    } else {
      return AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentTab == 0) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: screens[currentTab],
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        controller: _mainScrollController,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              elevation: 4,
              backgroundColor: const Color(0xFF1E1E1E),
              expandedHeight: 355,
              collapsedHeight: 60,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: _navigateToAccount,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () {
                    // Implement share functionality
                  },
                ),
              ],
              flexibleSpace: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double expandRatio = (constraints.maxHeight - 60) / (355 - 60);
                  final double opacity = expandRatio.clamp(0.0, 1.0);

                  return FlexibleSpaceBar(
                    background: Container(
                      color: const Color(0xFF1E1E1E),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 50),
                          _buildProfilePhoto(),
                          const SizedBox(height: 16),
                          Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '@${username.toLowerCase()}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    centerTitle: true,
                    titlePadding: EdgeInsets.zero,
                    title: Opacity(
                      opacity: 1 - opacity,
                      child: Container(
                        width: double.infinity,
                        color: const Color(0xFF1E1E1E),
                        child: Center(
                          child: Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Diposting'),
                  Tab(text: 'Disimpan'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            PostinganPages(scrollController: _postinganScrollController),
            DisimpanPages(scrollController: _disimpanScrollController),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }


  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF1E1E1E),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, // 1. Gunakan spaceAround
          children: [
            // Tombol Home
            MaterialButton(
              minWidth: 40,
              onPressed: () {
                setState(() {
                  currentTab = 0;
                });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home,
                    size: 35,
                    color: currentTab == 0 ? Colors.white : Colors.grey,
                  ),
                ],
              ),
            ),

            DialogFoto(
                onImageSelected: (File imageFile) {

                },
                onImageUploaded: (String url) {
                  _refreshData();
                },
                onNewPhotoAdded: (String url) {
                  _refreshData();
                },
                size: 45
            ),

            // Tombol Profil
            MaterialButton(
              minWidth: 40,
              onPressed: () {
                setState(() {
                  currentTab = 1;
                });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBottomNavProfileIcon(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}