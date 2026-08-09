import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaf/services/api_failure.dart';
import 'package:kanaf/services/api_service.dart';
import 'package:kanaf/theme/kanaf_motion.dart';
import 'package:kanaf/theme/kanaf_theme.dart';
import 'package:kanaf/widgets/kanaf_states.dart';

/// اختبارات المرحلة الثالثة: تصنيف الأعطال، والمصادقة، والأداء.

Widget _app(Widget child) {
  return MaterialApp(
    theme: KanafTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

DioException _dio({
  DioExceptionType type = DioExceptionType.badResponse,
  int? statusCode,
}) {
  final options = RequestOptions(path: '/needs/');
  return DioException(
    requestOptions: options,
    type: type,
    response: statusCode == null
        ? null
        : Response<dynamic>(requestOptions: options, statusCode: statusCode),
  );
}

void main() {
  tearDown(NetworkProbe.reset);

  group('تصنيف سبب العطل', () {
    test('انقطاع الاتصال والجهاز بلا شبكة ⇦ offline', () async {
      NetworkProbe.debugOverride = false;

      final failure = await ApiService.failureFor(
        _dio(type: DioExceptionType.connectionError),
      );

      expect(failure.kind, ApiFailureKind.offline);
      expect(failure.isConnectivity, isTrue);
      // العنوان في الواجهة يعلن الانقطاع؛ الرسالة تكمّله بالخطوة
      // التالية، فلا نؤكّد على تكرار النص بل على التصنيف والإرشاد.
      expect(failure.message, contains('الشبكة'));
    });

    test('انقطاع الاتصال والجهاز متصل ⇦ unreachable لا offline', () async {
      // الفرق جوهري: المستخدم متصل، والخادم هو المتوقف. إرساله لفحص
      // شبكته السليمة إضاعة لوقته.
      NetworkProbe.debugOverride = true;

      final failure = await ApiService.failureFor(
        _dio(type: DioExceptionType.connectionError),
      );

      expect(failure.kind, ApiFailureKind.unreachable);
      expect(failure.message, isNot(contains('لا يوجد اتصال')));
    });

    test('خطأ 500 ⇦ server وليس مشكلة اتصال', () async {
      NetworkProbe.debugOverride = true;

      final failure = await ApiService.failureFor(_dio(statusCode: 500));

      expect(failure.kind, ApiFailureKind.server);
      expect(failure.isConnectivity, isFalse);
      expect(failure.statusCode, 500);
    });

    test('401 ⇦ unauthorized', () async {
      NetworkProbe.debugOverride = true;

      final failure = await ApiService.failureFor(_dio(statusCode: 401));

      expect(failure.kind, ApiFailureKind.unauthorized);
      expect(failure.isConnectivity, isFalse);
    });

    test('400 ⇦ request، ولا يُعرض له زر إعادة محاولة', () async {
      NetworkProbe.debugOverride = true;

      final failure = await ApiService.failureFor(_dio(statusCode: 400));

      expect(failure.kind, ApiFailureKind.request);
      expect(failure.kind.isRetryable, isFalse);
    });

    test('انتهاء المهلة ⇦ timeout بلا فحص شبكة', () async {
      final failure = await ApiService.failureFor(
        _dio(type: DioExceptionType.receiveTimeout),
      );

      expect(failure.kind, ApiFailureKind.timeout);
      expect(failure.isConnectivity, isTrue);
    });
  });

  group('شاشة العطل تتبع سببه', () {
    testWidgets('شاشة «لا يوجد اتصال» لا تظهر إلا عند انقطاع فعلي',
        (tester) async {
      await tester.pumpWidget(
        _app(
          const KanafFailureState(
            message: 'تعذر جلب البيانات',
            kind: ApiFailureKind.offline,
          ),
        ),
      );

      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('عطل الخادم لا يدّعي انقطاع الاتصال', (tester) async {
      await tester.pumpWidget(
        _app(
          const KanafFailureState(
            message: 'حدث خطأ في الخادم.',
            kind: ApiFailureKind.server,
          ),
        ),
      );

      // هذا جوهر الإصلاح: مستخدم متصل يجب ألا يُقال له إنه غير متصل.
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
      expect(find.text('خطأ في الخادم'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    });

    testWidgets('انتهاء الجلسة له عنوانه الخاص', (tester) async {
      await tester.pumpWidget(
        _app(
          const KanafFailureState(
            message: 'تعذر التحقق من بيانات الحساب.',
            kind: ApiFailureKind.unauthorized,
          ),
        ),
      );

      expect(find.text('انتهت صلاحية الجلسة'), findsOneWidget);
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
    });

    testWidgets('الطلب المرفوض لا يعرض زر إعادة المحاولة', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        _app(
          KanafFailureState(
            message: 'بيانات غير صالحة.',
            kind: ApiFailureKind.request,
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('إعادة المحاولة'), findsNothing);
      expect(retried, isFalse);
    });

    testWidgets('الفراغ ليس عطلاً — لا تظهر شاشة الخطأ بلا سبب',
        (tester) async {
      await tester.pumpWidget(
        _app(
          KanafAsyncView(
            isLoading: false,
            isEmpty: true,
            emptyTitle: 'لا توجد بيانات بعد',
            builder: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      expect(find.text('لا توجد بيانات بعد'), findsOneWidget);
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
      expect(find.text('تعذر تحميل البيانات'), findsNothing);
    });

    testWidgets('وجود بيانات يمنع شاشة العطل رغم وجود رسالة خطأ',
        (tester) async {
      await tester.pumpWidget(
        _app(
          KanafAsyncView(
            isLoading: false,
            isEmpty: false,
            errorMessage: 'فشل التحديث',
            errorKind: ApiFailureKind.offline,
            builder: (_) => const Text('المحتوى المحفوظ'),
          ),
        ),
      );

      expect(find.text('المحتوى المحفوظ'), findsOneWidget);
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
    });
  });

  group('أداء الحركة', () {
    testWidgets('العناصر البعيدة في القائمة لا تُنشئ متحكّم حركة',
        (tester) async {
      // متحكّم حركة لكل صف في قائمة طويلة هدر خالص، ويجعل العناصر
      // تتلاشى من جديد كلما مرّرها المستخدم.
      await tester.pumpWidget(
        _app(
          ListView.builder(
            itemCount: 3,
            itemBuilder: (context, index) => KanafStaggeredEntrance(
              index: index + KanafStaggeredEntrance.maxAnimatedIndex + 1,
              child: Text('صف $index'),
            ),
          ),
        ),
      );

      // بلا حركة يظهر المحتوى فوراً في أول إطار.
      expect(find.text('صف 0'), findsOneWidget);
      expect(find.byType(FadeTransition), findsNothing);
    });

    testWidgets('العناصر الأولى تُحرَّك', (tester) async {
      await tester.pumpWidget(
        _app(
          const KanafStaggeredEntrance(index: 0, child: Text('أول عنصر')),
        ),
      );

      expect(find.byType(FadeTransition), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('أول عنصر'), findsOneWidget);
    });

    testWidgets('إعداد تقليل الحركة يُحترم', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KanafTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: KanafStaggeredEntrance(index: 0, child: Text('بلا حركة')),
            ),
          ),
        ),
      );

      expect(find.byType(FadeTransition), findsNothing);
      expect(find.text('بلا حركة'), findsOneWidget);
    });
  });
}
