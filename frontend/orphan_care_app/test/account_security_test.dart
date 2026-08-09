import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaf/services/api_service.dart';
import 'package:kanaf/theme/kanaf_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يقفل سلوك أمان الحساب.
///
/// كان تسجيل الخروج ينتقل إلى شاشة الدخول **دون مسح التوكن**، فتبقى
/// الجلسة صالحة وتعيد شاشة البداية المستخدم إلى حسابه عند إعادة
/// التشغيل. وكان مفتاح الوضع الداكن يقلب `bool` محلياً بلا أثر.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('جلسة المستخدم', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('logout يمسح التوكن والدور من التخزين', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'access-token-value',
        'refresh_token': 'refresh-token-value',
        'user_role': 'donor',
      });
      final api = ApiService();
      expect(await api.isAuthenticated(), isTrue);

      await api.logout();

      expect(await api.isAuthenticated(), isFalse);
      expect(await api.getSavedRole(), isNull);
      final prefs = await SharedPreferences.getInstance();
      // لا بقايا: رمز التحديث وحده يكفي لإعادة إنشاء جلسة كاملة.
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
      expect(prefs.getString('user_role'), isNull);
    });

    test('الجلسة الفارغة لا تُعد مصادَقة', () async {
      final api = ApiService();
      expect(await api.isAuthenticated(), isFalse);
    });
  });

  group('KanafThemeController', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await KanafThemeController.instance.setMode(ThemeMode.light);
    });

    test('يبدأ بالوضع الفاتح افتراضياً', () async {
      SharedPreferences.setMockInitialValues({});
      await KanafThemeController.instance.load();
      expect(KanafThemeController.instance.value, ThemeMode.light);
    });

    test('يحفظ الوضع الداكن ويستعيده بعد إعادة التشغيل', () async {
      await KanafThemeController.instance.setDark(true);
      expect(KanafThemeController.instance.isDark, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');

      // محاكاة إقلاع جديد: نصفّر القيمة في الذاكرة فقط — استخدام
      // `setMode` هنا كان سيكتب في التخزين ويمحو ما نريد استعادته.
      KanafThemeController.instance.value = ThemeMode.light;
      await KanafThemeController.instance.load();

      expect(KanafThemeController.instance.value, ThemeMode.dark);
    });

    test('يُخطر المستمعين عند التبديل فقط', () async {
      var notifications = 0;
      void listener() => notifications++;
      KanafThemeController.instance.addListener(listener);

      await KanafThemeController.instance.setDark(true);
      // ضبط نفس القيمة مرة أخرى يجب ألا يعيد بناء التطبيق.
      await KanafThemeController.instance.setDark(true);

      KanafThemeController.instance.removeListener(listener);
      expect(notifications, 1);
    });
  });
}
