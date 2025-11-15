// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    // TODO: Replace with real Firebase / Supabase / your backend call
    await Future.delayed(const Duration(seconds: 2)); // simulate network
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account created! (Demo)')));
      // Navigator.pushReplacement(... home screen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Logo
              Center(
                child: Icon(
                  Icons.movie,
                  size: 100,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Join MovieFlix',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Enter your name' : null,
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v!.isEmpty) return 'Enter email';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 24),

              // Sign Up Button
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Sign Up', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 16),

              // Login redirect
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  TextButton(
                    onPressed: () {
                      // TODO: Navigate to Login screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Login screen not implemented yet'),
                        ),
                      );
                    },
                    child: const Text('Log In'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
