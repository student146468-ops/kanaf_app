import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaf/services/api_config.dart';
import 'package:kanaf/services/api_service.dart';
import 'package:kanaf/utils/auth_navigation.dart';

void main() {
  group('AuthNavigation', () {
    // التطبيق سطح جمهور: متبرع ومتطوع فقط. دار الرعاية والإدارة
    // تُدار من لوحة الويب، والخادم نفسه يرفض التسجيل بدور care_home.
    test('يوجّه دورَي الجمهور فقط إلى أقسامهما', () {
      expect(AuthNavigation.homeRouteForRole('donor'), '/supporter_home');
      expect(AuthNavigation.homeRouteForRole('volunteer'), '/volunteer_home');
      expect(AuthNavigation.homeRouteForRole('supporter'), '/supporter_home');
    });

    test('لا يوجّه الأدوار الإدارية إلى أي شاشة في التطبيق', () {
      expect(AuthNavigation.homeRouteForRole('care_home'), isNull);
      expect(AuthNavigation.homeRouteForRole('carehome'), isNull);
      expect(AuthNavigation.homeRouteForRole('orphanage'), isNull);
      expect(AuthNavigation.homeRouteForRole('CARE-HOME'), isNull);
      expect(AuthNavigation.homeRouteForRole('admin'), isNull);
    });

    test('يميّز الحساب الإداري عن الدور المجهول', () {
      // التمييز يغيّر الرسالة المعروضة: «حسابك يُدار من الويب» مقابل
      // «تعذر تحديد نوع الحساب» — والخلط بينهما يضلّل المستخدم.
      expect(
        AuthNavigation.webOnlyRoles
            .contains(AuthNavigation.normalizeRole('care_home')),
        isTrue,
      );
      expect(
        AuthNavigation.webOnlyRoles
            .contains(AuthNavigation.normalizeRole('admin')),
        isTrue,
      );
      expect(AuthNavigation.normalizeRole('unknown_role'), isNull);
    });

    test('الأدوار المجهولة تبقى مجهولة — لا تخمين', () {
      expect(AuthNavigation.homeRouteForRole('unknown_role'), isNull);
      expect(AuthNavigation.homeRouteForRole(null), isNull);
      expect(AuthNavigation.homeRouteForRole(''), isNull);
    });

    test('يستنتج دور الإدارة من أعلام is_staff المنطقية', () {
      expect(
        AuthNavigation.roleFromAuthResponse({
          'access': 'token',
          'user': {'is_staff': true},
        }),
        AuthNavigation.adminRole,
      );
    });

    test('extracts role from auth API user payload', () {
      expect(
        AuthNavigation.roleFromAuthResponse({
          'access': 'token',
          'user': {'role': 'donor'},
        }),
        'donor',
      );
      expect(
        AuthNavigation.roleFromAuthResponse({
          'access': 'token',
          'user': {
            'profile': {'role': 'volunteer'}
          },
        }),
        'volunteer',
      );
      expect(
        AuthNavigation.roleFromAuthResponse({'access': 'token'}),
        isNull,
      );
    });
  });

  group('Auth API error messages', () {
    test('resolves API base URL by platform', () {
      expect(
        ApiConfig.resolveBaseUrl(
          configuredBaseUrl: '',
          isWeb: true,
          isDebug: true,
          targetPlatform: TargetPlatform.windows,
        ),
        'https://kanafapp.pythonanywhere.com/api',
      );
      expect(
        ApiConfig.resolveBaseUrl(
          configuredBaseUrl: '',
          isWeb: false,
          isDebug: true,
          targetPlatform: TargetPlatform.android,
        ),
        'https://kanafapp.pythonanywhere.com/api',
      );
      expect(
        ApiConfig.resolveBaseUrl(
          configuredBaseUrl: 'http://192.168.1.10:8000/api/',
          isWeb: false,
          isDebug: true,
          targetPlatform: TargetPlatform.android,
        ),
        'http://192.168.1.10:8000/api',
      );
    });

    test('does not expose technical details for missing login endpoint', () {
      final message = ApiService.friendlyMessageForDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login/'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/login/'),
            statusCode: 404,
            data: '<html>Page not found at /api/auth/login/</html>',
          ),
        ),
        isLogin: true,
        authEndpoint: true,
      );

      expect(message, 'تعذر الوصول إلى خدمة تسجيل الدخول حالياً.');
      expect(message, isNot(contains('404')));
      expect(message, isNot(contains('html')));
    });

    test('maps invalid login credentials to a user friendly message', () {
      final message = ApiService.friendlyMessageForDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login/'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/login/'),
            statusCode: 401,
            data: {'detail': 'invalid credentials'},
          ),
        ),
        isLogin: true,
        authEndpoint: true,
      );

      expect(message, 'البريد الإلكتروني أو كلمة المرور غير صحيحة.');
    });

    test('maps duplicate register email to a user friendly message', () {
      final message = ApiService.friendlyMessageForDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/register/'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/register/'),
            statusCode: 400,
            data: {
              'email': ['email already exists'],
              'detail': 'email already exists',
            },
          ),
        ),
        isRegister: true,
        authEndpoint: true,
      );

      expect(message, 'هذا البريد الإلكتروني مستخدم بالفعل.');
    });

    test('does not map server configuration pages to duplicate email', () {
      final message = ApiService.friendlyMessageForDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/register/'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/register/'),
            statusCode: 400,
            data:
                '<html><title>DisallowedHost</title>Invalid HTTP_HOST header. ALLOWED_HOSTS</html>',
          ),
        ),
        isRegister: true,
        authEndpoint: true,
      );

      expect(
        message,
        'تعذر الاتصال بخدمة إنشاء الحساب حالياً. تأكد من تشغيل الخادم وحاول مرة أخرى.',
      );
      expect(message, isNot('هذا البريد الإلكتروني مستخدم بالفعل.'));
    });

    test('does not map unknown uniqueness conflicts to duplicate email', () {
      final message = ApiService.friendlyMessageForDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/register/'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/register/'),
            statusCode: 400,
            data: {'detail': 'unique constraint failed'},
          ),
        ),
        isRegister: true,
        authEndpoint: true,
      );

      expect(message, 'بيانات الحساب مستخدمة بالفعل.');
      expect(message, isNot('هذا البريد الإلكتروني مستخدم بالفعل.'));
    });

    test('maps duplicate register phone to a phone message', () {
      final message = ApiService.friendlyMessageForDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/register/'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/register/'),
            statusCode: 400,
            data: {
              'phone_number': ['phone number already exists'],
              'detail': 'phone number already exists',
            },
          ),
        ),
        isRegister: true,
        authEndpoint: true,
      );

      expect(message, 'رقم الهاتف مستخدم بالفعل.');
      expect(message, isNot(contains('البريد')));
    });

    test('maps timeout and connection errors without DioException text', () {
      final timeoutMessage = ApiService.friendlyMessageForDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login/'),
          type: DioExceptionType.connectionTimeout,
        ),
        isLogin: true,
        authEndpoint: true,
      );
      final connectionMessage = ApiService.friendlyMessageForDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login/'),
          type: DioExceptionType.connectionError,
        ),
        isLogin: true,
        authEndpoint: true,
      );

      expect(
        timeoutMessage,
        'استغرق الاتصال وقتاً أطول من المتوقع. حاول مرة أخرى.',
      );
      expect(
        connectionMessage,
        'تعذر الاتصال بخدمة تسجيل الدخول حالياً. تأكد من تشغيل الخادم وحاول مرة أخرى.',
      );
      expect(timeoutMessage, isNot(contains('DioException')));
      expect(connectionMessage, isNot(contains('DioException')));
    });
  });
}
