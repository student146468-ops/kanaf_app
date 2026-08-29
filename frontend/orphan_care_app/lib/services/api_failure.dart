import 'dart:io';

import 'package:flutter/foundation.dart';

/// سبب فشل الطلب.
///
/// كان الفشل يُمثَّل بنص فقط، فتعرض الواجهة شاشة «تعذر تحميل البيانات»
/// بأيقونة سحابة مقطوعة **لكل** فشل: انقطاع الشبكة، وخطأ في الخادم،
/// وانتهاء الجلسة سواء. المستخدم المتصل بالإنترنت كان يُقال له إن
/// اتصاله منقطع، فيضيّع وقته في فحص شبكته بلا سبب.
enum ApiFailureKind {
  /// الجهاز نفسه بلا اتصال — هنا فقط تصح شاشة «لا يوجد اتصال».
  offline,

  /// الجهاز متصل لكن الخادم لم يُجب (مطفأ، أو اسم النطاق لا يُحل).
  unreachable,

  /// وصل الطلب وتجاوز المهلة قبل أن يكتمل الرد.
  timeout,

  /// الخادم أجاب بخطأ 5xx — المشكلة عنده لا عند المستخدم.
  server,

  /// انتهت الجلسة أو رُفض الوصول.
  unauthorized,

  /// طلب غير صالح (4xx) — عادةً رسالة الخادم هي الأدق.
  request,

  /// ما لا يندرج تحت ما سبق.
  unknown,
}

extension ApiFailureKindX on ApiFailureKind {
  /// هل تُعرض شاشة «لا يوجد اتصال»؟
  ///
  /// فقط عند انقطاع فعلي أو تعذّر بلوغ الخادم. أي فشل آخر يعني أن
  /// الاتصال قائم، فالرسالة الصحيحة مختلفة تماماً.
  bool get isConnectivity =>
      this == ApiFailureKind.offline ||
      this == ApiFailureKind.unreachable ||
      this == ApiFailureKind.timeout;

  /// هل يستحق زر «إعادة المحاولة»؟ الأخطاء العابرة نعم، ورفض الطلب لا.
  bool get isRetryable => this != ApiFailureKind.request;
}

class ApiServiceException implements Exception {
  const ApiServiceException(
    this.message, {
    this.kind = ApiFailureKind.unknown,
    this.statusCode,
  });

  final String message;
  final ApiFailureKind kind;
  final int? statusCode;

  bool get isConnectivity => kind.isConnectivity;

  @override
  String toString() => message;
}

/// يفحص الاتصال فعلياً بدل الاستنتاج من شكل الخطأ وحده.
///
/// `DioExceptionType.connectionError` يُرفع في حالتين مختلفتين جداً:
/// الجهاز بلا شبكة، والخادم مطفأ رغم وجود الشبكة. التمييز بينهما هو
/// الفرق بين «تحقق من اتصالك» و«الخدمة متوقفة مؤقتاً» — ولا يجوز أن
/// نطلب من مستخدم متصل أن يفحص شبكته.
abstract final class NetworkProbe {
  /// نتيجة آخر فحص، تُستخدم لتفادي فحص متكرر خلال نافذة قصيرة.
  static bool? _lastResult;
  static DateTime? _lastCheck;

  static const Duration _cacheWindow = Duration(seconds: 5);

  /// للاختبارات: يفرض نتيجة ثابتة بدل الفحص الحقيقي.
  @visibleForTesting
  static bool? debugOverride;

  @visibleForTesting
  static void reset() {
    _lastResult = null;
    _lastCheck = null;
    debugOverride = null;
  }

  /// `true` إذا كان للجهاز اتصال صالح بالإنترنت.
  ///
  /// على الويب لا تتوفر مقابس DNS، فنعيد `true` ونترك التصنيف
  /// لنوع خطأ Dio — أفضل من ادّعاء انقطاع لا نستطيع إثباته.
  static Future<bool> hasConnection() async {
    if (debugOverride != null) return debugOverride!;
    if (kIsWeb) return true;

    final last = _lastCheck;
    if (last != null &&
        _lastResult != null &&
        DateTime.now().difference(last) < _cacheWindow) {
      return _lastResult!;
    }

    bool result;
    try {
      final lookup = await InternetAddress.lookup(
        'one.one.one.one',
      ).timeout(const Duration(seconds: 3));
      result = lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } on Object {
      result = false;
    }

    _lastResult = result;
    _lastCheck = DateTime.now();
    return result;
  }
}
