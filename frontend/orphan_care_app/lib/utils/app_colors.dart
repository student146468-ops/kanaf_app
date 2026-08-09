import 'package:flutter/material.dart';

/// [AppColors] - الهوية البصرية الجديدة المحسّنة لتطبيق "كَنَفْ"
/// ألوان فاتحة ومريحة للعين مع تصميم احترافي وحديث
class AppColors {
  // ===========================================================================
  // 🌅 الخلفيات الفاتحة والمريحة للعين
  // ===========================================================================

  // الخلفيات الرئيسية - ألوان فاتحة جداً
  static const Color scaffoldBackground =
      Color(0xFFF5F5F5); // رمادي فاتح للخلفيات
  static const Color cardBackground = Color(0xFFFFFFFF); // أبيض نقي
  static const Color surfaceLight = Color(0xFFF5F7FA); // أزرق فاتح جداً

  // ===========================================================================
  // 🎨 الألوان الأساسية والعلامة التجارية
  // ===========================================================================

  // البرتقالي الدافئ (العلامة التجارية الرئيسية)
  static const Color brandOrange = Color(0xFFFF8C42); // برتقالي دافئ وجميل
  static const Color brandOrangeDark = Color(0xFFD45A3C); // برتقالي غامق قليلاً
  static const Color brandOrangeLight =
      Color(0xFFFFF0E6); // برتقالي فاتح جداً للخلفيات

  // الأزرق السماوي الفاتح (للتنويع والتصميم)
  static const Color skyBlue = Color(0xFF87CEEB); // أزرق سماوي فاتح
  static const Color skyBlueDark = Color(0xFF4A90E2); // أزرق سماوي أغمق
  static const Color skyBlueLight = Color(0xFFE6F2FF); // أزرق سماوي فاتح جداً

  // الأخضر الفاتح (للحالات الإيجابية والنجاح)
  static const Color successGreen = Color(0xFF52C41A); // أخضر نجاح
  static const Color successGreenLight = Color(0xFFF6FFED); // أخضر فاتح جداً

  // الأحمر الفاتح (للتنبيهات والأخطاء)
  static const Color errorRed = Color(0xFFFF4D4F); // أحمر تنبيه
  static const Color errorRedLight = Color(0xFFFFF1F0); // أحمر فاتح جداً

  // ===========================================================================
  // 📝 ألوان النصوص
  // ===========================================================================

  static const Color textDarkPrimary =
      Color(0xFF2C3E50); // رمادي داكن - نص أساسي
  static const Color textDarkSecondary =
      Color(0xFF5A6C7D); // رمادي متوسط - نص ثانوي
  static const Color textDarkMuted = Color(0xFF8A9AAA); // رمادي فاتح - نص مخفف
  static const Color textDisabled =
      Color(0xFFBCC4CC); // رمادي خفيف جداً - نص معطل
  static const Color glassTextPrimary = Color(0xFFFFFFFF);
  static const Color glassTextSecondary = Color(0xE6FFFFFF);
  static const Color glassTextDisabled = Color(0x99FFFFFF);

  // ===========================================================================
  // 🎯 الحدود والفواصل
  // ===========================================================================

  static const Color innerBorder = Color(0xFFE8EEF2); // حد فاتح جداً
  static const Color divider = Color(0xFFEEF0F3); // فاصل فاتح
  static const Color innerShadow = Color(0x08000000); // ظل خفيف جداً

  // ===========================================================================
  // 💎 التأثيرات الزجاجية (Glassmorphism)
  // ===========================================================================

  static const Color glassBgNormal =
      Color(0x24FFFFFF); // شفافية بيضاء خفيفة جداً
  static const Color glassBgSelected =
      Color(0x38FFFFFF); // شفافية بيضاء أقوى قليلاً
  static const Color glassBorderNormal = Color(0x33FF8C42); // حد برتقالي شفاف
  static const Color glassBorderSelected =
      Color(0x66FF8C42); // حد برتقالي شفاف أقوى
  static const Color glassBorderWhite = Color(0x4DFFFFFF); // حد أبيض شفاف
  static const Color glassBackground = glassBgNormal;
  static const Color glassBorder = glassBorderWhite;
  static const Color glassShadow = Color(0x33000000);

  // ===========================================================================
  // 🔘 ألوان الأزرار والعناصر التفاعلية
  // ===========================================================================

  static const Color glassBtnActive = Color(0xFFFF8C42); // زر نشط - برتقالي
  static const Color glassBtnDisabled =
      Color(0x26FFFFFF); // زر معطل - رمادي فاتح

  // التدرجات اللونية
  static const List<Color> orangeGradient = [
    Color(0xFFFF8C42), // برتقالي دافئ
    Color(0xFFD45A3C), // برتقالي غامق
  ];

  static const List<Color> skyBlueGradient = [
    Color(0xFF87CEEB), // أزرق سماوي
    Color(0xFF4A90E2), // أزرق سماوي أغمق
  ];

  // ===========================================================================
  // 🎨 تأثيرات إضافية
  // ===========================================================================

  static const Color rippleEffect = Color(0x1AFF8C42); // تأثير النقر البرتقالي
  static const Color hoverEffect = Color(0x08FF8C42); // تأثير التحويم الخفيف
}
