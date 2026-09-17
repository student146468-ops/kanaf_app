import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaf/l10n/kanaf_localizations.dart';
import 'package:kanaf/services/api_service.dart';
import 'package:kanaf/services/push_notification_service.dart';
import 'package:kanaf/views/email_verification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Localizations extends LocalizationsDelegate<KanafLocalizations> {
  const _Localizations(this.values);
  final Map<String, String> values;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<KanafLocalizations> load(Locale locale) =>
      SynchronousFuture(KanafLocalizations(locale, values));

  @override
  bool shouldReload(covariant _Localizations old) => false;
}

class _VerificationApi implements ApiService {
  _VerificationApi(this.role);
  final String role;
  final result = Completer<Map<String, dynamic>>();
  int verifyCalls = 0;

  @override
  Future<Map<String, dynamic>> verifyEmailOtp({
    int? userId,
    required String email,
    required String code,
  }) async {
    verifyCalls++;
    final response = await result.future;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'verified-session');
    await prefs.setString('user_role', role);
    return response;
  }

  @override
  Future<void> saveActiveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> strings;

  setUpAll(() async {
    final json =
        jsonDecode(await rootBundle.loadString('assets/l10n/en.arb')) as Map;
    strings = {
      for (final key in json.keys)
        if (json[key] is String) key as String: json[key] as String
    };
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('push service is safe before Firebase initialization', () async {
    expect(Firebase.apps, isEmpty);
    final service = PushNotificationService.instance;
    await service.registerCurrentDevice();
    await service.deactivateCurrentDeviceToken();
  });

  for (final role in ['donor', 'volunteer']) {
    testWidgets('verified $role opens home without restarting or Firebase',
        (tester) async {
      expect(Firebase.apps, isEmpty);
      final api = _VerificationApi(role);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: [_Localizations(strings)],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(name: settings.name, arguments: {
            'email': 'verify@example.com',
            'user_id': 1,
            'role': role,
          }),
          builder: (_) => settings.name == '/'
              ? EmailVerificationScreen(apiService: api)
              : Scaffold(body: Text('home:${settings.name}')),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      // A queued keyboard submit must not consume the one-time code twice.
      tester
          .widget<TextField>(find.byType(TextField))
          .onSubmitted!('123456');
      expect(api.verifyCalls, 1);
      api.result.complete({'role': role, 'access': 'verified-session'});
      await tester.pumpAndSettle();
      final route = role == 'donor' ? '/supporter_home' : '/volunteer_home';
      expect(find.text('home:$route'), findsOneWidget);
      expect(find.byType(EmailVerificationScreen), findsNothing);
      expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), 'verified-session');
      expect(tester.takeException(), isNull);
    });
  }
}
