import 'package:flutter/material.dart';

import '../router/kanaf_router.dart';
import '../services/api_service.dart';
import '../theme/kanaf_tokens.dart';
import '../utils/auth_navigation.dart';
import '../widgets/kanaf_layout.dart';

/// شاشة البداية.
///
/// الأهم في إعادة البناء: الانتظار صار **مرتبطاً بالعمل الفعلي** لا
/// بمؤقّت ثابت. سابقاً كان `Timer(4 seconds)` يحبس المستخدم أربع ثوانٍ
/// كاملة حتى لو انتهى فحص الجلسة في 50 مللي ثانية. الآن نفحص الجلسة
/// فوراً وننتظر حداً أدنى قصيراً فقط ليكتمل ظهور الشعار بصرياً.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// أقل مدة عرض. أقصر منها يجعل الشاشة تبدو كوميض خاطف.
  static const Duration _minimumDisplay = Duration(milliseconds: 1400);

  late final AnimationController _introController = AnimationController(
    duration: KanafDuration.slow,
    vsync: this,
  );

  late final AnimationController _breatheController = AnimationController(
    duration: const Duration(milliseconds: 2200),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _introController.forward();
    _breatheController.repeat(reverse: true);
    _resolveDestination();
  }

  @override
  void dispose() {
    _introController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  /// يفحص الجلسة وينتقل. الحد الأدنى للعرض والفحص يجريان **بالتوازي**
  /// عبر `Future.wait`، فالمستخدم لا يدفع ثمن الاثنين متتاليين.
  Future<void> _resolveDestination() async {
    final api = ApiService();

    final results = await Future.wait<Object?>([
      Future<void>.delayed(_minimumDisplay),
      _readSession(api),
    ]);

    if (!mounted) return;

    final session = results[1] as _Session?;
    if (session != null && session.isAuthenticated) {
      AuthNavigation.navigateByRole(
        context,
        session.role,
        showUnknownRoleMessage: false,
      );
      return;
    }

    Navigator.of(context).pushReplacementNamed(KanafRoutes.onboarding);
  }

  Future<_Session?> _readSession(ApiService api) async {
    try {
      final authenticated = await api.isAuthenticated();
      if (!authenticated) return const _Session(isAuthenticated: false);

      final role = await api.getSavedRole();

      // وجود رمز محفوظ لا يعني أن الجلسة ما زالت صالحة: قد يكون
      // انتهى أو أُبطل من الخادم (تغيير كلمة مرور، أو خروج من جهاز
      // آخر). كنا ندخل المستخدم إلى قسمه ثم تفشل أول عملية أمامه
      // بلا تفسير. نتحقق الآن بنداء واحد خفيف قبل الدخول.
      try {
        final me = await api.getMe();
        // الدور القادم من الخادم أحدث من المحفوظ محلياً.
        final freshRole = AuthNavigation.roleFromAuthResponse(me) ?? role;
        return _Session(isAuthenticated: true, role: freshRole);
      } on ApiServiceException catch (e) {
        // انقطاع الشبكة ليس دليلاً على بطلان الجلسة — ندخل بالدور
        // المحفوظ بدل طرد مستخدم صالح لأنه بلا إنترنت لحظتها.
        if (e.isConnectivity) {
          return _Session(isAuthenticated: true, role: role);
        }
        return const _Session(isAuthenticated: false);
      }
    } catch (_) {
      // تعذر قراءة التخزين المحلي: نعامله كعدم وجود جلسة بدل
      // تعليق المستخدم على شاشة البداية إلى الأبد.
      return const _Session(isAuthenticated: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _introController,
                  curve: Curves.easeOut,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: KanafSpacing.xxl),
                    Text(
                      'كَــنَـــفْ',
                      style: context.texts.displaySmall?.copyWith(
                        color: KanafPalette.seed,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.xs),
                    Text(
                      'معًا نصنع أثرًا',
                      style: context.texts.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.huge),
                    // مؤشر خطي رقيق: يوصّل «جاري العمل» بلا نقاط
                    // مصنوعة يدوياً، ويتبع الثيم تلقائياً.
                    SizedBox(
                      width: 132,
                      child: ClipRRect(
                        borderRadius: KanafRadii.pill,
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(child: _SplashWaves()),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    // تنفّس هادئ (0.97 ← 1.03) بدل نبض حاد — يوحي بالحياة لا بالقلق.
    return ScaleTransition(
      scale: Tween<double>(begin: 0.97, end: 1.03).animate(
        CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
      ),
      child: const KanafLogo(size: 148),
    );
  }
}

class _Session {
  const _Session({required this.isAuthenticated, this.role});

  final bool isAuthenticated;
  final String? role;
}

/// موجتان برتقاليتان أسفل الشاشة — أبرز تجلٍّ لهوية كَنَفْ في التطبيق،
/// ومقصور على شاشة البداية حتى يبقى استثناءً لا نمطاً متكرراً.
class _SplashWaves extends StatelessWidget {
  const _SplashWaves();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final waveHeight = (screenHeight * 0.20).clamp(138.0, 178.0);

    return SizedBox(
      height: waveHeight,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: const _WaveClipper(layer: _WaveLayer.back),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      KanafPalette.ember.withOpacity(0.42),
                      KanafPalette.ember.withOpacity(0.66),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: waveHeight * 0.82,
            child: const ClipPath(
              clipper: _WaveClipper(layer: _WaveLayer.front),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [KanafPalette.ember, KanafPalette.seed],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _WaveLayer { back, front }

class _WaveClipper extends CustomClipper<Path> {
  const _WaveClipper({required this.layer});

  final _WaveLayer layer;

  @override
  Path getClip(Size size) {
    final isBack = layer == _WaveLayer.back;
    final startY = size.height * (isBack ? 0.28 : 0.24);

    return Path()
      ..moveTo(0, startY)
      ..cubicTo(
        size.width * 0.18,
        size.height * (isBack ? 0.08 : 0.44),
        size.width * 0.36,
        size.height * (isBack ? 0.14 : 0.02),
        size.width * 0.52,
        size.height * (isBack ? 0.27 : 0.19),
      )
      ..cubicTo(
        size.width * 0.68,
        size.height * (isBack ? 0.41 : 0.36),
        size.width * 0.82,
        size.height * 0.08,
        size.width,
        size.height * (isBack ? 0.22 : 0.18),
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _WaveClipper oldClipper) =>
      oldClipper.layer != layer;
}
