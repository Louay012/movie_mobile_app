class UserModel {
  final String uid;
  final String fullName;
  final DateTime birthDate;
  final String email;
  final String? photoURL;
  final DateTime? createdAt;
  final bool isAdmin;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.birthDate,
    required this.email,
    this.photoURL,
    this.createdAt,
    this.isAdmin = false,
    this.isActive = true,
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
      if (json['birthDate'] is String) {
        birthDate = DateTime.parse(json['birthDate']);
      } else if (json['birthDate'] is DateTime) {
        birthDate = json['birthDate'];
      } else {
        birthDate = DateTime(2000, 1, 1);
      }
    } else if (json.containsKey('age') && json['age'] != null) {
      final age = json['age'] as int;
      final now = DateTime.now();
      birthDate = DateTime(now.year - age, 1, 1);
    } else {
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
      fullName: json['fullName'] ?? json['name'] ?? '',
      birthDate: birthDate,
      email: json['email'] ?? '',
      photoURL: json['photoURL'] ?? json['profileImageUrl'],
      createdAt: createdAt,
      isAdmin: json['isAdmin'] ?? false,
      isActive: json['isActive'] ?? true,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'birthDate': birthDate.toIso8601String(),
      'age': age,
      'email': email,
      if (photoURL != null) 'photoURL': photoURL,
      'createdAt': createdAt?.toIso8601String(),
      'isAdmin': isAdmin,
      'isActive': isActive,
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
    bool? isAdmin,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      isAdmin: isAdmin ?? this.isAdmin,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, fullName: $fullName, birthDate: $birthDate, age: $age, email: $email, isAdmin: $isAdmin, isActive: $isActive)';
  }
}
