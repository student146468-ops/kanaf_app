import 'package:flutter/material.dart';

import 'kanaf_tokens.dart';

/// نظام الحركة لتطبيق كَنَفْ، مبني على أنماط Material 3 الثلاثة.
///
/// المشكلة التي يحلها: `main.dart` كان يطبّق انتقال Fade+Scale **واحداً**
/// على كل مسار في التطبيق. النتيجة أن الدخول إلى صفحة فرعية يبدو
/// مثل تبديل تبويب، فيفقد المستخدم إحساس الاتجاه والتسلسل الهرمي.
///
/// الأنماط الثلاثة:
/// * **shared axis** — تنقل هرمي (رئيسي ← تفاصيل). ينزلق أفقياً.
/// * **fade through** — تنقل جانبي بين أقسام غير مترابطة (التبويبات).
/// * **fade scale** — ظهور عنصر فوق السياق الحالي (الحوارات، النجاح).
enum KanafTransition {
  /// الافتراضي للتنقل الهرمي: ينزلق على المحور الأفقي مع تلاشٍ.
  sharedAxis,

  /// للانتقال بين أقسام متكافئة: تلاشٍ متقاطع دون إزاحة.
  fadeThrough,

  /// لشاشات التتويج والنتائج: تلاشٍ مع تكبير طفيف.
  fadeScale,
}

/// مسار صفحة يطبّق حركة كَنَفْ ويحترم اتجاه النص تلقائياً.
class KanafPageRoute<T> extends PageRouteBuilder<T> {
  KanafPageRoute({
    required WidgetBuilder builder,
    required RouteSettings settings,
    this.transition = KanafTransition.sharedAxis,
  }) : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: _durationFor(transition),
          reverseTransitionDuration: KanafDuration.standard,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _buildTransition(
              context: context,
              transition: transition,
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
        );

  final KanafTransition transition;

  static Duration _durationFor(KanafTransition transition) {
    switch (transition) {
      case KanafTransition.sharedAxis:
        return KanafDuration.emphasized;
      case KanafTransition.fadeThrough:
        return KanafDuration.standard;
      case KanafTransition.fadeScale:
        return KanafDuration.emphasized;
    }
  }

  static Widget _buildTransition({
    required BuildContext context,
    required KanafTransition transition,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    switch (transition) {
      case KanafTransition.sharedAxis:
        return _SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      case KanafTransition.fadeThrough:
        return _FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      case KanafTransition.fadeScale:
        return _FadeScaleTransition(animation: animation, child: child);
    }
  }
}

/// انتقال المحور المشترك: الصفحة الداخلة تنزلق من جهة الحافة الخلفية.
///
/// في العربية (RTL) المعنى ينعكس: «التقدم للأمام» يعني الانزلاق من
/// اليسار لا اليمين. نقرأ `Directionality` لنطابق الحس المكاني العربي —
/// وهذا تفصيل يفرّق بين تطبيق معرَّب وتطبيق مترجَم فقط.
class _SharedAxisTransition extends StatelessWidget {
  const _SharedAxisTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final sign = isRtl ? -1.0 : 1.0;

    final enter = CurvedAnimation(
      parent: animation,
      curve: KanafCurves.emphasizedDecelerate,
      reverseCurve: KanafCurves.emphasizedAccelerate,
    );
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: KanafCurves.emphasizedAccelerate,
      reverseCurve: KanafCurves.emphasizedDecelerate,
    );

    return SlideTransition(
      // الصفحة الحالية تنزلق قليلاً للخلف عندما تُغطّى — يعطي عمقاً.
      position: Tween<Offset>(
        begin: Offset.zero,
        end: Offset(-0.22 * sign, 0),
      ).animate(exit),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.35).animate(exit),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0.3 * sign, 0),
            end: Offset.zero,
          ).animate(enter),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.25, 1, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// تلاشٍ متقاطع مع تكبير خفيف — للتنقل بين أقسام متكافئة.
/// الصفحة الخارجة تتلاشى أولاً ثم تظهر الداخلة، فلا يتراكب المحتوى.
class _FadeThroughTransition extends StatelessWidget {
  const _FadeThroughTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: const Interval(0, 0.35, curve: Curves.easeOut),
        ),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.35, 1, curve: Curves.easeIn),
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: KanafCurves.emphasizedDecelerate,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// تلاشٍ مع تكبير — لشاشات النتيجة والحوارات.
class _FadeScaleTransition extends StatelessWidget {
  const _FadeScaleTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: KanafCurves.emphasizedDecelerate,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}

/// ظهور متتالٍ لعناصر القائمة (staggered entrance).
///
/// يعطي إحساس «الحياة» عند فتح الشاشة: العناصر تصل تباعاً لا كلها دفعة
/// واحدة. التأخير محدود بسقف حتى لا تنتظر العناصر البعيدة طويلاً.
class KanafStaggeredEntrance extends StatefulWidget {
  const KanafStaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.stepDelay = const Duration(milliseconds: 55),
    this.maxDelay = const Duration(milliseconds: 400),
  });

  /// آخر عنصر يُحرَّك. ما بعده يُبنى مباشرة بلا متحكّم حركة.
  ///
  /// الحركة مقصودها استقبال أول شاشة يراها المستخدم. تركها مفتوحة
  /// لكل عنصر كان يعني أمرين سيئين: متحكّم حركة لكل صف في قائمة قد
  /// تبلغ مئات العناصر، وإعادة ظهور العناصر بتلاشٍ **أثناء التمرير**
  /// كلما بناها `ListView.builder` — وهو ما يُشعر القائمة بالتقطّع.
  static const int maxAnimatedIndex = 7;

  final int index;
  final Widget child;
  final Duration stepDelay;
  final Duration maxDelay;

  @override
  State<KanafStaggeredEntrance> createState() => _KanafStaggeredEntranceState();
}

class _KanafStaggeredEntranceState extends State<KanafStaggeredEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  CurvedAnimation? _curved;

  bool get _animates => widget.index <= KanafStaggeredEntrance.maxAnimatedIndex;

  @override
  void initState() {
    super.initState();
    if (!_animates) return;

    final controller = AnimationController(
      duration: KanafDuration.emphasized,
      vsync: this,
    );
    _controller = controller;
    // يُبنى مرة واحدة لا في كل `build`: إنشاء `CurvedAnimation` داخل
    // البناء يخلق كائناً جديداً بكل إطار ويُسرّب اشتراكه.
    _curved = CurvedAnimation(
      parent: controller,
      curve: KanafCurves.emphasizedDecelerate,
    );

    final delayMs = (widget.stepDelay.inMilliseconds * widget.index)
        .clamp(0, widget.maxDelay.inMilliseconds);
    if (delayMs == 0) {
      controller.forward();
    } else {
      Future<void>.delayed(Duration(milliseconds: delayMs), () {
        // الشاشة قد تُغلق قبل انتهاء التأخير.
        if (mounted) controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _curved?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = _curved;
    // نحترم إعداد «تقليل الحركة» في نظام التشغيل: لبعض المستخدمين
    // الحركة مصدر إزعاج أو دوار، لا لمسة جمالية.
    if (curved == null || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
