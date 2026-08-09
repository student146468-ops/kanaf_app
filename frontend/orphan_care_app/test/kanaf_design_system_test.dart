import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kanaf/router/kanaf_router.dart';
import 'package:kanaf/theme/kanaf_motion.dart';
import 'package:kanaf/theme/kanaf_theme.dart';
import 'package:kanaf/theme/kanaf_tokens.dart';
import 'package:kanaf/views/donor/donation_success_screen.dart';
import 'package:kanaf/widgets/kanaf_states.dart';

/// يتحقق من نظام تصميم كَنَفْ: الثيم، الراوتر، والمكوّنات المشتركة.
/// هذه الاختبارات تصرّف الكود فعلياً، فهي تكشف أخطاء البناء التي لا
/// يراها المحلّل الثابت.
/// يبني تطبيق اختبار بنفس إعدادات تعريب التطبيق الحقيقي.
///
/// المفوّضات الثلاثة كلها مطلوبة: `MaterialApp` يضيف مفوّض Cupertino
/// افتراضياً وهو لا يدعم إلا الإنجليزية، فيُطلق تحذيراً يفشل الاختبار.
Widget _testApp({Widget? home, RouteFactory? onGenerateRoute}) {
  return MaterialApp(
    theme: KanafTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
    onGenerateRoute: onGenerateRoute,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('KanafTheme', () {
    test('يبني الوضعين الفاتح والداكن من بذرة هوية كَنَفْ', () {
      final light = KanafTheme.light();
      final dark = KanafTheme.dark();

      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      // نظام الألوان مشتق لا مرصوف يدوياً.
      expect(light.colorScheme.primary, isNot(equals(dark.colorScheme.primary)));
    });

    test('يوفّر الألوان الدلالية كامتداد للثيم في الوضعين', () {
      for (final theme in [KanafTheme.light(), KanafTheme.dark()]) {
        final semantic = theme.extension<KanafSemanticColors>();
        expect(semantic, isNotNull, reason: 'الألوان الدلالية مفقودة');
        expect(semantic!.success, isNot(equals(semantic.warning)));
      }
    });

    test('يستخدم خطوطاً عربية ويمنح النص تنفساً رأسياً كافياً', () {
      final texts = KanafTheme.light().textTheme;

      expect(texts.bodyMedium?.fontFamily, KanafTheme.fontBody);
      expect(texts.headlineMedium?.fontFamily, KanafTheme.fontDisplay);
      // الحرف العربي يحتاج height أعلى من افتراضي Material.
      expect(texts.bodyMedium!.height!, greaterThanOrEqualTo(1.5));
    });
  });

  group('KanafRouter', () {
    KanafPageRoute<dynamic> routeFor(String name) {
      final route = KanafRouter.generate(RouteSettings(name: name));
      return route as KanafPageRoute<dynamic>;
    }

    test('جذور الأقسام تتلاشى بدل أن تنزلق', () {
      expect(
        routeFor(KanafRoutes.donorHome).transition,
        KanafTransition.fadeThrough,
      );
      expect(
        routeFor(KanafRoutes.volunteerHome).transition,
        KanafTransition.fadeThrough,
      );
    });

    test('الصفحات الفرعية تنزلق على المحور المشترك', () {
      expect(
        routeFor(KanafRoutes.financialDonation).transition,
        KanafTransition.sharedAxis,
      );
      expect(
        routeFor(KanafRoutes.donationHistory).transition,
        KanafTransition.sharedAxis,
      );
    });

    test('شاشة النجاح تظهر بتكبير متلاشٍ', () {
      expect(
        routeFor(KanafRoutes.donationSuccess).transition,
        KanafTransition.fadeScale,
      );
    });

    test('المسار المجهول يعود إلى شاشة البداية بلا انهيار', () {
      expect(routeFor('/route_does_not_exist'), isA<KanafPageRoute<dynamic>>());
    });
  });

  group('KanafStatusChip', () {
    Future<void> pumpChip(WidgetTester tester, String status) {
      return tester.pumpWidget(
        _testApp(home: Scaffold(body: KanafStatusChip(status: status))),
      );
    }

    testWidgets('يترجم حالات الخادم الإنجليزية إلى عربية', (tester) async {
      await pumpChip(tester, 'pending');
      expect(find.text('قيد المراجعة'), findsOneWidget);

      await pumpChip(tester, 'completed');
      expect(find.text('مكتمل'), findsOneWidget);

      await pumpChip(tester, 'rejected');
      expect(find.text('مرفوض'), findsOneWidget);
    });

    testWidgets('يعرض الحالة المجهولة كما هي بدل إخفائها', (tester) async {
      await pumpChip(tester, 'حالة_جديدة');
      expect(find.text('حالة_جديدة'), findsOneWidget);
    });
  });

  group('DonationSuccessScreen', () {
    testWidgets('تعرض الرقم المرجعي الحقيقي وحالة الخادم', (tester) async {
      await tester.pumpWidget(
        _testApp(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: const RouteSettings(
              name: KanafRoutes.donationSuccess,
              arguments: {
                'type': 'تبرع مالي',
                'reference': 'KNF-42',
                'status': 'pending',
                'summary': '١٠٠ د.ل عبر تحويل مصرفي',
              },
            ),
            builder: (_) => const DonationSuccessScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      // الرقم المرجعي يأتي من الخادم — لا يُلفَّق محلياً.
      expect(find.text('KNF-42'), findsOneWidget);
      // النص يقول «تم تسجيل» لا «تم إتمام»، لأن الحالة pending.
      expect(find.text('تم تسجيل مساهمتك'), findsOneWidget);
      expect(find.text('قيد المراجعة'), findsOneWidget);
      expect(find.text('تبرع مالي'), findsOneWidget);
    });

    testWidgets('لا تنهار عند غياب الوسائط', (tester) async {
      await tester.pumpWidget(_testApp(home: const DonationSuccessScreen()));
      await tester.pump(const Duration(milliseconds: 700));

      expect(tester.takeException(), isNull);
      expect(find.text('تم تسجيل مساهمتك'), findsOneWidget);
    });
  });
}
