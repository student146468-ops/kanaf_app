class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.isRead,
    this.imageUrl,
    this.createdAt,
    this.relatedModel,
    this.relatedObjectId,
    this.username,
  });

  final int id;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final String? imageUrl;
  final DateTime? createdAt;
  final String? relatedModel;
  final int? relatedObjectId;
  final String? username;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? '',
      message: (json['message'] ?? json['body'])?.toString() ?? '',
      notificationType: json['notification_type']?.toString() ?? 'message',
      isRead: json['is_read'] == true,
      imageUrl: _nullableString(
        json['image_url'] ?? json['image'] ?? json['imageUrl'],
      ),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      relatedModel: json['related_model']?.toString(),
      relatedObjectId: _nullableInt(json['related_object_id']),
      username: json['username']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'notification_type': notificationType,
      'is_read': isRead,
      'image_url': imageUrl,
      'created_at': createdAt?.toIso8601String(),
      'related_model': relatedModel,
      'related_object_id': relatedObjectId,
      'username': username,
    };
  }

  static int _asInt(Object? value) => _nullableInt(value) ?? 0;

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _nullableInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
