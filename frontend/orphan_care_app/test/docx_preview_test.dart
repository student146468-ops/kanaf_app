import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// معاينة مخططات ملف الوورد.
///
/// المخططات في الوثيقة أشكال Word أصلية، ولا يمكن رؤيتها إلا بفتح
/// المستند. هذا الملف يعيد رسم **نفس الإحداثيات** بمحرّك Flutter
/// لمعاينتها قبل التسليم، فلا نسلّم تخطيطاً لم يره أحد.
///
/// شغّله بـ: flutter test test/docx_preview_test.dart --update-goldens

const Color _ink = Color(0xFF1F2937);
const Color _brand = Color(0xFFC55A11);
const Color _soft = Color(0xFFFCE4D6);
const Color _line = Color(0xFF9AA1AD);
const Color _navy = Color(0xFF1F3864);

/// وصف شكل مطابق لما يستهلكه كاتب الوورد.
sealed class Shape {
  const Shape();
}

class Box extends Shape {
  const Box({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.title,
    this.subtitle,
    this.fill = _soft,
    this.stroke = _brand,
    this.titleSize = 10,
    this.titleBold = true,
  });

  final double x, y, w, h;
  final String title;
  final String? subtitle;
  final Color fill, stroke;
  final double titleSize;
  final bool titleBold;
}

class Wire extends Shape {
  const Wire(this.x1, this.y1, this.x2, this.y2, {this.dashed = false,
      this.arrow = true});

  final double x1, y1, x2, y2;
  final bool dashed, arrow;
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Vazirmatn');
  for (final path in [
    'assets/fonts/Vazirmatn-Regular.ttf',
    'assets/fonts/Vazirmatn-SemiBold.ttf',
    'assets/fonts/Vazirmatn-Bold.ttf',
  ]) {
    loader.addFont(rootBundle.load(path));
  }
  await loader.load();
}

class _WirePainter extends CustomPainter {
  _WirePainter(this.wires);

  final List<Wire> wires;

