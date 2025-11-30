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

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
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
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
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
            _birthDateCtrl.text = DateFormat(
              'dd/MM/yyyy',
            ).format(userData.birthDate);
            _emailCtrl.text = userData.email;
            _currentBase64Image = userData.photoURL;
          });
          _animationController.forward();
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.deepPurpleAccent,
              onPrimary: Colors.white,
              surface: const Color(0xFF302B63),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF24243E),
          ),
          child: child!,
        );
      },
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
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

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
              backgroundColor: const Color(0xFF302B63),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Large Image',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'The selected image is $formattedSize. '
                'We\'ll try to compress it to fit the ${StorageService.maxImageSizeKB}KB limit.\n\n'
                'Continue?',
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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
          final imageData = kIsWeb
              ? _webImageBytes!
              : File(_selectedImage!.path);
          base64Image = await _storage.imageToBase64(
            imageData,
            autoCompress: true,
          );

          if (base64Image == null) {
            _showError(
              'Failed to process image. Please try a different image.',
            );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF302B63),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _auth.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        _showError('Failed to sign out: $e');
      }
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
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.deepPurpleAccent, Colors.purple.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white, width: 4),
        ),
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade800,
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white.withOpacity(0.7),
                    )
                  : null,
            ),
            if (_isEditing)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _uploadingImage ? null : _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurpleAccent,
                          Colors.purple.shade600,
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurpleAccent.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _uploadingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
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
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0F0C29),
                const Color(0xFF302B63),
                const Color(0xFF24243E),
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
            ),
          ),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0C29),
              const Color(0xFF302B63),
              const Color(0xFF24243E),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildProfileImage(),
                    const SizedBox(height: 20),

                    if (!_isEditing && _currentUser != null) ...[
                      Text(
                        _currentUser!.fullName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedBirthDate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurpleAccent.withOpacity(0.3),
                                Colors.purple.withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.deepPurpleAccent.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cake,
                                color: Colors.deepPurpleAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_calculateAge(_selectedBirthDate!)} years old',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),

                      const SizedBox(height: 30),

                      // Account Info Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.deepPurpleAccent.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurpleAccent.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.deepPurpleAccent,
                                        Colors.purple.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Account Information',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildInfoRow(
                              Icons.person_outline,
                              'Full Name',
                              _currentUser!.fullName,
                            ),
                            const SizedBox(height: 18),
                            _buildInfoRow(
                              Icons.email_outlined,
                              'Email',
                              _currentUser!.email,
                            ),
                            const SizedBox(height: 18),
                            _buildInfoRow(
                              Icons.cake_outlined,
                              'Birth Date',
                              DateFormat(
                                'dd/MM/yyyy',
                              ).format(_selectedBirthDate!),
                            ),
                            const SizedBox(height: 18),
                            _buildInfoRow(
                              Icons.calendar_today_outlined,
                              'Member Since',
                              DateFormat(
                                'MMM dd, yyyy',
                              ).format(_currentUser!.createdAt!),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sign Out Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade700, Colors.red.shade900],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout, size: 22),
                          label: const Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (_isEditing) ...[
                      const SizedBox(height: 30),

                      // Edit Form Fields
                      _buildEditField(
                        controller: _nameCtrl,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please Enter Your Name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildEditField(
                        controller: _birthDateCtrl,
                        label: 'Birth Date',
                        icon: Icons.cake_outlined,
                        hintText: 'dd/mm/yyyy',
                        readOnly: false,
                        keyboardType: TextInputType.datetime,
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.calendar_today,
                            color: Colors.deepPurpleAccent,
                          ),
                          onPressed: _selectBirthDate,
                        ),
                        helperText: _selectedBirthDate != null
                            ? 'Age: ${_calculateAge(_selectedBirthDate!)} years old'
                            : null,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please Enter Your Birth Date';
                          }
                          final parsedDate =
                              FormValidators.parseDateFromDDMMYYYY(value);
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
                      const SizedBox(height: 20),

                      _buildEditField(
                        controller: _emailCtrl,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        enabled: false,
                        helperText: 'Email cannot be changed',
                      ),
                      const SizedBox(height: 30),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: OutlinedButton(
                                onPressed: _updating
                                    ? null
                                    : () {
                                        setState(() {
                                          _isEditing = false;
                                          _selectedImage = null;
                                          _webImageBytes = null;
                                          if (_currentUser != null) {
                                            _nameCtrl.text =
                                                _currentUser!.fullName;
                                            _selectedBirthDate =
                                                _currentUser!.birthDate;
                                            _birthDateCtrl.text = DateFormat(
                                              'dd/MM/yyyy',
                                            ).format(_currentUser!.birthDate);
                                          }
                                        });
                                      },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.deepPurpleAccent,
                                    Colors.purple.shade700,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepPurpleAccent.withOpacity(
                                      0.4,
                                    ),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: (_updating || _uploadingImage)
                                    ? null
                                    : _updateProfile,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _updating
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.deepPurpleAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    String? helperText,
    bool enabled = true,
    bool readOnly = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        readOnly: readOnly,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          helperText: helperText,
          helperStyle: const TextStyle(color: Colors.deepPurpleAccent),
          prefixIcon: Icon(icon, color: Colors.deepPurpleAccent),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        style: const TextStyle(color: Colors.white, fontSize: 16),
        validator: validator,
      ),
    );
  }
}
