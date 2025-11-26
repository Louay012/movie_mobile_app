// lib/screens/profile_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';
import 'login.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _database = DatabaseService();
  final _storage = StorageService();

  UserModel? _currentUser;
  bool _loading = true;
  bool _editing = false;
  bool _uploadingImage = false;

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  XFile? _selectedImage;
  Uint8List? _webImageBytes;
  String? _currentBase64Image;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userData = await _database.getUser(user.uid);
        if (userData != null) {
          setState(() {
            _currentUser = userData;
            _nameCtrl.text = userData.fullName;
            _ageCtrl.text = userData.age.toString();
            _emailCtrl.text = userData.email;
            _currentBase64Image = userData.photoURL;
          });
        }
      }
    } catch (e) {
      _showError('Failed to load user data: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024, // Limit dimensions to reduce size
        maxHeight: 1024,
        imageQuality: 85, // Good quality but compressed
      );
      
      if (picked != null) {
        // Get image bytes
        Uint8List imageBytes;
        if (kIsWeb) {
          imageBytes = await picked.readAsBytes();
        } else {
          imageBytes = await File(picked.path).readAsBytes();
        }

        // Validate image size before showing
        final imageInfo = await _storage.getImageInfo(imageBytes);
        
        if (imageInfo.containsKey('error')) {
          _showError('Failed to read image: ${imageInfo['error']}');
          return;
        }

        final sizeKB = imageInfo['sizeKB'] as int;
        final isValid = imageInfo['isValid'] as bool;
        final formattedSize = imageInfo['formattedSize'] as String;

        print('Selected image: $formattedSize');

        if (!isValid) {
          // Show size warning but allow selection (will compress later)
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Large Image'),
              content: Text(
                'The selected image is $formattedSize. '
                'We\'ll try to compress it to fit the ${StorageService.maxImageSizeKB}KB limit.\n\n'
                'Continue?'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Compress & Use'),
                ),
              ],
            ),
          );

          if (shouldContinue != true) return;
        }

        setState(() {
          _selectedImage = picked;
          _webImageBytes = imageBytes;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _updateProfile() async {
    if (_currentUser == null) return;

    setState(() => _loading = true);

    try {
      String? base64Image = _currentBase64Image;

      // Process new image if selected
      if (_selectedImage != null) {
        setState(() => _uploadingImage = true);
        
        try {
          final imageData = kIsWeb ? _webImageBytes! : File(_selectedImage!.path);
          
          // This will validate, compress if needed, and convert to base64
          base64Image = await _storage.imageToBase64(imageData, autoCompress: true);
          
          if (base64Image == null) {
            _showError('Failed to process image. Please try a different image.');
            setState(() => _uploadingImage = false);
            return;
          }

          print('Image processed successfully');
          
        } on StorageServiceException catch (e) {
          // Handle storage-specific errors with user-friendly messages
          _showError(e.message);
          setState(() {
            _uploadingImage = false;
            _loading = false;
          });
          return;
        } catch (e) {
          _showError('Failed to process image: ${e.toString()}');
          setState(() {
            _uploadingImage = false;
            _loading = false;
          });
          return;
        } finally {
          if (mounted) setState(() => _uploadingImage = false);
        }
      }

      // Update Firebase Auth profile
      final user = _auth.currentUser;
      if (user != null) {
        await _auth.updateProfile(
          user: user,
          displayName: _nameCtrl.text.trim(),
          photoURL: base64Image,
        );
      }

      // Update Firestore
      final updateData = {
        'fullName': _nameCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text.trim()) ?? _currentUser!.age,
        if (base64Image != null) 'photoURL': base64Image,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final saved = await _database.updateUser(_currentUser!.uid, updateData);
      if (!saved) {
        _showError('Failed to update profile');
        return;
      }

      // Update local user model
      setState(() {
        _currentUser = _currentUser!.copyWith(
          fullName: _nameCtrl.text.trim(),
          age: int.tryParse(_ageCtrl.text.trim()) ?? _currentUser!.age,
          photoURL: base64Image,
        );
        _editing = false;
        _selectedImage = null;
        _webImageBytes = null;
      });

      _showSuccess('Profile updated successfully');
    } on DatabaseServiceException catch (e) {
      // Handle database-specific errors
      if (e.message.contains('longer than')) {
        _showError(
          'Image is too large for storage. Please choose a smaller image or lower quality photo.'
        );
      } else {
        _showError(e.message);
      }
    } catch (e) {
      _showError('Update failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildProfileImage() {
    final hasImage = _currentBase64Image != null && _currentBase64Image!.isNotEmpty;
    final hasNewImage = _selectedImage != null;

    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey.shade800,
          backgroundImage: hasNewImage
              ? (kIsWeb
              ? MemoryImage(_webImageBytes!)
              : FileImage(File(_selectedImage!.path)) as ImageProvider)
              : (hasImage
              ? MemoryImage(base64Decode(_currentBase64Image!))
              : null),
          child: !hasImage && !hasNewImage
              ? const Icon(Icons.person, size: 50, color: Colors.white54)
              : null,
        ),
        if (_editing && !_uploadingImage)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.amber.shade600,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                onPressed: _pickImage,
              ),
            ),
          ),
        if (_uploadingImage)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (!_editing && _currentUser != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            ),
          if (_editing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _editing = false;
                  _selectedImage = null;
                  _webImageBytes = null;
                  _loadUserData(); // Reset form
                });
              },
            ),
        ],
      ),
      body: _loading && _currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Image
            _buildProfileImage(),

            // Image size info when editing
            if (_editing) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade700),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Max image size: ${StorageService.maxImageSizeKB}KB. Large images will be compressed automatically.',
                        style: TextStyle(
                          color: Colors.blue.shade100,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // User Info Form
            Form(
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    enabled: _editing,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: !_editing,
                      fillColor: Colors.grey.shade900,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _ageCtrl,
                    enabled: _editing,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Age',
                      prefixIcon: const Icon(Icons.cake),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: !_editing,
                      fillColor: Colors.grey.shade900,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailCtrl,
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade900,
                    ),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            if (_editing) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.amber.shade600,
                    foregroundColor: Colors.black,
                  ),
                  child: _loading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                      : const Text('Save Changes', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Account Stats
            if (!_editing && _currentUser != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Info',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Member since: ${_currentUser!.createdAt != null ? _formatDate(_currentUser!.createdAt!) : 'N/A'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'User ID: ${_currentUser!.uid.substring(0, 8)}...',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _signOut,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(color: Colors.red.shade400),
                  foregroundColor: Colors.red.shade400,
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }
}