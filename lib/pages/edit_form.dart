import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class EditForm extends StatefulWidget {
  final File? imageFile;
  final Function(String) onImageUploaded;
  final int? photoId;
  final String? existingImageUrl;

  const EditForm({
    Key? key,
    this.imageFile,
    required this.onImageUploaded,
    this.photoId,
    this.existingImageUrl,
  }) : super(key: key);

  @override
  State<EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<EditForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  bool _isLoading = false;
  bool _isLoadingPhotoData = false;
  bool _isPublic = true;
  String? _imageUrl;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _imageFile = widget.imageFile;
    _imageUrl = widget.existingImageUrl;

    // If photoId is available, this is edit mode, so load photo data
    if (widget.photoId != null) {
      _loadPhotoData();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // Function to fetch photo data from the backend
  // Function to fetch photo data from the backend
  Future<void> _loadPhotoData() async {
    if (widget.photoId == null) return;

    setState(() => _isLoadingPhotoData = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final url = 'http://10.0.2.2/gallery_api/backend/get_photo_details.php?photo_id=${widget.photoId.toString()}&firebase_uid=${user.uid}';
      print('Making request to: $url');

      final response = await http.get(Uri.parse(url));

      print('Response status code: ${response.statusCode}');
      print('Raw response: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          print('Successfully parsed JSON: $data');

          if (data['success'] == true) {
            final photoData = data['photo'];

            setState(() {
              _titleController.text = photoData['JudulFoto'] ?? '';
              _descriptionController.text = photoData['DeskripsiFoto'] ?? '';
              _isPublic = (photoData['privacy'] ?? 'public') == 'public';
              _imageUrl = photoData['LokasiFile'];

              if (photoData['Tags'] != null) {
                _tags.clear();
                String tagsString = photoData['Tags'].toString();
                if (tagsString.isNotEmpty) {
                  final tagsList = tagsString.split(',');
                  _tags.addAll(tagsList.map((tag) => tag.trim()).toList());
                }
              }
            });
          } else {
            throw Exception(data['message'] ?? 'Failed to load photo data');
          }
        } catch (parseError) {
          print('Full response that caused error: ${response.body}');
          throw Exception('JSON parse error: $parseError');
        }
      } else {
        print('Full error response: ${response.body}');
        throw Exception('HTTP error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        print('Error in _loadPhotoData: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading photo data: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPhotoData = false);
      }
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _uploadPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2/gallery_api/backend/edit.php'),
      );

      // Only add the image file if there's a new file
      if (_imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          _imageFile!.path,
        ));
      }

      request.fields.addAll({
        'firebase_uid': user.uid,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'privacy': _isPublic ? 'public' : 'private',
        'tags': _tags.join(','),
      });

      // Add photo_id if in edit mode
      if (widget.photoId != null) {
        request.fields['photo_id'] = widget.photoId.toString();
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 200 && jsonResponse['success']) {
        widget.onImageUploaded(jsonResponse['url'] ?? _imageUrl ?? '');
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Foto berhasil diedit'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        throw Exception(jsonResponse['message'] ?? 'Upload failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Post',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: _isLoadingPhotoData
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _imageFile != null
                      ? Image.file(
                    _imageFile!,
                    height: 250,
                    fit: BoxFit.cover,
                  )
                      : _imageUrl != null
                      ? Image.network(
                    _imageUrl!,
                    height: 250,
                    fit: BoxFit.cover,
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
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 250,
                        color: Colors.grey[300],
                        child: Center(
                          child: Text('Failed to load image'),
                        ),
                      );
                    },
                  )
                      : Container(
                    height: 250,
                    color: Colors.grey[300],
                    child: Center(
                      child: Text('No Image Selected'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter your title',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).primaryColor),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter your description',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).primaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tagController,
                        decoration: InputDecoration(
                          labelText: 'Tags',
                          hintText: 'Add tags',
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Theme.of(context).primaryColor),
                          ),
                        ),
                        onEditingComplete: _addTag,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addTag,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Tags Display
                if (_tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: _tags.map((tag) => Chip(
                      label: Text(tag),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => _removeTag(tag),
                    )).toList(),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Make Post Public',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: _isPublic,
                        onChanged: (bool value) {
                          setState(() {
                            _isPublic = value;
                          });
                        },
                        activeColor: Theme.of(context).primaryColor,
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _uploadPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                      'Save',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}