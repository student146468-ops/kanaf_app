import 'package:flutter/material.dart';

/// رموز التصميم (Design Tokens) لتطبيق كَنَفْ.
///
/// كل قيمة مكانية أو زمنية أو دائرية في التطبيق تأتي من هنا.
/// لا أرقام سحرية داخل الشاشات — هذا ما يجعل الواجهة تبدو نظاماً
/// واحداً لا مجموعة شاشات صممها أشخاص مختلفون.
abstract final class KanafSpacing {
  /// سلّم مسافات من مضاعفات 4 — نفس شبكة Material 3.
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  /// الهامش الأفقي القياسي لمحتوى الصفحة.
  static const double pageInset = 20;

  /// مساحة أسفل القوائم لتفادي اصطدام آخر عنصر بالشريط السفلي.
  static const double bottomSafeGutter = 96;
}

abstract final class KanafRadii {
  static const Radius xsValue = Radius.circular(8);
  static const Radius smValue = Radius.circular(12);
  static const Radius mdValue = Radius.circular(16);
  static const Radius lgValue = Radius.circular(20);
  static const Radius xlValue = Radius.circular(28);

  static const BorderRadius xs = BorderRadius.all(xsValue);
  static const BorderRadius sm = BorderRadius.all(smValue);
  static const BorderRadius md = BorderRadius.all(mdValue);
  static const BorderRadius lg = BorderRadius.all(lgValue);
  static const BorderRadius xl = BorderRadius.all(xlValue);

  /// حافة علوية مستديرة للأوراق السفلية (Bottom Sheets).
  static const BorderRadius sheet = BorderRadius.vertical(top: xlValue);

  /// شكل الكبسولة — للشرائح والأزرار الدائرية.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// مدد الحركة. مأخوذة من توصيات Material 3 للحركة التعبيرية:
/// قصيرة للاستجابة الفورية، متوسطة لانتقالات الصفحات.
abstract final class KanafDuration {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 280);
  static const Duration emphasized = Duration(milliseconds: 420);
  static const Duration slow = Duration(milliseconds: 650);
}

/// منحنيات الحركة. `emphasized` هو منحنى Material 3 المميز الذي يعطي
/// إحساس «الثقل الطبيعي» بدل الحركة الخطية الرخيصة.
abstract final class KanafCurves {
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);
  static const Curve standard = Curves.easeInOutCubic;
}

/// ألوان هوية كَنَفْ.
///
/// البرتقالي مأخوذ من شعار التطبيق ويُستخدم كبذرة (seed) لتوليد
/// نظام ألوان Material 3 كامل. الفلسفة: البرتقالي **لمسة** على
/// الأسطح المحايدة — يظهر في نقاط القرار والتأكيد، لا كخلفية طاغية.
abstract final class KanafPalette {
  /// برتقالي الشعار الصريح — بذرة نظام الألوان.
  ///
  /// يُستخدم كما هو في الأسطح **الزخرفية** التي لا تحمل نصاً: التدرجات،
  /// حاويات الأيقونات، الشارات، حلقات التقدّم، وشاهدات الأقسام.
  static const Color seed = Color(0xFFF5751F);

  /// برتقالي أدفأ للتدرجات والحالات المضيئة.
  static const Color ember = Color(0xFFFF9A4D);

  /// برتقالي الأزرار والعناصر التي تحمل نصاً أبيض.
  ///
  /// أعمق قليلاً من الشعار عن قصد: النص الأبيض على `seed` يعطي تبايناً
  /// 2.8:1 ويرسب في WCAG AA (المطلوب 4.5:1). هذه الدرجة أقصى ما يمكن
  /// الاحتفاظ به من حيوية البرتقالي مع تباين **4.6:1** — فتبقى الهوية
  /// واضحة والنص مقروءاً لكل مستخدم.
  static const Color brandInk = Color(0xFFCB4A05);

  /// نظيرها في الوضع الداكن: النص الداكن يوضع فوقها، فتكون فاتحة.
  static const Color brandInkDark = Color(0xFFFF9247);

  /// أخضر النجاح — للتبرعات المؤكدة والحالات المكتملة.
  static const Color success = Color(0xFF1E9E62);
  static const Color successContainerLight = Color(0xFFE1F5EA);
  static const Color successContainerDark = Color(0xFF102E20);

  /// كهرماني التحذير — لحالة «قيد المراجعة».
  static const Color warning = Color(0xFFC8891A);
  static const Color warningContainerLight = Color(0xFFFDF2DC);
  static const Color warningContainerDark = Color(0xFF33270B);

  /// أزرق معلوماتي — محايد ومتمم للبرتقالي دون منافسته.
  static const Color info = Color(0xFF2C6BB0);
  static const Color infoContainerLight = Color(0xFFE4EEF9);
  static const Color infoContainerDark = Color(0xFF11243A);
}

/// ألوان دلالية (نجاح / تحذير / معلومة) لا يولّدها `ColorScheme`.
/// تُقرأ من `Theme.of(context).extension<KanafSemanticColors>()!`.
@immutable
class KanafSemanticColors extends ThemeExtension<KanafSemanticColors> {
  const KanafSemanticColors({
    required this.success,
    required this.onSuccessContainer,
    required this.successContainer,
    required this.warning,
    required this.onWarningContainer,
    required this.warningContainer,
    required this.info,
    required this.onInfoContainer,
    required this.infoContainer,
  });

  factory KanafSemanticColors.light() => const KanafSemanticColors(
        success: KanafPalette.success,
        successContainer: KanafPalette.successContainerLight,
        onSuccessContainer: Color(0xFF0B4F30),
        warning: KanafPalette.warning,
        warningContainer: KanafPalette.warningContainerLight,
        onWarningContainer: Color(0xFF5C3D05),
        info: KanafPalette.info,
        infoContainer: KanafPalette.infoContainerLight,
        onInfoContainer: Color(0xFF14355B),
      );

  factory KanafSemanticColors.dark() => const KanafSemanticColors(
        success: Color(0xFF62D69C),
        successContainer: KanafPalette.successContainerDark,
        onSuccessContainer: Color(0xFFB6F0D0),
        warning: Color(0xFFE8BE6D),
        warningContainer: KanafPalette.warningContainerDark,
        onWarningContainer: Color(0xFFF7E2B8),
        info: Color(0xFF8FBDEC),
        infoContainer: KanafPalette.infoContainerDark,
        onInfoContainer: Color(0xFFC9DFF6),
      );

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;

  @override
  KanafSemanticColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return KanafSemanticColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  KanafSemanticColors lerp(KanafSemanticColors? other, double t) {
    if (other == null) return this;
    return KanafSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}

/// امتداد مختصر للوصول إلى الألوان الدلالية داخل الشاشات.
extension KanafThemeAccess on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  KanafSemanticColors get semantic =>
      Theme.of(this).extension<KanafSemanticColors>() ??
      KanafSemanticColors.light();
}
