import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kanaf_tokens.dart';

/// ثيم كَنَفْ المبني على Material 3.
///
/// القرار التصميمي المركزي: نظام الألوان كله **مُشتق** من برتقالي الشعار
/// عبر `ColorScheme.fromSeed`. هذا يضمن أن كل سطح ونص وحدّ في التطبيق
/// متناغم رياضياً مع الهوية، وأن نسب التباين تحقق معايير الوصول —
/// بدل رصف أكواد ألوان يدوياً في كل شاشة كما كان الحال.
///
/// البرتقالي يظهر كلمسة: أزرار الإجراء الرئيسي، المؤشرات، والحالة النشطة.
/// الأسطح تبقى محايدة ليتنفس المحتوى.
abstract final class KanafTheme {
  /// الخط الأساسي. Vazirmatn يملك أوزاناً متعددة ويقرأ بوضوح
  /// في المقاسات الصغيرة — لذلك هو خط الواجهة، وTajawal للعناوين العريضة.
  static const String fontBody = 'Vazirmatn';
  static const String fontDisplay = 'Tajawal';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final generated = ColorScheme.fromSeed(
      seedColor: KanafPalette.seed,
      brightness: brightness,
      // المتغيّر الافتراضي (tonalSpot) يسحب تشبّع البذرة بشدة، فيخرج
      // برتقالي كَنَفْ بنيّاً باهتاً وتضيع الهوية. `vibrant` يحافظ على
      // حيوية اللون مع إبقاء ضمانات التباين في Material 3.
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );

    // نبقي على النظام المولَّد كاملاً (فالأسطح والحدود والألوان
    // الثانوية كلها متناغمة رياضياً مع البذرة)، ونعيد تعريف اللون
    // الأساسي وحاويته فقط ليطابقا هوية الشعار بدرجة أقرب مما يعطيه
    // التوليد الافتراضي — دون التفريط في نسب التباين.
    final scheme = isLight
        ? generated.copyWith(
            primary: KanafPalette.brandInk,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFFFE5D2),
            onPrimaryContainer: const Color(0xFF4A1900),
          )
        : generated.copyWith(
            primary: KanafPalette.brandInkDark,
            onPrimary: const Color(0xFF4A1900),
            primaryContainer: const Color(0xFF7A2E02),
            onPrimaryContainer: const Color(0xFFFFDBC7),
          );

    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      useMaterial3: true,
      fontFamily: fontBody,
      scaffoldBackgroundColor: isLight ? const Color(0xFFFBF9F7) : scheme.surface,
      splashFactory: InkSparkle.splashFactory,
    );

    final texts = _textTheme(base.textTheme, scheme);

    return base.copyWith(
      textTheme: texts,
      extensions: <ThemeExtension<dynamic>>[
        isLight ? KanafSemanticColors.light() : KanafSemanticColors.dark(),
      ],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? const Color(0xFFFBF9F7) : scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 3,
        centerTitle: true,
        titleTextStyle: texts.titleLarge,
        systemOverlayStyle:
            isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardTheme(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: KanafRadii.lg,
          side: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle: texts.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: KanafRadii.md),
          padding: const EdgeInsets.symmetric(horizontal: KanafSpacing.xxl),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle: texts.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: KanafRadii.md),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: texts.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: KanafRadii.sm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KanafSpacing.lg,
          vertical: KanafSpacing.lg,
        ),
        hintStyle: texts.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: texts.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: texts.bodySmall?.copyWith(color: scheme.error),
        border: OutlineInputBorder(
          borderRadius: KanafRadii.md,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: KanafRadii.md,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: KanafRadii.md,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: KanafRadii.md,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: KanafRadii.md,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 3,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return texts.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: scheme.scrim.withOpacity(0.45),
        shape: const RoundedRectangleBorder(borderRadius: KanafRadii.sheet),
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: KanafRadii.xl),
        titleTextStyle: texts.titleLarge,
        contentTextStyle: texts.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            texts.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: const RoundedRectangleBorder(borderRadius: KanafRadii.md),
        insetPadding: const EdgeInsets.all(KanafSpacing.lg),
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        labelStyle: texts.labelMedium,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const RoundedRectangleBorder(borderRadius: KanafRadii.pill),
        padding: const EdgeInsets.symmetric(
          horizontal: KanafSpacing.md,
          vertical: KanafSpacing.sm,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: KanafRadii.md),
        titleTextStyle: texts.bodyLarge,
        subtitleTextStyle: texts.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: KanafRadii.sm,
        ),
        textStyle: texts.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
      // انتقالات مخصّصة للشرائح المتزامنة تُدار في kanaf_page_route.dart.
      visualDensity: VisualDensity.standard,
    );
  }

  /// سلّم طباعي عربي.
  ///
  /// `height` أعلى من افتراضي Material لأن الحرف العربي يحتاج
  /// تنفساً رأسياً أكبر — بغيره يبدو النص مزدحماً وهذا أول ما يفضح
  /// أن التطبيق «صفحة ويب ملفوفة».
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    TextStyle display(double size, {double height = 1.3}) => TextStyle(
          fontFamily: fontDisplay,
          fontSize: size,
          height: height,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        );

    TextStyle body(
      double size, {
      FontWeight weight = FontWeight.w500,
      double height = 1.6,
      Color? color,
    }) =>
        TextStyle(
          fontFamily: fontBody,
          fontSize: size,
          height: height,
          fontWeight: weight,
          color: color ?? scheme.onSurface,
        );

    return base.copyWith(
      displayLarge: display(40, height: 1.2),
      displayMedium: display(34, height: 1.22),
      displaySmall: display(28, height: 1.25),
      headlineLarge: display(26),
      headlineMedium: display(23),
      headlineSmall: display(20),
      titleLarge: body(19, weight: FontWeight.w700, height: 1.4),
      titleMedium: body(16, weight: FontWeight.w700, height: 1.45),
      titleSmall: body(14, weight: FontWeight.w700, height: 1.45),
      bodyLarge: body(16),
      bodyMedium: body(14),
      bodySmall: body(12.5, height: 1.5, color: scheme.onSurfaceVariant),
      labelLarge: body(15, weight: FontWeight.w700, height: 1.3),
      labelMedium: body(13, weight: FontWeight.w600, height: 1.3),
      labelSmall: body(11.5, weight: FontWeight.w600, height: 1.3),
    );
  }
}
