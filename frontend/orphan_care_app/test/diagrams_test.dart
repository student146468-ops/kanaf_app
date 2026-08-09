import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// مولّد مخططات التوثيق الأكاديمي.
///
/// شغّله بـ: `flutter test test/diagrams_test.dart --update-goldens`
/// تُكتب الصور في `test/diagrams/`.
///
/// نرسمها بمحرّك Flutter لا بأداة رسم خارجية، لسببين: المحرّك يتقن
/// تشكيل الحروف العربية ووصلها (وهو ما تفشل فيه أغلب أدوات المخططات)،
/// وهو موجود في المشروع أصلاً ومُثبت أنه يعمل في هذه البيئة.
///
/// المحتوى مشتق من الكود الفعلي: الكيانات وعلاقاتها من نماذج Django،
/// وحالات الاستخدام من المسارات المسجَّلة في الراوتر.

const Color _ink = Color(0xFF1F2937);
const Color _muted = Color(0xFF6B7280);
const Color _brand = Color(0xFFC55A11);
const Color _brandSoft = Color(0xFFFCE4D6);
const Color _line = Color(0xFF9AA1AD);
const Color _paper = Colors.white;

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }

  await load('Vazirmatn', [
    'assets/fonts/Vazirmatn-Regular.ttf',
    'assets/fonts/Vazirmatn-SemiBold.ttf',
    'assets/fonts/Vazirmatn-Bold.ttf',
  ]);
  await load('Tajawal', [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
  ]);
}

TextStyle _style({
  double size = 13,
  FontWeight weight = FontWeight.w600,
  Color color = _ink,
}) {
  return TextStyle(
    fontFamily: 'Vazirmatn',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.35,
  );
}

/// إطار المخطط: خلفية بيضاء واتجاه عربي وعنوان أعلى الصورة.
Widget _sheet({
  required String title,
  required Widget child,
  double width = 1100,
  double height = 780,
}) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(1200, 900)),
      child: Container(
        width: width,
        height: height,
        color: _paper,
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: _style(size: 20, weight: FontWeight.w800, color: _brand),
            ),
            const SizedBox(height: 6),
            Container(height: 2, color: _brandSoft),
            const SizedBox(height: 18),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

// ── لبنات الرسم ──────────────────────────────────────────────

/// جهة متفاعلة (Actor) في مخطط حالات الاستخدام.
class _Actor extends StatelessWidget {
  const _Actor({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(46, 62), painter: _StickPainter()),
        const SizedBox(height: 6),
        SizedBox(
          width: 110,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: _style(size: 13, weight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _StickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _ink
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    canvas.drawCircle(Offset(cx, 11), 10, paint);
    canvas.drawLine(Offset(cx, 21), Offset(cx, 42), paint);
    canvas.drawLine(Offset(cx - 15, 30), Offset(cx + 15, 30), paint);
    canvas.drawLine(Offset(cx, 42), Offset(cx - 13, 60), paint);
    canvas.drawLine(Offset(cx, 42), Offset(cx + 13, 60), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// حالة استخدام: بيضاوي بنص داخله.
///
/// ارتفاعها ثابت عمداً: المخطط يوصّل الأسهم بإحداثيات محسوبة، وارتفاع
/// متغيّر حسب طول النص يجعل كل سهم يشير إلى فراغ.
class _UseCase extends StatelessWidget {
  const _UseCase({required this.label, this.width = 210, this.height = 48});

  final String label;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _brandSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _brand, width: 1.3),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        style: _style(size: 12, weight: FontWeight.w700),
      ),
    );
  }
}

/// مخطط حالات استخدام بجهة واحدة على اليمين وحالاتها على اليسار.
///
/// يبني التخطيط والأسهم من نفس القائمة، فلا يمكن أن يفترقا.
class _UseCaseSheet extends StatelessWidget {
  const _UseCaseSheet({required this.actor, required this.cases});

  final String actor;
  final List<String> cases;

  static const double _pitch = 74;
  static const double _caseHeight = 48;
  static const double _caseWidth = 240;
  static const double _caseLeft = 90;
  static const double _actorLeft = 800;
  static const double _top = 16;

