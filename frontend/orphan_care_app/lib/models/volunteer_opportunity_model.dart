import 'package:flutter/material.dart';

class VolunteerOpportunityModel {
  final int id;
  final String title;
  final String description;
  final String category;
  final String requiredSkills;
  final String? imageUrl;
  final int? careHomeId;
  final String? careHomeName;
  final String? careHomeLocation;
  final int requiredVolunteers;
  final int currentVolunteers;
  final int applicationsCount;
  final int? capacityPercent;
  final int? remainingSlots;
  final int? myApplicationId;
  final String? myApplicationStatus;
  final DateTime? startDate;
  final DateTime? endDate;
  final String location;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> raw;

  const VolunteerOpportunityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.requiredSkills,
    required this.requiredVolunteers,
    required this.currentVolunteers,
    required this.applicationsCount,
    required this.location,
    required this.status,
    required this.raw,
    this.careHomeId,
    this.careHomeName,
    this.careHomeLocation,
    this.imageUrl,
    this.capacityPercent,
    this.remainingSlots,
    this.myApplicationId,
    this.myApplicationStatus,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
  });

  factory VolunteerOpportunityModel.fromJson(Map<String, dynamic> json) {
    return VolunteerOpportunityModel(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      requiredSkills: json['required_skills']?.toString() ?? '',
      imageUrl: _asNullableString(json['image_url']),
      careHomeId: json['care_home'] == null ? null : _asInt(json['care_home']),
      careHomeName: _asNullableString(json['care_home_name']),
      careHomeLocation: _asNullableString(json['care_home_location']),
      requiredVolunteers: _asInt(json['required_volunteers']),
      currentVolunteers: _asInt(json['current_volunteers']),
      applicationsCount: _asInt(json['applications_count']),
      capacityPercent: _asNullableInt(json['capacity_percent']),
      remainingSlots: _asNullableInt(json['remaining_slots']),
      myApplicationId: _asNullableInt(json['my_application_id']),
      myApplicationStatus: _asNullableString(json['my_application_status']),
      startDate: _asDate(json['start_date']),
      endDate: _asDate(json['end_date']),
      location: json['location']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      createdAt: _asDate(json['created_at']),
      updatedAt: _asDate(json['updated_at']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  bool get isOpen => status == 'open';
  bool get isFull =>
      requiredVolunteers > 0 && currentVolunteers >= requiredVolunteers;
  bool get hasApplication => myApplicationStatus != null;
  bool get canApply => isOpen && !isFull && !hasApplication;

  int get effectiveRemainingSlots {
    if (remainingSlots != null) {
      return remainingSlots!.clamp(0, requiredVolunteers);
    }
    return (requiredVolunteers - currentVolunteers)
        .clamp(0, requiredVolunteers);
  }

  double get capacityRatio {
    if (capacityPercent != null) {
      return (capacityPercent!.clamp(0, 100) / 100).toDouble();
    }
    if (requiredVolunteers <= 0) return 0;
    return (currentVolunteers / requiredVolunteers).clamp(0.0, 1.0);
  }

  String get categoryLabel {
    switch (category) {
      case 'education':
        return 'تعليم';
      case 'health':
      case 'psychological':
        return 'دعم صحي';
      case 'logistics':
        return 'لوجستي';
      case 'events':
        return 'فعاليات';
      case 'general':
        return 'تطوع عام';
    }

    final text = '$title $description $requiredSkills'.toLowerCase();
    if (text.contains('teach') ||
        text.contains('تعليم') ||
        text.contains('تدريس')) {
      return 'تعليم';
    }
    if (text.contains('medical') ||
        text.contains('صحي') ||
        text.contains('نفسي')) {
      return 'دعم صحي';
    }
    if (text.contains('logistic') ||
        text.contains('تنظيم') ||
        text.contains('نقل')) {
      return 'لوجستي';
    }
    if (text.contains('event') ||
        text.contains('فعالية') ||
        text.contains('نشاط')) {
      return 'فعاليات';
    }
    return 'تطوع عام';
  }

  IconData get icon => switch (categoryLabel) {
        'تعليم' => Icons.school_outlined,
        'دعم صحي' => Icons.health_and_safety_outlined,
        'لوجستي' => Icons.local_shipping_outlined,
        'فعاليات' => Icons.celebration_outlined,
        _ => Icons.volunteer_activism_outlined,
      };

  List<String> get skills {
    return requiredSkills
        .split(RegExp(r'[,،\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toRouteArguments() => Map<String, dynamic>.from(raw)
    ..addAll({
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'required_skills': requiredSkills,
      'image_url': imageUrl,
      'care_home': careHomeId,
      'care_home_name': careHomeName,
      'care_home_location': careHomeLocation,
      'required_volunteers': requiredVolunteers,
      'current_volunteers': currentVolunteers,
      'applications_count': applicationsCount,
      'capacity_percent': capacityPercent,
      'remaining_slots': remainingSlots,
      'my_application_id': myApplicationId,
      'my_application_status': myApplicationStatus,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'location': location,
      'status': status,
    });

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static DateTime? _asDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _asNullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
