import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/auth_navigation.dart';
import 'api_config.dart';
import 'api_failure.dart';

export 'api_failure.dart' show ApiFailureKind, ApiServiceException, NetworkProbe;

const String _registerServiceUnavailableMessage =
    'تعذر الاتصال بخدمة إنشاء الحساب حالياً. تأكد من تشغيل الخادم وحاول مرة أخرى.';
const String _loginServiceUnavailableMessage =
    'تعذر الاتصال بخدمة تسجيل الدخول حالياً. تأكد من تشغيل الخادم وحاول مرة أخرى.';
const String _duplicateEmailMessage =
    'هذا البريد الإلكتروني مستخدم بالفعل.';
const String _duplicatePhoneMessage = 'رقم الهاتف مستخدم بالفعل.';
const String _duplicateAccountMessage = 'بيانات الحساب مستخدمة بالفعل.';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  static String get baseUrl1 => ApiConfig.baseUrl;

  late final Dio _dio;

  /// عميل منفصل بلا معترضات، مخصّص لتجديد الرمز وحده.
  /// وجوده هو ما يكسر حلقة «تجديد يفشل ⇦ معترض ⇦ تجديد».
  late final Dio _refreshDio;

  /// عملية التجديد الجارية إن وُجدت — تمنع تزاحم عدة تجديدات معاً.
  Future<bool>? _refreshInFlight;

  /// يُبلَّغ عند سقوط الجلسة نهائياً، ليتولى التطبيق العودة لتسجيل
  /// الدخول. سابقاً كان الرمز يُمسح بصمت ويبقى المستخدم أمام شاشة
  /// معطّلة لا يفهم لماذا توقفت عن العمل.
  static final ValueNotifier<int> sessionExpiredSignal = ValueNotifier<int>(0);

  factory ApiService() => _instance;

  ApiService._internal() {
    debugPrint(
      'Kanaf API baseUrl=$baseUrl1 '
      'connectTimeout=30s receiveTimeout=30s',
    );
    final options = BaseOptions(
      baseUrl: baseUrl1,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
    );
    _dio = Dio(options);
    _refreshDio = Dio(options);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.data is! FormData) {
            options.headers['Content-Type'] = 'application/json';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode != 401) {
            return handler.next(error);
          }

          // تسجيل الدخول والتجديد لا يُعاد إرسالهما: 401 هنا يعني
          // بيانات خاطئة لا جلسة منتهية.
          final path = error.requestOptions.path;
          if (path.contains('/auth/login/') ||
              path.contains('/auth/refresh/')) {
            return handler.next(error);
          }

          if (await refreshAccessToken()) {
            try {
              final retry = await _dio.fetch(error.requestOptions);
              return handler.resolve(retry);
            } on DioException catch (retryError) {
              return handler.next(retryError);
            }
          }

          await _clearToken();
          // إشعار واحد يلتقطه التطبيق فيعيد المستخدم لتسجيل الدخول.
          sessionExpiredSignal.value++;
          handler.next(error);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    const path = '/auth/login/';
    final requestData = {'email': email, 'password': password};
    _logAuthRequest('POST', path, requestData);
    try {
      final response = await _dio.post(
        path,
        data: requestData,
      );
      _logAuthResponse('login', response);
      final responseData = _extractMap(response.data);
      await _saveAuthSession(responseData);
      return responseData;
    } on DioException catch (e) {
      debugPrint('Login API error: ${_developerErrorSummary(e)}');
      throw ApiServiceException(
        friendlyMessageForDioException(
          e,
          isLogin: true,
          authEndpoint: true,
        ),
      );
    } on ApiServiceException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Login response handling error: $e\n$stackTrace');
      throw const ApiServiceException(
        'تعذر إكمال تسجيل الدخول حالياً. حاول مرة أخرى.',
      );
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    const path = '/auth/register/';
    _logAuthRequest('POST', path, userData);
    try {
      final response = await _dio.post(path, data: userData);
      _logAuthResponse('register', response);
      final responseData = _extractMap(response.data);
      await _saveAuthSession(responseData);
      return responseData;
    } on DioException catch (e) {
      debugPrint('Register API error: ${_developerErrorSummary(e)}');
      throw ApiServiceException(
        friendlyMessageForDioException(
          e,
          isRegister: true,
          authEndpoint: true,
        ),
      );
    } on ApiServiceException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Register response handling error: $e\n$stackTrace');
      throw const ApiServiceException(
        'تعذر إكمال إنشاء الحساب حالياً. حاول مرة أخرى.',
      );
    }
  }

  Future<void> logout() async {
    await _clearToken();
  }

  /// يغيّر كلمة المرور من داخل الحساب.
  ///
  /// الخادم يبطل جلسات الأجهزة الأخرى ويعيد رموزاً جديدة للجهاز
  /// الحالي — نحفظها فوراً وإلا خرج المستخدم من حسابه بعد نجاح العملية.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    try {
      final response = await _dio.post('/auth/change-password/', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirm': newPasswordConfirm,
      });
      await _saveRefreshedSession(response.data);
    } on DioException catch (e) {
      throw ApiServiceException(
        _accountErrorMessage(e, 'تعذر تغيير كلمة المرور حالياً.'),
      );
    }
  }

  /// يغيّر البريد الإلكتروني للحساب. يشترط كلمة المرور الحالية.
  Future<Map<String, dynamic>> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      final response = await _dio.post('/auth/change-email/', data: {
        'new_email': newEmail,
        'current_password': currentPassword,
      });
      final data = _extractMap(response.data);
      await _saveRefreshedSession(data);
      return data;
    } on DioException catch (e) {
      throw ApiServiceException(
        _accountErrorMessage(e, 'تعذر تغيير البريد الإلكتروني حالياً.'),
      );
    }
  }

  /// يحفظ الرموز الجديدة التي يعيدها الخادم بعد إبطال الجلسات.
  Future<void> _saveRefreshedSession(dynamic data) async {
    if (data is! Map) return;
    final access = data['access'] ?? data['access_token'];
    if (access == null) return;
    await _saveToken(
      access,
      refreshToken: data['refresh'] ?? data['refresh_token'],
    );
  }

  /// يستخرج أول رسالة حقل من رد الخادم لعمليات الحساب.
  static String _accountErrorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      for (final key in const [
        'current_password',
        'new_password',
        'new_password_confirm',
        'new_email',
        'detail',
      ]) {
        final value = data[key];
        if (value == null) continue;
        final text = value is Iterable
            ? value.map((item) => item.toString()).join(' ')
            : value.toString();
        if (text.trim().isNotEmpty) return text;
      }
    }
    return friendlyMessageForDioException(e, fallback: fallback);
  }

  /// يطلب رمز استعادة كلمة المرور.
  ///
  /// الخادم يعيد 200 دائماً حتى لو كان البريد غير مسجّل (منعاً لجرد
  /// الحسابات)، فنجاح هذه الدالة يعني «تم قبول الطلب» لا «البريد موجود».
  Future<void> requestPasswordReset(String email) async {
    try {
      await _dio.post('/auth/password-reset/', data: {'email': email});
    } on DioException catch (e) {
      throw ApiServiceException(
        _errorMessage(e, 'تعذر إرسال رمز الاستعادة حالياً. حاول مرة أخرى.'),
      );
    }
  }

  /// يؤكد الرمز ويعيّن كلمة المرور الجديدة.
  ///
  /// لا يُعتبر ناجحاً إلا برد 2xx من الخادم — أي رمز خاطئ أو منتهٍ
  /// يرمي استثناءً بالرسالة العربية القادمة من الخادم.
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      await _dio.post('/auth/password-reset/confirm/', data: {
        'email': email,
        'code': code,
        'password': password,
        'password_confirm': passwordConfirm,
      });
    } on DioException catch (e) {
      throw ApiServiceException(
        _passwordResetErrorMessage(e),
      );
    }
  }

  /// يستخرج رسالة الخادم لأخطاء الاستعادة، مع تفضيل `detail`
  /// ثم أخطاء الحقول، قبل السقوط إلى رسالة عامة.
  static String _passwordResetErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }
      for (final key in const ['code', 'password', 'password_confirm', 'email']) {
        final value = data[key];
        if (value == null) continue;
        final text = value is Iterable
            ? value.map((item) => item.toString()).join(' ')
            : value.toString();
        if (text.trim().isNotEmpty) return text;
      }
    }
    if (e.response?.statusCode == 429) {
      return 'تمت محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.';
    }
    return friendlyMessageForDioException(
      e,
      fallback: 'تعذر تحديث كلمة المرور حالياً. حاول مرة أخرى.',
    );
  }

  /// يجدّد رمز الوصول.
  ///
  /// أُصلح فيها عيبان خطيران:
  ///
  /// 1. **حلقة لا نهائية**: كان التجديد يُرسل عبر `_dio` نفسه الحامل
  ///    لمعترض الأخطاء. فإذا رد الخادم 401 على التجديد، أطلق المعترض
  ///    `refreshAccessToken()` من جديد… إلى ما لا نهاية. صار التجديد
  ///    يمر عبر `_refreshDio` النظيف بلا معترضات.
  /// 2. **تزاحم**: عند انتهاء الجلسة تفشل كل الطلبات الجارية معاً،
  ///    فكان كل واحد منها يطلق تجديداً مستقلاً. أول تجديد ناجح يُبطل
  ///    رمز التحديث (rotation)، فتفشل البقية وتمسح الجلسة رغم نجاحها.
  ///    صار هناك تجديد واحد في الطيران يتشاركه الجميع.
  Future<bool> refreshAccessToken() {
    return _refreshInFlight ??= _performRefresh()
        .whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _refreshDio.post(
        '/auth/refresh/',
        data: {'refresh': refreshToken},
      );
      final data = response.data;
      final access = data is Map ? data['access'] ?? data['access_token'] : null;
      if (access == null || access.toString().isEmpty) {
        await _clearToken();
        return false;
      }
      await _saveToken(
        access.toString(),
        refreshToken: data is Map ? data['refresh'] ?? refreshToken : refreshToken,
      );
      return true;
    } on DioException {
      await _clearToken();
      return false;
    }
  }

  Future<Map<String, dynamic>> getMe() => _getMap('/auth/me/');

  Future<List<dynamic>> getOrphans() => _getList('/orphans/');
  Future<Map<String, dynamic>> getOrphanDetails(int id) =>
      _getMap('/orphans/$id/');
  Future<Map<String, dynamic>> addOrphan(Map<String, dynamic> data) =>
      _postPersistedMap(
        '/orphans/',
        data,
        'لم يؤكد الخادم حفظ بيانات اليتيم. حاول مرة أخرى.',
      );
  Future<Map<String, dynamic>> updateOrphan(
          int id, Map<String, dynamic> data) =>
      _putMap('/orphans/$id/', data);

  Future<List<dynamic>> getDonations() => _getList('/donations/');

  /// ينجح فقط إذا أعاد الخادم سجلاً محفوظاً بمعرّف حقيقي.
  Future<Map<String, dynamic>> createDonation(Map<String, dynamic> data) =>
      _postPersistedMap(
        '/donations/',
        data,
        'لم يؤكد الخادم حفظ التبرع. لم يتم خصم أو تسجيل أي شيء، حاول مرة أخرى.',
      );
  Future<List<dynamic>> getMyDonations() =>
      _getList('/donations/my-donations/');
  Future<Map<String, dynamic>> confirmDonationReceived(int id) =>
      _postMap('/donations/$id/confirm_received/', const {});

  Future<List<dynamic>> getVolunteers() => _getList('/volunteers/');
  Future<Map<String, dynamic>> applyAsVolunteer(Map<String, dynamic> data) =>
      _postPersistedMap(
        '/volunteers/apply/',
        data,
        'لم يؤكد الخادم حفظ طلب التطوع. حاول مرة أخرى.',
      );
  Future<List<dynamic>> getVolunteerOpportunities() =>
      _getList('/volunteer-opportunities/');
  Future<Map<String, dynamic>> applyToVolunteerOpportunity(
          int id, Map<String, dynamic> data) =>
      _postMap('/volunteer-opportunities/$id/apply/', data);
  Future<List<dynamic>> getVolunteerApplications() =>
      _getList('/volunteer-applications/my-applications/');

  Future<List<dynamic>> getSponsors() => _getList('/sponsors/');
  Future<Map<String, dynamic>> addSponsor(Map<String, dynamic> data) =>
      _postPersistedMap(
        '/sponsors/',
        data,
        'لم يؤكد الخادم حفظ بيانات الكافل. حاول مرة أخرى.',
      );

  Future<List<dynamic>> getInventory() => _getList('/inventory/');
  Future<Map<String, dynamic>> addInventoryItem(Map<String, dynamic> data) =>
      _postPersistedMap(
        '/inventory/',
        data,
        'لم يؤكد الخادم حفظ الصنف. حاول مرة أخرى.',
      );

  Future<Map<String, dynamic>> getDashboardStats() =>
      _getMap('/stats/dashboard/');
  Future<Map<String, dynamic>> getReports() => _getMap('/reports/');

  Future<List<dynamic>> getNeeds() => _getList('/needs/');
  Future<Map<String, dynamic>> getNeedDetails(int id) => _getMap('/needs/$id/');
  Future<Map<String, dynamic>> createNeed(Map<String, dynamic> data) =>
      _postPersistedMap(
        '/needs/',
        data,
        'لم يؤكد الخادم حفظ الاحتياج. حاول مرة أخرى.',
      );
  Future<Map<String, dynamic>> updateNeed(int id, Map<String, dynamic> data) =>
      _patchMap('/needs/$id/', data);
  Future<void> archiveNeed(int id) =>
      _send('POST', '/needs/$id/archive/', 'تعذر أرشفة الاحتياج');

  Future<List<dynamic>> getCareHomes() => _getList('/care-homes/');

  /// مواعيد زيارة دار بعينها. الكتابة تتم من لوحة التحكم لا من التطبيق.
  Future<List<dynamic>> getVisitHours(int careHomeId) =>
      _getList('/visit-hours/?care_home=$careHomeId');

  Future<List<dynamic>> getNotifications() => _getList('/notifications/');
  Future<void> markNotificationRead(int id) => _send(
        'POST',
        '/notifications/$id/mark_as_read/',
        'تعذر تحديث حالة الإشعار',
      );
  Future<void> markAllNotificationsRead() => _send(
        'POST',
        '/notifications/mark_all_as_read/',
        'تعذر تحديث حالة الإشعارات',
      );

  Future<List<dynamic>> _getList(String path) async {
    try {
      final response = await _dio.get(path);
      return _extractList(response.data);
    } on DioException catch (e) {
      throw await failureFor(e, fallback: 'تعذر جلب البيانات');
    }
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    try {
      final response = await _dio.get(path);
      return _extractMap(response.data);
    } on DioException catch (e) {
      throw await failureFor(e, fallback: 'تعذر جلب البيانات');
    }
  }

  Future<Map<String, dynamic>> _postMap(
      String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(path, data: data);
      return _extractMap(response.data);
    } on DioException catch (e) {
      throw await failureFor(e, fallback: 'تعذر حفظ البيانات');
    }
  }

  /// إنشاء سجل جديد مع ضمان الاستمرارية:
  /// لا تُعتبر العملية ناجحة إلا إذا أعاد الخادم كياناً يحمل معرّفاً حقيقياً.
  /// هذا هو الحاجز الذي يمنع ظهور "تم بنجاح" بينما قاعدة البيانات فارغة.
  Future<Map<String, dynamic>> _postPersistedMap(
    String path,
    Map<String, dynamic> data,
    String unconfirmedMessage,
  ) async {
    final created = await _postMap(path, data);
    if (!_hasPersistedId(created)) {
      debugPrint(
        'Kanaf API persistence guard tripped: path=$path '
        'response=${_safeLogData(created)}',
      );
      throw ApiServiceException(unconfirmedMessage);
    }
    return created;
  }

  /// طلب لا يعيد كياناً (أرشفة / حذف / تعليم كمقروء).
  /// Dio يرمي استثناءً على أي رمز حالة خارج 2xx، فالوصول إلى نهاية
  /// الدالة يعني أن الخادم أكد العملية فعلاً.
  Future<void> _send(String method, String path, String fallback) async {
    try {
      await _dio.request<dynamic>(
        path,
        options: Options(method: method),
      );
    } on DioException catch (e) {
      throw await failureFor(e, fallback: fallback);
    }
  }

  static bool _hasPersistedId(Map<String, dynamic> data) {
    final id = data['id'];
    if (id == null) return false;
    if (id is int) return id > 0;
    final parsed = int.tryParse(id.toString());
    return parsed != null && parsed > 0;
  }

  Future<Map<String, dynamic>> _putMap(
      String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(path, data: data);
      return _extractMap(response.data);
    } on DioException catch (e) {
      throw await failureFor(e, fallback: 'تعذر تحديث البيانات');
    }
  }

  Future<Map<String, dynamic>> _patchMap(
      String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch(path, data: data);
      return _extractMap(response.data);
    } on DioException catch (e) {
      throw await failureFor(e, fallback: 'تعذر تحديث البيانات');
    }
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['results'] is List) return data['results'] as List;
    return [];
  }

  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiServiceException(
      'تعذر قراءة استجابة الخادم. حاول مرة أخرى.',
    );
  }

  String _errorMessage(DioException e, String fallback) {
    return friendlyMessageForDioException(e, fallback: fallback);
  }

  /// يحوّل خطأ Dio إلى استثناء **مصنَّف**، لا نصاً مجرداً.
  ///
  /// التصنيف هو ما يمكّن الواجهة من التمييز بين «لا شبكة» و«الخادم
  /// يعطب» و«انتهت جلستك»، فلا تُعرض شاشة انقطاع الاتصال لمستخدم
  /// متصل. الفحص الفعلي للشبكة يجري فقط عند `connectionError`، أي
  /// الحالة الوحيدة الغامضة — فلا نضيف زمناً على المسار السليم.
  static Future<ApiServiceException> failureFor(
    DioException e, {
    String fallback = 'تعذر إكمال العملية حالياً. حاول مرة أخرى.',
    bool isLogin = false,
    bool isRegister = false,
    bool authEndpoint = false,
  }) async {
    final message = friendlyMessageForDioException(
      e,
      fallback: fallback,
      isLogin: isLogin,
      isRegister: isRegister,
      authEndpoint: authEndpoint,
    );
    final statusCode = e.response?.statusCode;
    final kind = await _kindFor(e);

    // الرسالة القديمة كانت تقول «لا يوجد اتصال بالإنترنت» لكل
    // `connectionError`. بعد التصنيف صار لكل حالة نصّها الصحيح:
    // فلا يُتّهم اتصال المستخدم السليم، ولا يُقال لمن هو بلا شبكة
    // إن «الخدمة متوقفة».
    if (kind == ApiFailureKind.offline) {
      // العنوان في الواجهة يقول «لا يوجد اتصال بالإنترنت»، فالرسالة
      // هنا تكمّله بالخطوة التالية بدل أن تكرّره.
      return ApiServiceException(
        'تحقق من الشبكة أو بيانات الجوال ثم أعد المحاولة.',
        kind: kind,
      );
    }

    if (kind == ApiFailureKind.unreachable && !authEndpoint) {
      return ApiServiceException(
        'اتصالك يعمل، لكن تعذر الوصول إلى خدمة كَنَفْ. حاول بعد قليل.',
        kind: kind,
        statusCode: statusCode,
      );
    }

    return ApiServiceException(message, kind: kind, statusCode: statusCode);
  }

  static Future<ApiFailureKind> _kindFor(DioException e) async {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiFailureKind.timeout;
      case DioExceptionType.connectionError:
        // الحالة الغامضة الوحيدة: جهاز بلا شبكة، أم خادم لا يستجيب؟
        return await NetworkProbe.hasConnection()
            ? ApiFailureKind.unreachable
            : ApiFailureKind.offline;
      default:
        break;
    }

    final statusCode = e.response?.statusCode;
    if (statusCode == null) {
      return await NetworkProbe.hasConnection()
          ? ApiFailureKind.unreachable
          : ApiFailureKind.offline;
    }
    if (statusCode == 401 || statusCode == 403) {
      return ApiFailureKind.unauthorized;
    }
    if (statusCode >= 500) return ApiFailureKind.server;
    if (statusCode >= 400) return ApiFailureKind.request;
    return ApiFailureKind.unknown;
  }

  static String friendlyMessageForDioException(
    DioException e, {
    String fallback = 'تعذر إكمال العملية حالياً. حاول مرة أخرى.',
    bool isLogin = false,
    bool isRegister = false,
    bool authEndpoint = false,
  }) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'استغرق الاتصال وقتاً أطول من المتوقع. حاول مرة أخرى.';
    }

    if (e.response == null) {
      if (e.type == DioExceptionType.connectionError) {
        if (authEndpoint) {
          return isRegister
              ? _registerServiceUnavailableMessage
              : _loginServiceUnavailableMessage;
        }
        return 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.';
      }
      return 'تعذر الاتصال بالخادم حالياً. حاول مرة أخرى لاحقاً.';
    }

    final statusCode = e.response?.statusCode;
    if (authEndpoint && _isServerConfigurationError(e.response?.data)) {
      return isRegister
          ? _registerServiceUnavailableMessage
          : _loginServiceUnavailableMessage;
    }

    if (authEndpoint && statusCode == 404) {
      return isRegister
          ? 'تعذر الوصول إلى خدمة إنشاء الحساب حالياً.'
          : 'تعذر الوصول إلى خدمة تسجيل الدخول حالياً.';
    }

    if (authEndpoint && statusCode == 400 && _looksLikeHtml(e.response?.data)) {
      return isRegister
          ? _registerServiceUnavailableMessage
          : _loginServiceUnavailableMessage;
    }

    if (statusCode == 401 || statusCode == 403) {
      return isLogin
          ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.'
          : 'تعذر التحقق من بيانات الحساب.';
    }

    if (statusCode == 400 || statusCode == 409) {
      final validationMessage = _validationMessage(
        e.response?.data,
        isLogin: isLogin,
        isRegister: isRegister,
      );
      if (validationMessage != null) return validationMessage;
    }

    if (statusCode == 429) {
      return 'تمت محاولات كثيرة خلال وقت قصير. حاول مرة أخرى لاحقاً.';
    }

    if (statusCode != null && statusCode >= 500) {
      return 'حدث خطأ في الخادم. حاول مرة أخرى لاحقاً.';
    }

    return fallback;
  }

  static String? _validationMessage(
    dynamic data, {
    required bool isLogin,
    required bool isRegister,
  }) {
    if (isLogin) return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

    final text = _flattenErrorText(data).toLowerCase();
    final hasConflictText = text.contains('already') ||
        text.contains('exists') ||
        text.contains('unique') ||
        text.contains('مستخدم');
    if (_fieldHasConflict(data, const ['phone_number', 'phone']) ||
        ((text.contains('phone_number') || text.contains('phone')) &&
            hasConflictText)) {
      return _duplicatePhoneMessage;
    }
    if (_fieldHasConflict(data, const ['email'])) {
      return _duplicateEmailMessage;
    }
    if (text.contains('username or email already exists') ||
        text.contains('email already exists')) {
      return _duplicateEmailMessage;
    }
    if (_fieldHasConflict(data, const ['username']) || hasConflictText) {
      return _duplicateAccountMessage;
    }
    if (text.contains('password') && text.contains('match')) {
      return 'كلمة المرور وتأكيدها غير متطابقين.';
    }
    if (text.contains('role')) {
      return 'نوع الحساب غير صحيح. الرجاء اختيار نوع الحساب مرة أخرى.';
    }
    if (text.contains('email')) {
      return 'البريد الإلكتروني غير صحيح أو مطلوب.';
    }
    if (text.contains('password')) {
      return 'كلمة المرور غير صحيحة أو غير مكتملة.';
    }
    if (text.contains('phone')) {
      return 'رقم الهاتف غير صحيح أو مطلوب.';
    }
    if (isRegister) return 'تحقق من بيانات الحساب وحاول مرة أخرى.';
    return null;
  }

  static bool _fieldHasConflict(dynamic data, List<String> fieldNames) {
    if (data is! Map) return false;

    for (final fieldName in fieldNames) {
      final value = data[fieldName];
      if (value == null) continue;

      final text = _flattenErrorText(value).toLowerCase();
      if (text.contains('already') ||
          text.contains('exists') ||
          text.contains('unique') ||
          text.contains('مستخدم')) {
        return true;
      }
    }

    return false;
  }

  static bool _isServerConfigurationError(dynamic data) {
    final text = _flattenErrorText(data).toLowerCase();
    return text.contains('disallowedhost') ||
        text.contains('invalid http_host header') ||
        text.contains('allowed_hosts');
  }

  static bool _looksLikeHtml(dynamic data) {
    return data is String && data.trimLeft().toLowerCase().startsWith('<html');
  }

  static String _flattenErrorText(dynamic data) {
    if (data is Map) {
      return data.entries
          .map((entry) => '${entry.key} ${_flattenErrorText(entry.value)}')
          .join(' ');
    }
    if (data is Iterable) {
      return data.map(_flattenErrorText).join(' ');
    }
    return data?.toString() ?? '';
  }

  static String _developerErrorSummary(DioException e) {
    final data = e.response?.data;
    final dataType = data == null ? 'none' : data.runtimeType.toString();
    return 'url=${e.requestOptions.uri}, method=${e.requestOptions.method}, '
        'type=${e.type}, status=${e.response?.statusCode}, '
        'message=${e.message}, responseType=$dataType, '
        'response=${_safeLogData(e.response?.data)}, '
        'request=${_safeLogData(e.requestOptions.data)}';
  }

  static void _logAuthRequest(
    String method,
    String path,
    Map<String, dynamic> data,
  ) {
    debugPrint(
      'Kanaf API request: method=$method url=$baseUrl1$path '
      'body=${_safeLogData(data)}',
    );
  }

  static void _logAuthResponse(String operation, Response<dynamic> response) {
    debugPrint(
      'Kanaf API $operation response: '
      'url=${response.requestOptions.uri}, '
      'status=${response.statusCode}, '
      'body=${_safeLogData(response.data)}',
    );
  }

  static String _safeLogData(dynamic data) {
    Object? sanitize(dynamic value) {
      if (value is Map) {
        return value.map((key, dynamic child) {
          final keyText = key.toString().toLowerCase();
          if (keyText.contains('password') ||
              keyText.contains('token') ||
              keyText == 'access' ||
              keyText == 'refresh') {
            return MapEntry(key, '***');
          }
          return MapEntry(key, sanitize(child));
        });
      }
      if (value is Iterable) return value.map(sanitize).toList();
      return value;
    }

    final sanitized = sanitize(data);
    final text = sanitized?.toString() ?? 'null';
    return text.length > 900 ? '${text.substring(0, 900)}...' : text;
  }

  Future<void> _saveToken(dynamic token, {dynamic refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token.toString());
    }
    if (refreshToken != null) {
      await prefs.setString('refresh_token', refreshToken.toString());
    }
  }

  Future<void> _saveAuthSession(Map<String, dynamic> data) async {
    final token = _tokenFromAuthResponse(data);
    final role = _roleFromAuthResponse(data);
    await _saveToken(token, refreshToken: _refreshTokenFromAuthResponse(data));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  String _tokenFromAuthResponse(Map<String, dynamic> data) {
    final token = data['access'] ?? data['access_token'] ?? data['token'];
    if (token == null || token.toString().isEmpty) {
      throw const ApiServiceException(
        'تعذر إنشاء جلسة آمنة. حاول تسجيل الدخول مرة أخرى.',
      );
    }
    return token.toString();
  }

  dynamic _refreshTokenFromAuthResponse(Map<String, dynamic> data) {
    return data['refresh'] ?? data['refresh_token'];
  }

  String _roleFromAuthResponse(Map<String, dynamic> data) {
    final role = AuthNavigation.roleFromAuthResponse(data);
    if (role == null) {
      throw const ApiServiceException(
        'تعذر تحديد نوع الحساب. الرجاء اختيار نوع الحساب مرة أخرى.',
      );
    }
    return role;
  }

  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthNavigation.normalizeRole(prefs.getString('user_role'));
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_role');
  }

  Future<bool> isAuthenticated() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }
}