  @override
  Widget build(BuildContext context) {
    final centers = [
      for (var i = 0; i < cases.length; i++) _top + _caseHeight / 2 + i * _pitch,
    ];
    final actorY = centers.reduce((a, b) => a + b) / centers.length;

    return Stack(
      children: [
        _Wires(
          links: [
            for (final y in centers)
              (const Offset(_actorLeft - 6, 0).translate(0, actorY),
                  Offset(_caseLeft + _caseWidth + 6, y), false),
          ],
        ),
        for (var i = 0; i < cases.length; i++)
          Positioned(
            left: _caseLeft,
            top: _top + i * _pitch,
            child: _UseCase(
              label: cases[i],
              width: _caseWidth,
              height: _caseHeight,
            ),
          ),
        Positioned(
          left: _actorLeft,
          top: actorY - 38,
          child: _Actor(label: actor),
        ),
      ],
    );
  }
}

/// صندوق كيان في مخطط الأصناف/الكيانات.
class _EntityBox extends StatelessWidget {
  const _EntityBox({
    required this.title,
    required this.subtitle,
    required this.fields,
    this.width = 218,
  });

  final String title;
  final String subtitle;
  final List<String> fields;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: _paper,
        border: Border.all(color: _line, width: 1.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const BoxDecoration(
              color: _brandSoft,
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: _style(size: 13.5, weight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: _style(size: 10.5, weight: FontWeight.w600,
                      color: _muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      // عزل ثنائي الاتجاه: أسماء الحقول لاتينية داخل
                      // بطاقة عربية، وبدون العزل يقفز سهم المفتاح
                      // الخارجي إلى موضع خاطئ أو يختفي.
                      '\u2068$field\u2069',
                      style: _style(
                        size: 10.5,
                        weight: FontWeight.w500,
                        color: _ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// يرسم مجموعة أسهم فوق تخطيط مطلق داخل Stack.
class _Wires extends StatelessWidget {
  const _Wires({required this.links});

  /// كل رابط: (البداية، النهاية، متقطّع؟)
  final List<(Offset, Offset, bool)> links;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _ArrowPainter(links: links)),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.links});

  final List<(Offset, Offset, bool)> links;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (from, to, dashed) in links) {
      final paint = Paint()
        ..color = _line
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;

      if (dashed) {
        const dash = 7.0;
        const gap = 5.0;
        final total = (to - from).distance;
        if (total == 0) continue;
        final direction = (to - from) / total;
        var travelled = 0.0;
        while (travelled < total) {
          final start = from + direction * travelled;
          final end = from + direction * math.min(travelled + dash, total);
          canvas.drawLine(start, end, paint);
          travelled += dash + gap;
        }
      } else {
        canvas.drawLine(from, to, paint);
      }

      final angle = (to - from).direction;
      const headLength = 10.0;
      const spread = 0.42;
      final head = Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(
          to.dx - headLength * math.cos(angle - spread),
          to.dy - headLength * math.sin(angle - spread),
        )
        ..moveTo(to.dx, to.dy)
        ..lineTo(
          to.dx - headLength * math.cos(angle + spread),
          to.dy - headLength * math.sin(angle + spread),
        );
      canvas.drawPath(head, paint..strokeWidth = 1.7);
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) => true;
}

/// عمود حياة في مخطط التسلسل.
class _Lifeline extends StatelessWidget {
  const _Lifeline({required this.label, required this.height});

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: _brandSoft,
            border: Border.all(color: _brand, width: 1.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: _style(size: 12.5, weight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size(2, height),
            painter: _DashedSpine(),
          ),
        ),
      ],
    );
  }
}

class _DashedSpine extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _line
      ..strokeWidth = 1.2;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, math.min(y + 6, size.height)),
          paint);
      y += 11;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// رسالة أفقية بين عمودَي حياة.
