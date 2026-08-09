/// نموذج بيانات اليتيم - يستخدم للتواصل بين التطبيق والمنظومة
class OrphanModel {
  final int id;
  final String name;
  final int age;
  final String status;
  final String? imageUrl;
  final String? bio;
  final String? needs;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrphanModel({
    required this.id,
    required this.name,
    required this.age,
    required this.status,
    this.imageUrl,
    this.bio,
    this.needs,
    this.createdAt,
    this.updatedAt,
  });

  /// تحويل من JSON إلى نموذج
  factory OrphanModel.fromJson(Map<String, dynamic> json) {
    return OrphanModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      status: json['status'] ?? 'ينتظر كفالة',
      imageUrl: json['image_url'],
      bio: json['bio'],
      needs: json['needs'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  /// تحويل من نموذج إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'status': status,
      'image_url': imageUrl,
      'bio': bio,
      'needs': needs,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// نسخ مع تحديث بعض الحقول
  OrphanModel copyWith({
    int? id,
    String? name,
    int? age,
    String? status,
    String? imageUrl,
    String? bio,
    String? needs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrphanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      bio: bio ?? this.bio,
      needs: needs ?? this.needs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'OrphanModel(id: $id, name: $name, age: $age, status: $status)';
}
