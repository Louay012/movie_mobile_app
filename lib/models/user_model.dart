class UserModel {
  final String uid;
  final String fullName;
  final DateTime birthDate; // Changed from int age
  final String email;
  final String? photoURL;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.birthDate,
    required this.email,
    this.photoURL,
    this.createdAt,
  });

  // Calculate age from birthdate
  int get age {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  // Factory constructor from JSON
  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    DateTime birthDate;
    
    // Handle both old age field and new birthDate field
    if (json.containsKey('birthDate') && json['birthDate'] != null) {
      // New format: birthDate as ISO string
      if (json['birthDate'] is String) {
        birthDate = DateTime.parse(json['birthDate']);
      } else if (json['birthDate'] is DateTime) {
        birthDate = json['birthDate'];
      } else {
        // Fallback: use a default date
        birthDate = DateTime(2000, 1, 1);
      }
    } else if (json.containsKey('age') && json['age'] != null) {
      // Old format: convert age to approximate birthdate
      final age = json['age'] as int;
      final now = DateTime.now();
      birthDate = DateTime(now.year - age, 1, 1);
    } else {
      // No date info, use default
      birthDate = DateTime(2000, 1, 1);
    }

    DateTime? createdAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is String) {
        createdAt = DateTime.parse(json['createdAt']);
      } else if (json['createdAt'] is DateTime) {
        createdAt = json['createdAt'];
      }
    }

    return UserModel(
      uid: uid,
      fullName: json['fullName'] ?? '',
      birthDate: birthDate,
      email: json['email'] ?? '',
      photoURL: json['photoURL'],
      createdAt: createdAt,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'birthDate': birthDate.toIso8601String(),
      'age': age, // Keep for backward compatibility
      'email': email,
      if (photoURL != null) 'photoURL': photoURL,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  // Copy with method
  UserModel copyWith({
    String? uid,
    String? fullName,
    DateTime? birthDate,
    String? email,
    String? photoURL,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, fullName: $fullName, birthDate: $birthDate, age: $age, email: $email)';
  }
}