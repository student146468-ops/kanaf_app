import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kanaf/providers/app_provider.dart';
import 'package:kanaf/providers/app_provider_scope.dart';
import 'package:kanaf/services/api_failure.dart';
import 'package:kanaf/theme/kanaf_theme.dart';
import 'package:kanaf/views/about/about_app_screen.dart';
import 'package:kanaf/views/discovery_search/explore_orphanages_screen.dart';
import 'package:kanaf/views/donor/donation_success_screen.dart';
import 'package:kanaf/views/donor/financial_donation_screen.dart';
import 'package:kanaf/views/donor/inkind_donation_screen.dart';
import 'package:kanaf/views/donor/profile_screen.dart';
import 'package:kanaf/views/donor/search_filter_screen.dart';
import 'package:kanaf/views/donor/supporter_home_screen.dart';
import 'package:kanaf/views/forgot_password_screen.dart';
import 'package:kanaf/views/login_screen.dart';
import 'package:kanaf/views/onboarding_screen.dart';
import 'package:kanaf/views/register_screen.dart';
import 'package:kanaf/views/reset_password_screen.dart';
import 'package:kanaf/views/role_selection_screen.dart';
import 'package:kanaf/views/settings/change_email_screen.dart';
import 'package:kanaf/views/settings/change_password_screen.dart';
import 'package:kanaf/views/settings/settings_screen.dart';
import 'package:kanaf/views/volunteer/apply_opportunity_view.dart';
import 'package:kanaf/views/volunteer/home_volunteer_view.dart';
import 'package:kanaf/views/volunteer/my_certificates_view.dart';
import 'package:kanaf/views/volunteer/my_schedule_view.dart';
import 'package:kanaf/views/volunteer/profile_volunteer_view.dart';
import 'package:kanaf/widgets/kanaf_states.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مولّد لقطات الشاشة.
///
/// شغّله بـ: `flutter test test/screenshots_test.dart --update-goldens`
/// تُكتب الصور في `test/screenshots/`.
///
/// هذه لقطات **حقيقية**: الشاشات تُصرَّف وتُرسم فعلاً بمحرّك Flutter
/// نفسه، بالخطوط العربية الحقيقية وبأبعاد هاتف. الفرق الوحيد عن جهاز
/// فعلي أن الشبكة غير متاحة، فالشاشات المعتمدة على بيانات الخادم تظهر
/// في حالتها الفارغة — وهي بذاتها حالة تستحق المراجعة.
///
/// تُشغَّل بأبعاد Pixel 7 المنطقية (412×915).
const Size _phoneSize = Size(412, 915);

Future<void> _loadArabicFonts() async {
  // بدون تحميل صريح تُرسم النصوص بخط الاختبار (مربعات فارغة)،
  // فتصبح اللقطات عديمة الفائدة للمراجعة البصرية.
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }

  // خط أيقونات Material ليس ضمن أصول المشروع بل ضمن الـ SDK، ولا
  // يُحمَّل تلقائياً في بيئة الاختبار — بدونه تظهر كل أيقونة مربعاً.
  await _loadMaterialIcons();

  await load('Vazirmatn', [
    'assets/fonts/Vazirmatn-Regular.ttf',
    'assets/fonts/Vazirmatn-SemiBold.ttf',
    'assets/fonts/Vazirmatn-Bold.ttf',
  ]);
  await load('Tajawal', [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
  ]);
  await load('Cairo', ['assets/fonts/Cairo.ttf']);
}

/// يحمّل خط أيقونات Material من مجلد الـ SDK.
///
/// موقع الملف يُشتق من `Platform.resolvedExecutable` (وهو `dart` داخل
/// الـ SDK) فلا نحتاج مساراً مكتوباً يدوياً يختلف بين الأجهزة.
/// عند تعذّر العثور عليه نمضي بلا أيقونات بدل إفشال التوليد كله.
Future<void> _loadMaterialIcons() async {
  final dartBin = File(Platform.resolvedExecutable);
  var directory = dartBin.parent;

  for (var depth = 0; depth < 6; depth++) {
    final candidate = File(
      '${directory.path}/bin/cache/artifacts/material_fonts'
      '/materialicons-regular.otf',
    );
    if (candidate.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(candidate.readAsBytesSync().buffer.asByteData()),
        );
      await loader.load();
      return;
    }
    if (directory.parent.path == directory.path) break;
    directory = directory.parent;
  }
}

