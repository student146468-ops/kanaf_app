import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يحفظ لغة التطبيق ويتيح تبديلها دون إعادة تشغيل.
class KanafLocaleController extends ValueNotifier<Locale> {
  KanafLocaleController._() : super(const Locale('ar'));

  static final KanafLocaleController instance = KanafLocaleController._();

  static const String _storageKey = 'app_locale';
  static const Locale arabic = Locale('ar');
  static const Locale english = Locale('en');

  bool get isArabic => value.languageCode == arabic.languageCode;

  String get languageLabel => isArabic ? 'العربية' : 'English';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = _decode(prefs.getString(_storageKey));
    } catch (_) {
      value = arabic;
    }
  }

  Future<void> setLocale(Locale locale) async {
    final next = _normalize(locale);
    if (value.languageCode == next.languageCode) return;
    value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, next.languageCode);
    } catch (_) {
      // يبقى التغيير سارياً للجلسة الحالية حتى لو تعذر الحفظ.
    }
  }

  static Locale _decode(String? raw) => switch (raw) {
        'en' => english,
        _ => arabic,
      };

  static Locale _normalize(Locale locale) =>
      locale.languageCode == 'en' ? english : arabic;
}
