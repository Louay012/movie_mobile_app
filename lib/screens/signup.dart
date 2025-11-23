import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _database = DatabaseService();
  final _storage = StorageService();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _uploadingImage = false;

  XFile? _selectedImage;
  Uint8List? _webImageBytes;

  Future<void> _pickImage() async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        _selectedImage = picked;
        if (kIsWeb) {
          _webImageBytes = await picked.readAsBytes();
        }
        setState(() {});
      }
    } catch (e) {
      _showError('Failed to pick image');
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // Step 1: Create user in Firebase Auth
      final authResponse = await _auth.signUpWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      if (!authResponse.success || authResponse.uid == null) {
        _showError(authResponse.message ?? AppMessages.errorOccurred);
        return;
      }

      final uid = authResponse.uid!;

      // Step 2: Convert image to base64 instead of uploading
      String? base64Image;
      if (_selectedImage != null) {
        setState(() => _uploadingImage = true);
        try {
          final imageData = kIsWeb ? _webImageBytes! : File(_selectedImage!.path);
          base64Image = await _storage.imageToBase64(imageData);
          if (base64Image == null) {
            _showError('Failed to process image, but account will be created.');
          }
        } catch (e) {
          _showError('Error processing image: $e');
        } finally {
          if (mounted) setState(() => _uploadingImage = false);
        }
      }

      // Step 3: Update Firebase Auth profile
      final user = _auth.currentUser;
      if (user != null) {
        await _auth.updateProfile(
          user: user,
          displayName: _nameCtrl.text.trim(),
          photoURL: base64Image,
        );
      }

      // Step 4: Save user to Firestore
      final userModel = UserModel(
        uid: uid,
        fullName: _nameCtrl.text.trim(),
        age: int.parse(_ageCtrl.text.trim()),
        email: _emailCtrl.text.trim(),
        photoURL: base64Image,
        createdAt: DateTime.now(),
      );

      final saved = await _database.createUser(userModel);
      if (!saved) {
        _showError('Failed to save user data');
        return;
      }

      if (!mounted) return;

      _showSuccess(AppMessages.signupSuccess);

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
    } catch (e) {
      _showError('Signup failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 10),

              // Profile Image Picker
              Center(
                child: GestureDetector(
                  onTap: _uploadingImage ? null : _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage: kIsWeb
                            ? (_webImageBytes != null
                                ? MemoryImage(_webImageBytes!)
                                : null)
                            : (_selectedImage != null
                                ? FileImage(File(_selectedImage!.path))
                                : null) as ImageProvider<Object>?,
                        child: _selectedImage == null
                            ? const Icon(Icons.camera_alt, size: 40)
                            : null,
                      ),
                      if (_uploadingImage)
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.black.withOpacity(0.5),
                          child: const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Full Name
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: FormValidators.validateName,
              ),
              const SizedBox(height: 16),

              // Age
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Age',
                  prefixIcon: const Icon(Icons.cake),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: FormValidators.validateAge,
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: FormValidators.validateEmail,
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: FormValidators.validatePassword,
              ),
              const SizedBox(height: 25),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_loading || _uploadingImage) ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
              const SizedBox(height: 15),

              // Login Redirect
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text('Log In'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
