class DonationModel {
  final int id;
  final String donorName;
  final String donationType;
  final String itemType;
  final String status;
  final double? amount;
  final String? description;
  final String? quantity;
  final String? needTitle;
  final String? category;
  final DateTime? donationDate;
  final DateTime? createdAt;

  DonationModel({
    required this.id,
    required this.donorName,
    this.donationType = '',
    required this.itemType,
    required this.status,
    this.amount,
    this.description,
    this.quantity,
    this.needTitle,
    this.category,
    this.donationDate,
    this.createdAt,
  });

  static String _stringValue(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  static String? _nullableStringValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static double? _nullableDoubleValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _nullableDateTimeValue(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  factory DonationModel.fromJson(Map<String, dynamic> json) {
    return DonationModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      donorName: _stringValue(json['donor_name'] ?? json['donor']),
      donationType: _stringValue(json['donation_type']),
      itemType: _stringValue(json['item_type']),
      status: _stringValue(json['status'], 'pending'),
      amount: _nullableDoubleValue(json['amount']),
      description: _nullableStringValue(json['description']),
      quantity: _nullableStringValue(json['quantity']),
      needTitle: _nullableStringValue(json['need_title']),
      category: _nullableStringValue(json['category']),
      donationDate: _nullableDateTimeValue(json['donation_date']),
      createdAt: _nullableDateTimeValue(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'donor_name': donorName,
      'donation_type': donationType,
      'item_type': itemType,
      'status': status,
      'amount': amount,
      'description': description,
      'quantity': quantity,
      'need_title': needTitle,
      'category': category,
      'donation_date': donationDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  DonationModel copyWith({
    int? id,
    String? donorName,
    String? donationType,
    String? itemType,
    String? status,
    double? amount,
    String? description,
    String? quantity,
    String? needTitle,
    String? category,
    DateTime? donationDate,
    DateTime? createdAt,
  }) {
    return DonationModel(
      id: id ?? this.id,
      donorName: donorName ?? this.donorName,
      donationType: donationType ?? this.donationType,
      itemType: itemType ?? this.itemType,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      needTitle: needTitle ?? this.needTitle,
      category: category ?? this.category,
      donationDate: donationDate ?? this.donationDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'DonationModel(id: $id, donor: $donorName, item: $itemType, status: $status)';
}
