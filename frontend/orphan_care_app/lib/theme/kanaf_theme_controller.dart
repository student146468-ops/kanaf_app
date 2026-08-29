import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يتحكم بوضع الثيم (فاتح / داكن / تبع النظام) ويحفظ الاختيار.
///
/// كان مفتاح «الوضع الداكن» في الإعدادات يقلب `bool` محلياً بلا أي
/// أثر على المظهر — مفتاح زخرفي. هذا المتحكم يجعله حقيقياً ويحفظ
/// الاختيار بين الجلسات.
class KanafThemeController extends ValueNotifier<ThemeMode> {
  KanafThemeController._() : super(ThemeMode.light);

  static final KanafThemeController instance = KanafThemeController._();

  static const String _storageKey = 'theme_mode';

  /// يقرأ الاختيار المحفوظ. يُستدعى مرة واحدة عند الإقلاع.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = _decode(prefs.getString(_storageKey));
    } catch (_) {
      // تعذر قراءة التخزين لا يجوز أن يمنع إقلاع التطبيق.
      value = ThemeMode.light;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (value == mode) return;
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, _encode(mode));
    } catch (_) {
      // الفشل في الحفظ يترك التغيير سارياً لهذه الجلسة فقط.
    }
  }

  Future<void> setDark(bool isDark) =>
      setMode(isDark ? ThemeMode.dark : ThemeMode.light);

  bool get isDark => value == ThemeMode.dark;

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      };

  static ThemeMode _decode(String? raw) => switch (raw) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
}
