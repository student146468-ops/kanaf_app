import 'package:flutter_test/flutter_test.dart';
import 'package:kanaf/models/donation_request.dart';

/// يقفل عقد البيانات بين التطبيق و `DonationSerializer` في Django.
/// كسر أي توقع هنا يعني عودة باغ عدم التزامن: التطبيق يعرض نجاحاً
/// بينما الخادم يرفض الطلب أو يحفظ سجلاً ناقصاً.
void main() {
  group('DonationRequest.financial', () {
    test('يرسل النوع المالي والقيمة بصيغة عشرية', () {
      final json = DonationRequest.financial(
        amount: 100,
        paymentMethod: 'تحويل مصرفي',
        donationMode: 'تبرع مرة واحدة',
      ).toJson();

      expect(json['donation_type'], 'financial');
      expect(json['amount'], '100.00');
      expect(json['payment_method'], 'تحويل مصرفي');
      expect(json['donation_mode'], 'تبرع مرة واحدة');
    });

    test('لا يرسل status إطلاقاً — الخادم يملك دورة الحالة', () {
      final json = DonationRequest.financial(
        amount: 50,
        paymentMethod: 'محفظة إلكترونية',
        donationMode: 'تبرع شهري',
      ).toJson();

      // إرسال 'قيد التنفيذ' كان يُرفض بـ 400 لأن STATUS_CHOICES إنجليزية.
      expect(json.containsKey('status'), isFalse);
      expect(json.containsKey('user'), isFalse);
      expect(json.containsKey('donor_name'), isFalse);
    });

    test('يربط التبرع بالاحتياج عند تمريره فقط', () {
      final linked = DonationRequest.financial(
        amount: 10,
        paymentMethod: 'م',
        donationMode: 'و',
        needId: 7,
      ).toJson();
      final unlinked = DonationRequest.financial(
        amount: 10,
        paymentMethod: 'م',
        donationMode: 'و',
      ).toJson();

      expect(linked['need_id'], 7);
      expect(unlinked.containsKey('need_id'), isFalse);
    });

    test('يرفض القيمة الصفرية أو السالبة قبل الشبكة', () {
      expect(
        DonationRequest.financial(
          amount: 0,
          paymentMethod: 'م',
          donationMode: 'و',
        ).validationError(),
        isNotNull,
      );
      expect(
        DonationRequest.financial(
          amount: -5,
          paymentMethod: 'م',
          donationMode: 'و',
        ).validationError(),
        isNotNull,
      );
      expect(
        DonationRequest.financial(
          amount: 25.5,
          paymentMethod: 'م',
          donationMode: 'و',
        ).validationError(),
        isNull,
      );
    });
  });

  group('DonationRequest.inKind', () {
    test('يرسل النوع العيني بدون حقل amount', () {
      final json = DonationRequest.inKind(
        itemType: 'مواد غذائية',
        quantity: '10 سلات',
        description: 'سلات غذائية كاملة',
        contact: '0910000000',
      ).toJson();

      expect(json['donation_type'], 'in_kind');
      expect(json['item_type'], 'مواد غذائية');
      expect(json['quantity'], '10 سلات');
      expect(json['description'], 'سلات غذائية كاملة');
      expect(json['contact'], '0910000000');
      // الخادم يرفض amount بلا معنى للتبرع العيني.
      expect(json.containsKey('amount'), isFalse);
    });

    test('يحذف الحقول الفارغة بدل إرسال نصوص خاوية', () {
      final json = DonationRequest.inKind(
        itemType: 'ملابس وكسوة',
        quantity: '5 علب',
        description: '   ',
        notes: '',
      ).toJson();

      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('notes'), isFalse);
      expect(json.containsKey('contact'), isFalse);
    });

    test('يرفض الطلب الخالي من الكمية والوصف والنوع', () {
      expect(
        DonationRequest.inKind(itemType: '', quantity: '').validationError(),
        isNotNull,
      );
      expect(
        DonationRequest.inKind(itemType: 'مواد غذائية', quantity: '')
            .validationError(),
        isNull,
      );
    });
  });
}
