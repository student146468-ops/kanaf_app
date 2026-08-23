import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/app_provider.dart';
import 'providers/app_provider_scope.dart';
import 'router/kanaf_router.dart';
import 'theme/kanaf_locale_controller.dart';
import 'theme/kanaf_theme.dart';
import 'theme/kanaf_theme_controller.dart';
import 'utils/session_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة بيانات التواريخ العربية قبل الإقلاع. بدونها يرمي
  // `DateFormat(..., 'ar')` استثناء LocaleDataException عند أول
  // شاشة تعرض تاريخاً.
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');

  // استرجاع وضع الثيم المحفوظ قبل أول إطار، فلا يومض المظهر الفاتح
  // للحظة أمام مستخدم اختار الوضع الداكن.
  await KanafThemeController.instance.load();
  await KanafLocaleController.instance.load();

  final provider = AppProvider();

  runApp(
    AppProviderScope(
      provider: provider,
      child: KanafApp(provider: provider),
    ),
  );
}

class KanafApp extends StatelessWidget {
  KanafApp({super.key, required this.provider});

  final AppProvider provider;

  /// مفتاح الملاح — يتيح لحارس الجلسة إعادة التوجيه من خارج شجرة
  /// الشاشات دون تمرير `BuildContext` عبر الطبقات.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // إعادة البناء عند تبديل الثيم من الإعدادات — يقتصر التحديث على
    // `MaterialApp` فلا يُعاد بناء شجرة الشاشات الحالية يدوياً.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: KanafThemeController.instance,
      builder: (context, themeMode, _) => ValueListenableBuilder<Locale>(
        valueListenable: KanafLocaleController.instance,
        builder: (context, locale, _) => KanafSessionGuard(
          navigatorKey: _navigatorKey,
          provider: provider,
          child: _buildApp(themeMode, locale),
        ),
      ),
    );
  }

  Widget _buildApp(ThemeMode themeMode, Locale locale) {
    return MaterialApp(
      title: 'كَنَفْ',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,

      // ── التعريب ─────────────────────────────────────────────
      // تحديد `locale` عربي يجعل Flutter يقلب الاتجاه إلى RTL على
      // مستوى التطبيق كله. هذا يغني عن لفّ كل شاشة بـ `Directionality`
      // يدوياً — وهو ما كان يسبب اختلافات اتجاه بين الشاشات
      // ويجعل الحوارات والأوراق السفلية تخرج بالاتجاه الخطأ.
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ── الثيم ───────────────────────────────────────────────
      theme: KanafTheme.light(),
      darkTheme: KanafTheme.dark(),
      themeMode: themeMode,

      // ── التنقل ──────────────────────────────────────────────
      initialRoute: KanafRoutes.splash,
      onGenerateRoute: KanafRouter.generate,

      // تثبيت مقياس الخط ضمن حدود آمنة: نحترم إعداد المستخدم
      // لإمكانية الوصول، لكن نمنع تكبيراً متطرفاً يفكك التخطيط.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.25,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
