import 'package:flutter/material.dart';

class NeedModel {
  final int id;
  final String title;
  final String description;
  final String category;
  final String needType;
  final String priority;
  final String requiredQuantity;
  final double fulfilledQuantity;
  final String status;
  final String? imageUrl;
  final DateTime? deadline;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// معرّف الدار صاحبة الاحتياج — يتيح للمتبرع تصفح احتياجات دار بعينها.
  final int? careHomeId;

  const NeedModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.needType,
    required this.priority,
    required this.requiredQuantity,
    required this.fulfilledQuantity,
    required this.status,
    this.imageUrl,
    this.deadline,
    this.createdAt,
    this.updatedAt,
    this.careHomeId,
  });

  factory NeedModel.fromJson(Map<String, dynamic> json) {
    return NeedModel(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      needType: json['need_type']?.toString() ?? '',
      priority: json['priority']?.toString() ?? '',
      requiredQuantity: json['required_quantity']?.toString() ?? '',
      fulfilledQuantity: _asDouble(json['fulfilled_quantity']),
      status: json['status']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      deadline: _asDate(json['deadline']),
      createdAt: _asDate(json['created_at']),
      updatedAt: _asDate(json['updated_at']),
      careHomeId: json['care_home'] == null ? null : _asInt(json['care_home']),
    );
  }

  /// نسبة الإنجاز إن كانت الكمية المطلوبة رقمية، وإلا `null`.
  ///
  /// `required_quantity` نص حر في الخادم («٥٠ كرتونة»)، فلا يصح
  /// افتراض أنه رقم — ولا عرض شريط تقدّم لا معنى له.
  double? get progress {
    final match =
        RegExp(r'\d+(\.\d+)?').firstMatch(requiredQuantity.replaceAll(',', ''));
    final target = double.tryParse(match?.group(0) ?? '');
    if (target == null || target <= 0) return null;
    return (fulfilledQuantity / target).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'need_type': needType,
      'priority': priority,
      'required_quantity': requiredQuantity,
      'fulfilled_quantity': fulfilledQuantity,
      'status': status,
      'deadline': deadline?.toIso8601String().split('T').first,
    };
  }

  /// وسوم الحالة والأولوية بالعربية.
  ///
  /// كانت هذه القيم مخزَّنة بترميز تالف — `statusLabel` مثلاً كان يعيد
  /// `'ظ…ظƒطھظ…ظ„'` بدل «مكتمل»، فتظهر رموز مبعثرة في كل شاشة تعرضها.
  String get statusLabel => switch (status) {
        'completed' => 'مكتمل',
        'archived' => 'مؤرشف',
        _ => 'قيد التنفيذ',
      };

  String get priorityLabel => switch (priority) {
        'urgent' => 'عاجل',
        'low' => 'منخفض',
        'medium' => 'متوسط',
        _ => priority.isEmpty ? 'متوسط' : priority,
      };

  String get categoryLabel => switch (category) {
        'medical' => 'صحي',
        'food' => 'غذائي',
        'clothes' => 'كسوة',
        'education' => 'تعليمي',
        _ => category.isEmpty ? 'احتياج' : category,
      };

  IconData get icon => switch (category) {
        'medical' => Icons.health_and_safety_rounded,
        'food' => Icons.bakery_dining_rounded,
        'clothes' => Icons.checkroom_rounded,
        'education' => Icons.school_rounded,
        _ => Icons.inventory_2_outlined,
      };

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }
}
