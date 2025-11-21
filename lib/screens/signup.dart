import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/storage_service.dart';
import 'login.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _userService = UserService();
  final _storage = StorageService();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  XFile? _selectedImage;      // image_picker file
  Uint8List? _webImageBytes;  // for web preview

  // Pick image
  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      _selectedImage = picked;
      if (kIsWeb) _webImageBytes = await picked.readAsBytes();
      setState(() {});
    }
  }

  // Upload image
  Future<String?> uploadImage(String uid) async {
    if (_selectedImage == null) return null;
    if (kIsWeb) {
      return await _storage.uploadProfileImageWeb(uid, _webImageBytes!);
    } else {
      return await _storage.uploadProfileImage(uid, File(_selectedImage!.path));
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // 1️⃣ Create user in Firebase Auth
      User? user = await _auth.signUpWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      if (user == null) throw Exception("User is null!");

      // 2️⃣ Upload profile image
      final imageURL = await uploadImage(user.uid);

      // 3️⃣ Update Firebase Auth profile
      await _auth.updateProfile(
        user: user,
        displayName: _nameCtrl.text.trim(),
        photoURL: imageURL,
      );

      // 4️⃣ Save user in Firestore
      await _userService.createUser(
        uid: user.uid,
        fullName: _nameCtrl.text.trim(),
        age: int.parse(_ageCtrl.text.trim()),
        email: _emailCtrl.text.trim(),
        photoURL: imageURL,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully!")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup error: $e")),
      );
    }

    if (mounted) setState(() => _loading = false);
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
      appBar: AppBar(title: const Text("Create Account")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 10),

              // Profile Image
              Center(
                child: GestureDetector(
                  onTap: pickImage,
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.grey.shade300,
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
                ),
              ),
              const SizedBox(height: 25),

              // Full Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v!.trim().isEmpty ? "Enter your name" : null,
              ),
              const SizedBox(height: 16),

              // Age
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v!.isEmpty) return "Enter your age";
                  if (int.tryParse(v) == null) return "Age must be a number";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (!v!.contains('@')) ? "Invalid email" : null,
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    v!.length < 6 ? "Minimum 6 characters" : null,
              ),
              const SizedBox(height: 25),

              // Sign Up Button
              ElevatedButton(
                onPressed: _loading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Sign Up", style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 15),

              // Login Redirect
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text("Log In"),
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