class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.top,
    required this.fromX,
    required this.toX,
    this.dashed = false,
  });

  final String text;
  final double top;
  final double fromX;
  final double toX;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final left = math.min(fromX, toX);
    final width = (toX - fromX).abs();

    return Positioned(
      top: top,
      left: left,
      width: width,
      child: Column(
        children: [
          Text(
            // عزل ثنائي الاتجاه (FSI…PDI): بدونه يُعاد ترتيب النص
            // اللاتيني داخل فقرة عربية، فيظهر مسار مثل
            // POST /api/donations/ معكوس الأجزاء ويربك القارئ التقني.
            '\u2068$text\u2069',
            textAlign: TextAlign.center,
            style: _style(size: 11, weight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 12,
            width: width,
            child: CustomPaint(
              painter: _ArrowPainter(
                links: [
                  (
                    Offset(fromX < toX ? 0 : width, 5),
                    Offset(fromX < toX ? width : 0, 5),
                    dashed,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(_loadFonts);

  /// يرسم لوحة ويحفظها صورة.
  ///
  /// نافذة العرض أوسع من أكبر لوحة عمداً. كل لوحة تحدّد مقاسها بنفسها،
  /// واللقطة تُؤخذ لحدود اللوحة لا لحدود النافذة — فالفائض لا يظهر.
  /// النافذة الضيّقة كانت تقصّ اللوحات الأعرض: مخطط الكيانات فقد
  /// عموداً كاملاً وصفّاً بأكمله.
  Future<void> draw(
    WidgetTester tester,
    String name,
    Widget sheet, {
    Size size = const Size(1440, 1000),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: sheet,
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(Directionality).first,
      matchesGoldenFile('diagrams/$name.png'),
    );
  }

  group('مخططات التوثيق', () {
    testWidgets('حالات استخدام المتبرع', (tester) async {
      await draw(
        tester,
        'usecase_donor',
        _sheet(
          title: 'مخطط حالات الاستخدام — المتبرع',
          height: 640,
          child: const _UseCaseSheet(
            actor: 'المتبرع',
            cases: [
              'إنشاء حساب وتسجيل الدخول',
              'تصفّح الاحتياجات والبحث فيها',
              'تصفّح دور الرعاية ومواعيد الزيارة',
              'التبرع المالي',
              'التبرع العيني',
              'متابعة سجل تبرعاتي',
              'تتبّع حالة الاحتياج',
            ],
          ),
        ),
      );
    });

    testWidgets('حالات استخدام المتطوع', (tester) async {
      await draw(
        tester,
        'usecase_volunteer',
        _sheet(
          title: 'مخطط حالات الاستخدام — المتطوع',
          height: 580,
          child: const _UseCaseSheet(
            actor: 'المتطوع',
            cases: [
              'إنشاء حساب وتسجيل الدخول',
              'تصفّح فرص التطوع والبحث فيها',
              'التقديم على فرصة تطوع',
              'متابعة جدولي وحالة طلباتي',
              'عرض شهاداتي وتقييماتي',
              'استقبال الإشعارات',
            ],
          ),
        ),
      );
    });

    testWidgets('حالات استخدام مدير الدار', (tester) async {
      await draw(
        tester,
        'usecase_care_home',
        _sheet(
          title: 'مخطط حالات الاستخدام — مدير دار الرعاية (لوحة التحكم)',
          height: 580,
          child: const _UseCaseSheet(
            actor: 'مدير دار الرعاية',
            cases: [
              'إدارة ملف الدار ومواعيد الزيارة',
              'نشر الاحتياجات وتعديلها وأرشفتها',
              'استقبال التبرعات وتأكيد الاستلام',
              'نشر فرص التطوع',
              'قبول طلبات التطوع أو رفضها',
              'تقييم المتطوعين بعد المشاركة',
            ],
          ),
        ),
      );
    });

    testWidgets('مخطط الكيانات والعلاقات', (tester) async {
      // شبكة من أربعة أعمدة وثلاثة صفوف، والعمود الثاني تحت `User`
      // يُترك فارغاً عمداً ليكون ممراً للوصلات الطويلة بلا تقاطع.
      const c1 = 0.0, c2 = 348.0, c3 = 696.0, c4 = 1044.0;
      const r1 = 10.0, r2 = 320.0, r3 = 600.0;
      const boxWidth = 300.0;

      await draw(
        tester,
        'erd',
        _sheet(
          title: 'مخطط الكيانات والعلاقات (ERD) — منصة كَنَفْ',
          width: 1400,
          height: 940,
          child: Stack(
            children: const [
              _Wires(
                links: [
                  // Notification.user User
                  (Offset(c1 + boxWidth, 89), Offset(c2 - 4, 81), false),
                  // UserProfile.user User
                  (Offset(c1 + boxWidth, 391), Offset(c2 + 52, 156), false),
                  // Donation.user User
                  (Offset(c1 + boxWidth, 660), Offset(c2 + 82, 156), false),
                  // Donation.need Need
                  (Offset(c1 + boxWidth, 720), Offset(c3 - 4, 480), false),
                  // Need.care_home CareHome
                  (Offset(c3 + 150, r2 - 4), Offset(c3 + 150, 172), false),
                  // VisitHour.care_home CareHome
                  (Offset(c4 - 4, 81), Offset(c3 + boxWidth + 4, 81), false),
                  // VolunteerOpportunity.care_home CareHome
                  (Offset(c4 + 106, r2 - 4), Offset(c3 + 240, 172), false),
                  // VolunteerApplication.opportunity Opportunity
                  (Offset(c3 + boxWidth, 660), Offset(c4 + 56, 482), false),
                  // VolunteerApplication.user User
                  (Offset(c3 - 4, 660), Offset(c2 + 212, 156), false),
                ],
              ),
              // ── العمود الأول ──
              Positioned(
                left: c1,
                top: r1,
                child: _EntityBox(
                  title: 'Notification',
                  subtitle: 'الإشعار',
                  fields: ['id : INT (PK)', 'user : FK User',
                      'notification_type', 'title', 'message', 'is_read'],
                  width: boxWidth,
                ),
              ),
              Positioned(
                left: c1,
                top: r2,
                child: _EntityBox(
                  title: 'UserProfile',
                  subtitle: 'ملف المستخدم',
                  fields: ['id : INT (PK)', 'user : FK User', 'role',
                      'phone_number', 'city'],
                  width: boxWidth,
                ),
              ),
              Positioned(
                left: c1,
                top: r3,
                child: _EntityBox(
                  title: 'Donation',
                  subtitle: 'التبرع',
                  fields: ['id : INT (PK)', 'user : FK User',
                      'need : FK Need', 'donation_type', 'amount',
                      'payment_method', 'status', 'created_at'],
                  width: boxWidth,
                ),
              ),
              // ── العمود الثاني: المستخدم وحده، وما تحته ممر ──
              Positioned(
                left: c2,
                top: r1,
                child: _EntityBox(
                  title: 'User',
                  subtitle: 'حساب المستخدم',
                  fields: ['id : INT (PK)', 'username', 'email',
                      'password', 'is_staff'],
                  width: boxWidth,
                ),
              ),
              // ── العمود الثالث ──
              Positioned(
                left: c3,
                top: r1,
                child: _EntityBox(
                  title: 'CareHome',
                  subtitle: 'دار الرعاية',
                  fields: ['id : INT (PK)', 'name', 'address', 'phone',
                      'manager : FK User', 'orphan_count'],
                  width: boxWidth,
                ),
              ),
              Positioned(
                left: c3,
                top: r2,
                child: _EntityBox(
                  title: 'Need',
                  subtitle: 'الاحتياج',
                  fields: ['id : INT (PK)', 'title', 'category', 'priority',
                      'required_quantity', 'fulfilled_quantity', 'status',
                      'care_home : FK', 'created_by : FK'],
                  width: boxWidth,
                ),
              ),
              Positioned(
                left: c3,
                top: r3,
                child: _EntityBox(
                  title: 'VolunteerApplication',
                  subtitle: 'طلب التطوع',
                  fields: ['id : INT (PK)', 'opportunity : FK',
                      'user : FK User', 'message', 'status', 'rating'],
                  width: boxWidth,
                ),
              ),
              // ── العمود الرابع ──
              Positioned(
                left: c4,
                top: r1,
                child: _EntityBox(
                  title: 'VisitHour',
                  subtitle: 'موعد الزيارة',
                  fields: ['id : INT (PK)', 'care_home : FK', 'weekday',
                      'start_time', 'end_time'],
                  width: boxWidth,
                ),
              ),
              Positioned(
                left: c4,
                top: r2,
                child: _EntityBox(
                  title: 'VolunteerOpportunity',
                  subtitle: 'فرصة التطوع',
                  fields: ['id : INT (PK)', 'title', 'care_home : FK',
                      'required_volunteers', 'current_volunteers', 'status'],
                  width: boxWidth,
                ),
              ),
            ],
          ),
        ),
      );
    });

    testWidgets('مخطط تسلسل التبرع', (tester) async {
      // المتبرع في أقصى اليمين لأن القراءة عربية، والرسائل تسير
      // يميناً ← يساراً في مسار الطلب، ثم تعود متقطّعة في مسار الرد.
      const lanes = <String>[
        'قاعدة البيانات',
        'خادم Django',
        'طبقة الـ API',
        'واجهة التبرع',
        'المتبرع',
      ];
      const laneWidth = 150.0;
      const laneGap = 66.0;
      const laneLeft = 24.0;
      double center(int index) =>
          laneLeft + laneWidth / 2 + index * (laneWidth + laneGap);

      const db = 0, server = 1, api = 2, ui = 3, donor = 4;

      await draw(
        tester,
        'sequence_donation',
        _sheet(
          title: 'مخطط التسلسل — عملية التبرع المالي',
          width: 1180,
          height: 700,
          child: Stack(
            children: [
              for (var i = 0; i < lanes.length; i++)
                Positioned(
                  left: center(i) - laneWidth / 2,
                  top: 0,
                  child: _Lifeline(label: lanes[i], height: 470),
                ),
              _Message(
                text: 'يُدخل المبلغ وطريقة الدفع',
                top: 78,
                fromX: center(donor),
                toX: center(ui),
              ),
              _Message(
                text: 'تحقّق داخل الحقول ثم بناء الطلب',
                top: 128,
                fromX: center(ui),
                toX: center(api),
              ),
              _Message(
                text: 'POST /api/donations/',
                top: 178,
                fromX: center(api),
                toX: center(server),
              ),
              _Message(
                text: 'تحقّق من الحد ثم INSERT',
                top: 228,
                fromX: center(server),
                toX: center(db),
              ),
              _Message(
                text: 'السجل المحفوظ ومعرّفه',
                top: 278,
                fromX: center(db),
                toX: center(server),
                dashed: true,
              ),
              _Message(
                text: '201 Created + id',
                top: 328,
                fromX: center(server),
                toX: center(api),
                dashed: true,
              ),
              _Message(
                text: 'حارس الاستمرارية: هل المعرّف حقيقي؟',
                top: 378,
                fromX: center(api),
                toX: center(ui),
                dashed: true,
              ),
              _Message(
                text: 'شاشة النجاح بالرقم المرجعي',
                top: 428,
                fromX: center(ui),
                toX: center(donor),
                dashed: true,
              ),
            ],
          ),
        ),
      );
    });

    testWidgets('معمارية النظام', (tester) async {
      await draw(
        tester,
        'architecture',
        _sheet(
          title: 'المعمارية العامة لمنصة كَنَفْ',
          width: 1080,
          height: 640,
          child: Stack(
            children: [
              const _Wires(
                links: [
                  (Offset(540, 150), Offset(540, 215), false),
                  (Offset(540, 330), Offset(540, 395), false),
                  (Offset(540, 465), Offset(540, 520), false),
                ],
              ),
              Positioned(
                left: 240,
                top: 30,
                child: _EntityBox(
                  title: 'طبقة العرض — Flutter',
                  subtitle: 'Material 3 · عربية RTL',
                  fields: const [
                    'Screens · KanafRouter · KanafTheme',
                    'KanafAsyncView (تحميل/خطأ/فراغ/محتوى)',
                  ],
                  width: 560,
                ),
              ),
              Positioned(
                left: 240,
                top: 215,
                child: _EntityBox(
                  title: 'طبقة الحالة — Provider',
                  subtitle: 'AppProvider',
                  fields: const [
                    'إدارة البيانات · تصنيف الأعطال · حرّاس الحفظ',
                  ],
                  width: 560,
                ),
              ),
              Positioned(
                left: 240,
                top: 395,
                child: _EntityBox(
                  title: 'طبقة الاتصال — Dio',
                  subtitle: 'ApiService',
                  fields: const [
                    'JWT · تجديد الرمز · مهلات · NetworkProbe',
                  ],
                  width: 560,
                ),
              ),
              Positioned(
                left: 240,
                top: 520,
                child: _EntityBox(
                  title: 'الخادم — Django REST Framework',
                  subtitle: 'PostgreSQL / SQLite',
                  fields: const [
                    'ViewSets · Serializers · صلاحيات · SimpleJWT',
                  ],
                  width: 560,
                ),
              ),
            ],
          ),
        ),
      );
    });
  });
}
