/// نموذج بيانات المتطوع - يستخدم للتواصل بين التطبيق والمنظومة
class VolunteerModel {
  final int id;
  final String name;
  final String specialty;
  final int points;
  final String? email;
  final String? phone;
  final String? status;
  final int? hoursWorked;
  final String? imageUrl;
  final DateTime? createdAt;

  VolunteerModel({
    required this.id,
    required this.name,
    required this.specialty,
    required this.points,
    this.email,
    this.phone,
    this.status,
    this.hoursWorked,
    this.imageUrl,
    this.createdAt,
  });

  /// تحويل من JSON إلى نموذج
  factory VolunteerModel.fromJson(Map<String, dynamic> json) {
    return VolunteerModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      specialty: json['specialty'] ?? '',
      points: json['points'] ?? 0,
      email: json['email'],
      phone: json['phone'],
      status: json['status'],
      hoursWorked: json['hours_worked'],
      imageUrl: json['image_url'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  /// تحويل من نموذج إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialty': specialty,
      'points': points,
      'email': email,
      'phone': phone,
      'status': status,
      'hours_worked': hoursWorked,
      'image_url': imageUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// نسخ مع تحديث بعض الحقول
  VolunteerModel copyWith({
    int? id,
    String? name,
    String? specialty,
    int? points,
    String? email,
    String? phone,
    String? status,
    int? hoursWorked,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return VolunteerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      specialty: specialty ?? this.specialty,
      points: points ?? this.points,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'VolunteerModel(id: $id, name: $name, specialty: $specialty, points: $points)';
}
