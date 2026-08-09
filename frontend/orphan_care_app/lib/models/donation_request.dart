/// عقد بيانات التبرع المرسل إلى الخادم.
///
/// أسماء الحقول هنا مطابقة تماماً لـ `DonationSerializer` في Django.
/// الحقول التي يتحكم بها الخادم (`user`, `donor_name`, `status`, `donation_date`)
/// لا تُرسل من التطبيق إطلاقاً — الخادم هو المصدر الوحيد للحقيقة فيها.
enum DonationKind {
  financial('financial'),
  inKind('in_kind');

  const DonationKind(this.wireValue);

  final String wireValue;
}

class DonationRequest {
  const DonationRequest._({
    required this.kind,
    required this.itemType,
    this.amount,
    this.needId,
    this.description = '',
    this.quantity = '',
    this.paymentMethod = '',
    this.donationMode = '',
    this.contact = '',
    this.notes = '',
  });

  /// تبرع مالي — `amount` إلزامي ويجب أن يكون أكبر من صفر،
  /// وإلا رفضه الخادم بـ 400 (`amount is required for financial donations`).
  factory DonationRequest.financial({
    required double amount,
    required String paymentMethod,
    required String donationMode,
    int? needId,
    String notes = '',
  }) {
    return DonationRequest._(
      kind: DonationKind.financial,
      itemType: 'تبرع مالي',
      amount: amount,
      needId: needId,
      paymentMethod: paymentMethod,
      donationMode: donationMode,
      notes: notes,
    );
  }

  /// تبرع عيني — الخادم يشترط وجود `quantity` أو `description` أو `item_type`.
  factory DonationRequest.inKind({
    required String itemType,
    required String quantity,
    int? needId,
    String description = '',
    String contact = '',
    String notes = '',
  }) {
    return DonationRequest._(
      kind: DonationKind.inKind,
      itemType: itemType,
      quantity: quantity,
      needId: needId,
      description: description,
      contact: contact,
      notes: notes,
    );
  }

  final DonationKind kind;
  final String itemType;
  final double? amount;
  final int? needId;
  final String description;
  final String quantity;
  final String paymentMethod;
  final String donationMode;
  final String contact;
  final String notes;

  bool get isFinancial => kind == DonationKind.financial;

  /// تحقق محلي مطابق لقواعد الخادم — يمنع رحلة شبكة مؤكدة الفشل.
  /// يعيد `null` عند الصحة، أو رسالة عربية عند الخطأ.
  String? validationError() {
    if (isFinancial) {
      final value = amount;
      if (value == null || value <= 0) {
        return 'أدخل قيمة صحيحة للتبرع.';
      }
    } else if (quantity.trim().isEmpty &&
        description.trim().isEmpty &&
        itemType.trim().isEmpty) {
      return 'حدد نوع التبرع والكمية.';
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'donation_type': kind.wireValue,
      'item_type': itemType.trim(),
    };

    if (isFinancial) {
      // يُرسل كنص لتفادي فقدان الدقة في DecimalField(12, 2).
      payload['amount'] = amount!.toStringAsFixed(2);
    }
    if (needId != null) {
      payload['need_id'] = needId;
    }
    _putIfNotEmpty(payload, 'description', description);
    _putIfNotEmpty(payload, 'quantity', quantity);
    _putIfNotEmpty(payload, 'payment_method', paymentMethod);
    _putIfNotEmpty(payload, 'donation_mode', donationMode);
    _putIfNotEmpty(payload, 'contact', contact);
    _putIfNotEmpty(payload, 'notes', notes);

    return payload;
  }

  static void _putIfNotEmpty(
    Map<String, dynamic> payload,
    String key,
    String value,
  ) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) payload[key] = trimmed;
  }
}
