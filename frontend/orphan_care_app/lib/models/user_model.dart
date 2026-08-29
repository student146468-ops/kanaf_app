/// نموذج بيانات المستخدم - يستخدم للمصادقة والتعريف
class UserModel {
  final int id;
  final String email;
  final String password;
  final String fullName;
  final String role; // donor, volunteer, care_home, admin
  final String? phoneNumber;
  final String? profileImage;
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserModel({
    required this.id,
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
    this.phoneNumber,
    this.profileImage,
    this.isVerified = false,
    this.createdAt,
    this.lastLogin,
  });

  /// تحويل من JSON إلى نموذج
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      fullName: json['full_name'] ?? json['name'] ?? '',
      role: json['role']?.toString() ?? '',
      phoneNumber: json['phone_number'],
      profileImage: json['profile_image'],
      isVerified: json['is_verified'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
    );
  }

  /// تحويل من نموذج إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'full_name': fullName,
      'role': role,
      'phone_number': phoneNumber,
      'profile_image': profileImage,
      'is_verified': isVerified,
      'created_at': createdAt?.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  /// نسخ مع تحديث بعض الحقول
  UserModel copyWith({
    int? id,
    String? email,
    String? password,
    String? fullName,
    String? role,
    String? phoneNumber,
    String? profileImage,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImage: profileImage ?? this.profileImage,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  @override
  String toString() =>
      'UserModel(id: $id, email: $email, fullName: $fullName, role: $role)';
}
