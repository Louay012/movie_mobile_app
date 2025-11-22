class AuthResponse {
  final bool success;
  final String? message;
  final String? uid;

  AuthResponse({
    required this.success,
    this.message,
    this.uid,
  });
}
