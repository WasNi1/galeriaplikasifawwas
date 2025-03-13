import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UploadForm extends StatefulWidget {
  final File imageFile;
  final Function(String) onImageUploaded;

  const UploadForm({
    Key? key,
    required this.imageFile,
    required this.onImageUploaded,
  }) : super(key: key);

  @override
  State<UploadForm> createState() => _UploadFormState();
}

class _UploadFormState extends State<UploadForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String>_tags = [];
  bool _isLoading = false;
  bool _isPublic = true;
  String _errorMessage = '';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
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

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check file size before uploading
      final fileSize = await widget.imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('File is too large. Maximum size is 5MB.');
      }

      // Updated URL - ensure this is correct
      final apiUrl = 'http://10.0.2.2/gallery_api/backend/upload.php';

      // Create the request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(apiUrl),
      );

      // Add timeout
      request.headers['Connection'] = 'keep-alive';

      // Add the file
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        widget.imageFile.path,
      ));

      // Add other fields
      request.fields.addAll({
        'firebase_uid': user.uid,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'privacy': _isPublic ? 'public' : 'private',
        'tags': _tags.join(','),
      });

      // For debugging
      print('Sending request to: $apiUrl');
      print('Fields: ${request.fields}');

      // Send the request with a timeout
      var response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out. Please try again.');
        },
      );

      // Read response
      var responseData = await response.stream.bytesToString();

      // Debug logging
      print('Response status: ${response.statusCode}');
      print('Response body: $responseData');

      // Handle empty response
      if (responseData.isEmpty) {
        throw Exception('Empty response from server. Check server logs.');
      }

      // Parse JSON response
      try {
        var jsonResponse = json.decode(responseData);

        if (response.statusCode == 200 && jsonResponse['success'] == true) {
          // Success - pass the URL back
          widget.onImageUploaded(jsonResponse['url']);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post uploaded successfully')),
            );
          }
        } else {
          // Server returned error
          String errorMsg = jsonResponse['message'] ?? 'Upload failed';
          throw Exception(errorMsg);
        }
      } catch (jsonError) {
        // JSON parsing error
        throw Exception('Invalid server response: $jsonError. Response: $responseData');
      }
    } on SocketException catch (e) {
      // Network error
      setState(() {
        _errorMessage = 'Network error: ${e.message}. Check your connection and server.';
      });
    } on TimeoutException catch (_) {
      setState(() {
        _errorMessage = 'Request timed out. Server might be unavailable.';
      });
    } catch (e) {
      // Other errors
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Post',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    widget.imageFile,
                    height: 250,
                    fit: BoxFit.cover,
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

                // Error message display
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[300]!),
                      ),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red[800]),
                      ),
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
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontSize: 15),
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

// Custom exception class
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}