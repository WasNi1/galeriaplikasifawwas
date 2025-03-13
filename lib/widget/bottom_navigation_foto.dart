import 'dart:async';

import 'package:aplikasi_galeri_baru/foto_screen/detail_foto_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BottomNavigationFoto extends StatefulWidget {
  final int photoId;
  final Function onPhotoDeleted;

  const BottomNavigationFoto({
    super.key,
    required this.photoId,
    required this.onPhotoDeleted,
  });

  @override
  State<BottomNavigationFoto> createState() => _BottomNavigationFotoState();
}

class _BottomNavigationFotoState extends State<BottomNavigationFoto> {
  int _selectedIndex = 0;
  bool isFavorite = false;

  Future<void> _deletePhoto() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated')),
          );
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );
      }

      final response = await http.post(
        Uri.parse('http://10.0.2.2/gallery_api/backend/move_to_trash.php'),
        body: {
          'firebase_uid': user.uid,
          'foto_id': widget.photoId.toString(),
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (mounted) {
        Navigator.pop(context);
      }

      if (response.statusCode == 200) {
        if (response.body.trim().startsWith('{')) {
          try {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              widget.onPhotoDeleted();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(data['message'] ?? 'Failed to delete photo')),
                );
              }
            }
          } catch (e) {
            print('JSON parsing error: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid server response format')),
              );
            }
          }
        } else {
          print('Invalid response format: ${response.body}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Server returned invalid response format')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('Error deleting photo: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e is TimeoutException ? 'Request timed out' : 'Network error occurred'}')),
        );
      }
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Apakah anda ingin menghapus fotonya?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 35),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Tidak",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                          ),
                          onPressed: () {
                            _deletePhoto();
                          },
                          child: const Text(
                            "Ya",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        isFavorite = !isFavorite;
        print('Favorit status: ${isFavorite ? 'aktif' : 'nonaktif'}');
      }
    });

    switch (index) {
      case 0:
        print('Bagikan dipilih');
        break;
      case 2:
        _showDeleteDialog(context);
        break;
      case 3:
        print('Selengkapnya dipilih');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.black.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildIconButtonWithLabel(
            icon: Icons.share,
            label: 'Bagikan',
            onTap: () => _onItemTapped(0),
          ),
          _buildIconButtonWithLabel(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border_outlined,
            label: 'Favorit',
            onTap: () => _onItemTapped(1),
            iconColor: isFavorite ? Colors.red : Colors.white,
          ),
          _buildIconButtonWithLabel(
            icon: Icons.delete,
            label: 'Hapus',
            onTap: () => _onItemTapped(2),
          ),
          _buildIconButtonWithLabel(
            icon: Icons.keyboard_control,
            label: 'Selengkapnya',
            onTap: () => _onItemTapped(3),
          ),

        ],
      ),
    );
  }

  Widget _buildIconButtonWithLabel({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor ?? Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