  @override
  void paint(Canvas canvas, Size size) {
    for (final wire in wires) {
      final paint = Paint()
        ..color = _line
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke;
      final from = Offset(wire.x1, wire.y1);
      final to = Offset(wire.x2, wire.y2);

      if (wire.dashed) {
        final total = (to - from).distance;
        if (total == 0) continue;
        final step = (to - from) / total;
        var travelled = 0.0;
        while (travelled < total) {
          canvas.drawLine(
            from + step * travelled,
            from + step * math.min(travelled + 6, total),
            paint,
          );
          travelled += 10;
        }
      } else {
        canvas.drawLine(from, to, paint);
      }

      if (!wire.arrow) continue;
      final angle = (to - from).direction;
      const len = 9.0, spread = 0.42;
      canvas.drawPath(
        Path()
          ..moveTo(to.dx, to.dy)
          ..lineTo(to.dx - len * math.cos(angle - spread),
              to.dy - len * math.sin(angle - spread))
          ..moveTo(to.dx, to.dy)
          ..lineTo(to.dx - len * math.cos(angle + spread),
              to.dy - len * math.sin(angle + spread)),
        paint..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Widget _canvas(String title, double width, double height,
    List<Shape> shapes) {
  final boxes = shapes.whereType<Box>().toList();
  final wires = shapes.whereType<Wire>().toList();

  return Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _brand,
            ),
          ),
          const SizedBox(height: 10),
          // إطار رمادي يمثّل حدود اللوحة داخل الوورد.
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter:
                    _WirePainter(wires))),
                for (final box in boxes)
                  Positioned(
                    left: box.x,
                    top: box.y,
                    width: box.w,
                    height: box.h,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: box.fill,
                        border: Border.all(color: box.stroke),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            box.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: box.titleSize,
                              fontWeight: box.titleBold
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: _ink,
                              height: 1.25,
                            ),
                          ),
                          if (box.subtitle != null)
                            Text(
                              box.subtitle!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 7,
                                color: Color(0xFF6B7280),
                                height: 1.25,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  Future<void> shot(WidgetTester tester, String name, Widget child) async {
    tester.view.physicalSize = const Size(1300, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(650, 550)),
        child: child,
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(Directionality).first,
      matchesGoldenFile('docx_preview/$name.png'),
    );
  }

  testWidgets('منهجية أجايل', (tester) async {
    const w = 168.0, h = 54.0;
    const xl = 15.0, xm = 201.0, xr = 387.0;
    const r1 = 14.0, r2 = 140.0;
    const my1 = r1 + h / 2, my2 = r2 + h / 2;

    await shot(
      tester,
      'agile',
      _canvas('منهجية أجايل — كما ستظهر في الوورد', 580, 210, const [
        Box(x: xr, y: r1, w: w, h: h, title: 'تحديد المتطلبات'),
        Box(x: xm, y: r1, w: w, h: h, title: 'التخطيط للدورة'),
        Box(x: xl, y: r1, w: w, h: h, title: 'التصميم والتنفيذ'),
        Box(x: xl, y: r2, w: w, h: h, title: 'الاختبار'),
        Box(x: xm, y: r2, w: w, h: h, title: 'المراجعة'),
        Wire(xr, my1, xm + w, my1),
        Wire(xm, my1, xl + w, my1),
        Wire(xl + w / 2, r1 + h, xl + w / 2, r2),
        Wire(xl + w, my2, xm, my2),
        Wire(xm + w, my2, xr + w / 2, r1 + h, dashed: true),
        Box(x: xm + w + 14, y: 88, w: 140, h: 26, title: 'تغذية راجعة',
            titleSize: 8, titleBold: false, fill: Colors.white,
            stroke: Colors.white),
      ]),
    );
  });

  testWidgets('مخطط الكيانات', (tester) async {
    const w = 126.0, h = 56.0;
    const c0 = 8.0, c1 = 148.0, c2 = 288.0, c3 = 428.0;
    const corridor = 141.0;
    const r0 = 10.0, r1 = 118.0, r2 = 226.0;
    const mid = h / 2;

    await shot(
      tester,
      'erd',
      _canvas('مخطط الكيانات — كما سيظهر في الوورد', 570, 294, const [
        Box(x: c0, y: r0, w: w, h: h, title: 'Notification',
            subtitle: 'الإشعار', titleSize: 7),
        Box(x: c1, y: r0, w: w, h: h, title: 'User',
            subtitle: 'حساب المستخدم', titleSize: 7,
            fill: Colors.white, stroke: _navy),
        Box(x: c2, y: r0, w: w, h: h, title: 'CareHome',
            subtitle: 'دار الرعاية', titleSize: 7),
        Box(x: c3, y: r0, w: w, h: h, title: 'VisitHour',
            subtitle: 'موعد الزيارة', titleSize: 7),
        Box(x: c0, y: r1, w: w, h: h, title: 'UserProfile',
            subtitle: 'ملف المستخدم', titleSize: 7),
        Box(x: c1, y: r1, w: w, h: h, title: 'Donation',
            subtitle: 'التبرع', titleSize: 7),
        Box(x: c2, y: r1, w: w, h: h, title: 'Need',
            subtitle: 'الاحتياج', titleSize: 7),
        Box(x: c3, y: r1, w: w, h: h, title: 'VolunteerOpportunity',
            subtitle: 'فرصة التطوع', titleSize: 7),
        Box(x: c1, y: r2, w: w, h: h, title: 'VolunteerApplication',
            subtitle: 'طلب التطوع', titleSize: 7),
        Wire(c0 + w, r0 + mid, c1, r0 + mid),
        Wire(c2, r0 + mid, c1 + w, r0 + mid),
        Wire(c3, r0 + mid, c2 + w, r0 + mid),
        Wire(c0 + w, r1 + mid, c1 + 25, r0 + h),
        Wire(c1 + w / 2, r1, c1 + w / 2, r0 + h),
        Wire(c1 + w, r1 + mid, c2, r1 + mid),
        Wire(c2 + w / 2, r1, c2 + w / 2, r0 + h),
        Wire(c3 + 25, r1, c2 + w - 20, r0 + h),
        Wire(c1 + w, r2 + mid, c3 + 25, r1 + h),
        Wire(c1, r2 + mid, corridor, r2 + mid, arrow: false),
        Wire(corridor, r2 + mid, corridor, r0 + 40, arrow: false),
        Wire(corridor, r0 + 40, c1, r0 + 40),
      ]),
    );
  });
}
