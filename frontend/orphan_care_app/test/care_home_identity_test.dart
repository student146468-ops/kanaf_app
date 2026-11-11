import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:kanaf/l10n/kanaf_localizations.dart';
import 'package:kanaf/models/donation_model.dart';
import 'package:kanaf/providers/app_provider.dart';
import 'package:kanaf/providers/app_provider_scope.dart';
import 'package:kanaf/theme/kanaf_theme.dart';
import 'package:kanaf/views/donor/donation_receipt_screen.dart';
import 'package:kanaf/views/volunteer/my_certificates_view.dart';

class _LocalizationsDelegate extends LocalizationsDelegate<KanafLocalizations> {
  const _LocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<KanafLocalizations> load(Locale locale) =>
      SynchronousFuture(KanafLocalizations(locale, const {}));

  @override
  bool shouldReload(covariant LocalizationsDelegate<KanafLocalizations> old) =>
      false;
}

Widget _app({Widget? home, RouteFactory? onGenerateRoute}) => MaterialApp(
      theme: KanafTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        _LocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
      onGenerateRoute: onGenerateRoute,
    );

Future<void> _pumpCertificates(
    WidgetTester tester, List<Map<String, dynamic>> applications) async {
  final provider = AppProvider();
  provider.currentUser.addAll({'first_name': 'سارة', 'last_name': 'علي'});
  provider.volunteerApplications.addAll(applications);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
  await tester.pumpWidget(AppProviderScope(
    provider: provider,
    child: _app(home: const MyCertificatesView()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  testWidgets('certificate uses API issuer and fixed issue date',
      (tester) async {
    await _pumpCertificates(tester, [
      {
        'status': 'completed',
        'opportunity_title': 'دعم تعليمي',
        'care_home_name': 'دار الطفل أبوهريدة – طرابلس',
        'care_home_location': 'طرابلس',
        'opportunity_location': 'غريان',
        'certificate_issued_at': '2026-05-02T09:00:00Z',
        'updated_at': '2026-09-15T14:00:00Z',
      },
      {'status': 'accepted', 'opportunity_title': 'مشاركة لم تكتمل'},
    ]);

    expect(find.text('تشهد دار الطفل أبوهريدة – طرابلس بأن'), findsOneWidget);
    expect(find.text('طرابلس'), findsOneWidget);
    expect(find.textContaining('غريان'), findsNothing);
    expect(find.text('سارة علي'), findsOneWidget);
    expect(
      find.text(
          'صدرت في ${DateFormat('d MMMM y', 'ar').format(DateTime(2026, 5, 2))}'),
      findsOneWidget,
    );
    expect(find.textContaining('مشاركة لم تكتمل'), findsNothing);
    expect(find.textContaining('سبتمبر'), findsNothing);
  });

  testWidgets('missing issue date never falls back to mutable timestamps',
      (tester) async {
    await _pumpCertificates(tester, [
      {
        'status': 'completed',
        'opportunity_title': 'زيارة تطوعية',
        'updated_at': '2026-09-15T14:00:00Z',
        'created_at': '2026-01-01T14:00:00Z',
      },
    ]);

    expect(find.text('تشهد دار الرعاية بأن'), findsOneWidget);
    expect(find.textContaining('صدرت في'), findsNothing);
    expect(find.textContaining('أبوهريدة'), findsNothing);
  });

  test('donation care-home identity survives JSON and status updates', () {
    final donation = DonationModel.fromJson({
      'id': 12,
      'care_home_id': '7',
      'care_home_name': 'دار الطفل أبوهريدة – طرابلس',
      'care_home_location': 'طرابلس',
    });
    final restored =
        DonationModel.fromJson(donation.copyWith(status: 'completed').toJson());

    expect(restored.careHomeId, 7);
    expect(restored.careHomeName, 'دار الطفل أبوهريدة – طرابلس');
    expect(restored.careHomeLocation, 'طرابلس');
    expect(restored.status, 'completed');
    expect(donation.copyWith(careHomeId: 8).careHomeId, 8);
  });

  test('donations without a linked care home do not invent an identity', () {
    final donation = DonationModel.fromJson({
      'id': 13,
      'care_home_name': '  ',
      'care_home_location': null,
    });

    expect(donation.careHomeId, isNull);
    expect(donation.careHomeName, isNull);
    expect(donation.careHomeLocation, isNull);
    expect(donation.toJson()['care_home_name'], isNull);
  });

  testWidgets('donation receipt displays the API care-home identity',
      (tester) async {
    final donation = DonationModel.fromJson({
      'id': 12,
      'status': 'completed',
      'care_home_id': 7,
      'care_home_name': 'دار الطفل أبوهريدة – طرابلس',
      'care_home_location': 'طرابلس',
      'created_at': '2026-05-02T09:00:00Z',
    });
    await tester.pumpWidget(_app(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        settings: RouteSettings(arguments: donation),
        builder: (_) => const DonationReceiptScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('دار الطفل أبوهريدة – طرابلس'), findsOneWidget);
    expect(find.text('طرابلس'), findsOneWidget);
    expect(find.text('KNF-12'), findsWidgets);
  });
}