/// يغلّف الشاشة بنفس بيئة التطبيق الحقيقي: الثيم، التعريب، والحالة.
Widget _wrap(Widget screen, {Object? routeArguments, bool dark = false}) {
  return AppProviderScope(
    provider: AppProvider(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? KanafTheme.dark() : KanafTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: RouteSettings(name: settings.name, arguments: routeArguments),
        builder: (_) => screen,
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await _loadArabicFonts();
    initializeDateFormatting('ar');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // بيئة الاختبار بلا شبكة. نُثبّت النتيجة صراحةً بدل انتظار فشل
    // استعلام DNS حقيقي — فتصبح اللقطات محدَّدة لا رهينة توقيت.
    NetworkProbe.debugOverride = false;
  });

  tearDown(NetworkProbe.reset);

  /// يلتقط لقطة لشاشة واحدة.
  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget screen, {
    Object? routeArguments,
    bool dark = false,
  }) async {
    // كثافة 2x تكفي تماماً للمراجعة البصرية وتُبقي حجم كل لقطة
    // في حدود معقولة؛ 3x كانت تضاعف الحجم بلا فائدة تُرى.
    tester.view.physicalSize = _phoneSize * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(screen, routeArguments: routeArguments, dark: dark),
    );

    // تحميل الصور فعلياً: فكّ ترميز PNG عملية غير متزامنة حقيقية،
    // و`pumpWidget` يعمل داخل منطقة زمن وهمي تمنعها. بدون `runAsync`
    // تبقى كل `Image.asset` فارغة — ومنها شعار كَنَفْ وصور الترحيب.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element);
      }
    });
    await tester.pump();

    // إطارات متتابعة لا قفزة واحدة: `KanafStaggeredEntrance` يؤخّر
    // بدء كل عنصر بـ `Future.delayed`، و`pump` واحد بمدة كبيرة يُطلق
    // كل المؤقتات ثم يرسم إطاراً واحداً — فتبقى العناصر المتأخرة
    // بشفافية صفر. التقدّم على خطوات يمنح كل متحكم تكّاته.
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/$name.png'),
    );
  }

  group('لقطات شاشات كَنَفْ', () {
    testWidgets('01 - الترحيب', (tester) async {
      await capture(tester, '01_onboarding', const OnboardingScreen());
    });

    testWidgets('02 - اختيار الدور', (tester) async {
      await capture(tester, '02_role_selection', const RoleSelectionScreen());
    });

    testWidgets('03 - تسجيل الدخول', (tester) async {
      await capture(tester, '03_login', const LoginScreen());
    });

    testWidgets('04 - إنشاء حساب', (tester) async {
      await capture(
        tester,
        '04_register',
        const RegisterScreen(selectedRole: 'donor'),
      );
    });

    testWidgets('05 - نسيت كلمة المرور', (tester) async {
      await capture(tester, '05_forgot_password', const ForgotPasswordScreen());
    });

    testWidgets('06 - كلمة مرور جديدة', (tester) async {
      await capture(
        tester,
        '06_reset_password',
        const ResetPasswordScreen(),
        routeArguments: 'donor@example.com',
      );
    });

    testWidgets('07 - التبرع المالي', (tester) async {
      await capture(
        tester,
        '07_financial_donation',
        const FinancialDonationScreen(),
      );
    });

    testWidgets('08 - التبرع العيني', (tester) async {
      await capture(
        tester,
        '08_inkind_donation',
        const InkindDonationScreen(),
      );
    });

    testWidgets('09 - تأكيد التبرع', (tester) async {
      await capture(
        tester,
        '09_donation_success',
        const DonationSuccessScreen(),
        routeArguments: const {
          'type': 'تبرع مالي',
          'reference': 'KNF-1042',
          'status': 'pending',
          'summary': '٢٥٠ د.ل عبر تحويل مصرفي',
        },
      );
    });

    testWidgets('10 - الإعدادات', (tester) async {
      await capture(tester, '10_settings', const SettingsScreen());
    });

    testWidgets('11 - تغيير كلمة المرور', (tester) async {
      await capture(
        tester,
        '11_change_password',
        const ChangePasswordScreen(),
      );
    });

    testWidgets('12 - تغيير البريد', (tester) async {
      await capture(tester, '12_change_email', const ChangeEmailScreen());
    });

    testWidgets('13 - عن التطبيق', (tester) async {
      await capture(tester, '13_about_app', const AboutAppScreen());
    });

    // الشاشات المعتمدة على الشبكة تظهر في حالتها الفارغة — وهي
    // بذاتها الحالة التي يراها المستخدم عند انقطاع الاتصال.
    testWidgets('14 - رئيسية المتبرع', (tester) async {
      await capture(tester, '14_donor_home', const SupporterHomeScreen());
    });

    testWidgets('15 - الاحتياجات', (tester) async {
      await capture(tester, '15_needs_search', const SearchFilterScreen());
    });

    testWidgets('16 - تصفّح الدور', (tester) async {
      await capture(
        tester,
        '16_explore_orphanages',
        const ExploreOrphanagesScreen(),
      );
    });

    testWidgets('17 - حساب المتبرع', (tester) async {
      await capture(tester, '17_donor_profile', const ProfileScreen());
    });

    testWidgets('18 - فرص التطوع', (tester) async {
      await capture(tester, '18_volunteer_home', const HomeVolunteerView());
    });

    testWidgets('19 - جدول المتطوع', (tester) async {
      await capture(tester, '19_volunteer_schedule', const MyScheduleView());
    });

    testWidgets('20 - شهادات المتطوع', (tester) async {
      await capture(tester, '20_certificates', const MyCertificatesView());
    });

    testWidgets('21 - حساب المتطوع', (tester) async {
      await capture(
        tester,
        '21_volunteer_profile',
        const ProfileVolunteerView(),
      );
    });

    testWidgets('22 - التقديم على فرصة', (tester) async {
      await capture(
        tester,
        '22_apply_opportunity',
        const ApplyOpportunityView(),
        routeArguments: const {
          'id': 3,
          'title': 'مرافقة رحلة الأطفال',
          'location': 'غريان',
        },
      );
    });

    // حالتا العطل الأهم، معروضتان صراحةً.
    //
    // لا تُلتقطان من شاشة بيانات لأن `flutter_test` يعترض الشبكة
    // ويردّ 400 على كل طلب، فتُصنَّف الحالة «طلب مرفوض» — وهو تصنيف
    // صحيح لما جرى في المحاكاة، لكنه ليس ما يراه المستخدم على جهاز
    // حقيقي بلا شبكة. عرضهما مباشرةً يوثّق السلوك كما هو.
    testWidgets('26 - لا يوجد اتصال', (tester) async {
      await capture(
        tester,
        '26_state_offline',
        Scaffold(
          appBar: AppBar(title: const Text('الاحتياجات')),
          body: KanafFailureState(
            message: 'تحقق من الشبكة أو بيانات الجوال ثم أعد المحاولة.',
            kind: ApiFailureKind.offline,
            onRetry: () {},
          ),
        ),
      );
    });

    testWidgets('27 - عطل في الخادم', (tester) async {
      await capture(
        tester,
        '27_state_server_error',
        Scaffold(
          appBar: AppBar(title: const Text('الاحتياجات')),
          body: KanafFailureState(
            message:
                'اتصالك يعمل، لكن تعذر الوصول إلى خدمة كَنَفْ. حاول بعد قليل.',
            kind: ApiFailureKind.unreachable,
            onRetry: () {},
          ),
        ),
      );
    });

    // عيّنة من الوضع الداكن للتحقق من أن الثيم يعمل في الاتجاهين.
    testWidgets('23 - تسجيل الدخول (داكن)', (tester) async {
      await capture(tester, '23_login_dark', const LoginScreen(), dark: true);
    });

    testWidgets('24 - التبرع المالي (داكن)', (tester) async {
      await capture(
        tester,
        '24_financial_donation_dark',
        const FinancialDonationScreen(),
        dark: true,
      );
    });

    testWidgets('25 - فرص التطوع (داكن)', (tester) async {
      await capture(
        tester,
        '25_volunteer_home_dark',
        const HomeVolunteerView(),
        dark: true,
      );
    });
  });
}
