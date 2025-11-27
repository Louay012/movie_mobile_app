import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../utils/validators.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _database = DatabaseService();
  final _storage = StorageService();

  final _nameCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  
  DateTime? _selectedBirthDate;

  XFile? _selectedImage;
  Uint8List? _webImageBytes;
  String? _currentBase64Image;

  bool _loading = true;
  bool _updating = false;
  bool _uploadingImage = false;
  bool _isEditing = false;

  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _birthDateCtrl.addListener(_onDateInputChanged);
  }

  void _onDateInputChanged() {
    final text = _birthDateCtrl.text;
    final parsedDate = FormValidators.parseDateFromDDMMYYYY(text);
    if (parsedDate != null && parsedDate != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = parsedDate;
      });
    }
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
            _selectedBirthDate = userData.birthDate;
            _birthDateCtrl.text = DateFormat('dd/MM/yyyy').format(userData.birthDate);
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

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select your birth date',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      
      if (picked != null) {
        Uint8List imageBytes;
        if (kIsWeb) {
          imageBytes = await picked.readAsBytes();
        } else {
          imageBytes = await File(picked.path).readAsBytes();
        }

        final imageInfo = await _storage.getImageInfo(imageBytes);
        
        if (imageInfo.containsKey('error')) {
          _showError('Failed to read image: ${imageInfo['error']}');
          return;
        }

        final isValid = imageInfo['isValid'] as bool;
        final formattedSize = imageInfo['formattedSize'] as String;

        if (!isValid) {
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
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _updateProfile() async {
    if (_currentUser == null) return;
    
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedBirthDate == null) {
      _showError('Please Enter Your Birth Date');
      return;
    }

    final age = _calculateAge(_selectedBirthDate!);
    if (age < 13) {
      _showError('You Must Be At Least 13 Years Old');
      return;
    }

    setState(() => _updating = true);

    try {
      String? base64Image = _currentBase64Image;

      if (_selectedImage != null) {
        setState(() => _uploadingImage = true);
        
        try {
          final imageData = kIsWeb ? _webImageBytes! : File(_selectedImage!.path);
          base64Image = await _storage.imageToBase64(imageData, autoCompress: true);
          
          if (base64Image == null) {
            _showError('Failed to process image. Please try a different image.');
            setState(() => _uploadingImage = false);
            return;
          }
        } on StorageServiceException catch (e) {
          _showError(e.message);
          setState(() {
            _uploadingImage = false;
            _updating = false;
          });
          return;
        } catch (e) {
          _showError('Failed to process image: ${e.toString()}');
          setState(() {
            _uploadingImage = false;
            _updating = false;
          });
          return;
        } finally {
          if (mounted) setState(() => _uploadingImage = false);
        }
      }

      final user = _auth.currentUser;
      if (user != null) {
        await _auth.updateProfile(
          user: user,
          displayName: _nameCtrl.text.trim(),
          photoURL: base64Image,
        );
      }

      final updateData = {
        'fullName': _nameCtrl.text.trim(),
        'birthDate': _selectedBirthDate!.toIso8601String(),
        'age': _calculateAge(_selectedBirthDate!),
        if (base64Image != null) 'photoURL': base64Image,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final saved = await _database.updateUser(_currentUser!.uid, updateData);
      if (!saved) {
        _showError('Failed to update profile');
        return;
      }

      setState(() {
        _currentBase64Image = base64Image;
        _selectedImage = null;
        _webImageBytes = null;
        _isEditing = false;
        _currentUser = UserModel(
          uid: _currentUser!.uid,
          fullName: _nameCtrl.text.trim(),
          birthDate: _selectedBirthDate!,
          email: _currentUser!.email,
          photoURL: base64Image,
          createdAt: _currentUser!.createdAt,
        );
      });

      _showSuccess('Profile updated successfully');
    } catch (e) {
      _showError('Failed to update profile: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      _showError('Failed to sign out: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
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
    if (!mounted) return;
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
    ImageProvider? imageProvider;
    
    if (_webImageBytes != null) {
      imageProvider = MemoryImage(_webImageBytes!);
    } else if (_selectedImage != null && !kIsWeb) {
      imageProvider = FileImage(File(_selectedImage!.path));
    } else if (_currentBase64Image != null && _currentBase64Image!.isNotEmpty) {
      try {
        final bytes = base64Decode(_currentBase64Image!);
        imageProvider = MemoryImage(bytes);
      } catch (e) {
        imageProvider = null;
      }
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.amber.shade600, Colors.orange.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey.shade800,
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? Icon(Icons.person, size: 50, color: Colors.grey.shade400)
                : null,
          ),
          if (_isEditing)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _uploadingImage ? null : _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: _uploadingImage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _birthDateCtrl.removeListener(_onDateInputChanged);
    _nameCtrl.dispose();
    _birthDateCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.black,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              _buildProfileImage(),
              
              const SizedBox(height: 16),
              
              if (!_isEditing && _currentUser != null) ...[
                Text(
                  _currentUser!.fullName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (_selectedBirthDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_calculateAge(_selectedBirthDate!)} years old',
                      style: TextStyle(
                        color: Colors.amber.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  _currentUser!.email,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 30),
                
                // Account Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildInfoRow(Icons.person_outline, 'Full Name', _currentUser!.fullName),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.email_outlined, 'Email', _currentUser!.email),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.cake_outlined, 'Birth Date', DateFormat('dd/MM/yyyy').format(_selectedBirthDate!)),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.calendar_today_outlined, 'Member Since', DateFormat('MMM dd, yyyy').format(_currentUser!.createdAt!)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              
              if (_isEditing) ...[
                const SizedBox(height: 30),
                
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.person_outline, color: Colors.amber.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.amber.shade600, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please Enter Your Name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _birthDateCtrl,
                  decoration: InputDecoration(
                    labelText: 'Birth Date',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.cake_outlined, color: Colors.amber.shade600),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.calendar_today, color: Colors.grey.shade500),
                      onPressed: _selectBirthDate,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.amber.shade600, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    hintText: 'dd/mm/yyyy',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    helperText: _selectedBirthDate != null 
                        ? 'Age: ${_calculateAge(_selectedBirthDate!)} years old'
                        : null,
                    helperStyle: TextStyle(color: Colors.amber.shade400),
                  ),
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.datetime,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please Enter Your Birth Date';
                    }
                    final parsedDate = FormValidators.parseDateFromDDMMYYYY(value);
                    if (parsedDate == null) {
                      return 'Invalid Date Format';
                    }
                    final age = _calculateAge(parsedDate);
                    if (age < 13) {
                      return 'You Must Be At Least 13 Years Old';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailCtrl,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade800),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade900.withOpacity(0.5),
                    helperText: 'Email cannot be changed',
                    helperStyle: TextStyle(color: Colors.grey.shade600),
                  ),
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _updating ? null : () {
                          setState(() {
                            _isEditing = false;
                            _selectedImage = null;
                            _webImageBytes = null;
                            if (_currentUser != null) {
                              _nameCtrl.text = _currentUser!.fullName;
                              _selectedBirthDate = _currentUser!.birthDate;
                              _birthDateCtrl.text = DateFormat('dd/MM/yyyy').format(_currentUser!.birthDate);
                            }
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: BorderSide(color: Colors.grey.shade600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_updating || _uploadingImage) ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.amber.shade600,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _updating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber.shade600, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
