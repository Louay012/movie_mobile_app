class UserModel {
  final String uid;
  final String fullName;
  final int age;
  final String email;
  final String? photoURL;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.age,
    required this.email,
    this.photoURL,
    required this.createdAt,
  });

  // Convert Firestore document to UserModel
  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      fullName: json['fullName'] ?? '',
      age: json['age'] ?? 0,
      email: json['email'] ?? '',
      photoURL: json['photoURL'],
      createdAt: (json['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
  UserModel copyWith({
    String? uid,
    String? fullName,
    int? age,
    String? email,
    String? photoURL,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  // Convert UserModel to Firestore document
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'fullName': fullName,
    'age': age,
    'email': email,
    'photoURL': photoURL,
    'createdAt': createdAt,
  };
}
