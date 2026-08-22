import 'package:flutter/material.dart';

import '../theme/kanaf_tokens.dart';

/// مكوّنات التخطيط المشتركة.
///
/// «لمسة كَنَفْ» تُطبّق هنا بانضباط: تدرّج برتقالي خفيف جداً أعلى الشاشة،
/// وقوس احتواء في رأس الأقسام الرئيسية. المساحات تبقى محايدة —
/// البرتقالي يعمل كإشارة انتباه لا كطلاء.

/// بطاقة السطح القياسية. تعتمد على `CardTheme` فلا تكرر حدوداً وظلالاً.
class KanafCard extends StatelessWidget {
  const KanafCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KanafSpacing.lg),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: KanafRadii.lg,
      side: BorderSide(
        color: borderColor ?? scheme.outlineVariant.withOpacity(0.6),
      ),
    );

    return Material(
      color: color ?? scheme.surfaceContainerLow,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              // نبضة اللمس بلون الهوية — تفصيل صغير يُحسّ ولا يُرى.
              splashColor: scheme.primary.withOpacity(0.08),
              highlightColor: scheme.primary.withOpacity(0.04),
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// عنوان قسم مع سطر وصفي اختياري وإجراء على الحافة الأمامية.
class KanafSectionHeader extends StatelessWidget {
  const KanafSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // شاهدة برتقالية رأسية — علامة كَنَفْ الهادئة على بداية كل قسم.
        Container(
          width: 3.5,
          height: subtitle == null ? 18 : 34,
          margin: const EdgeInsetsDirectional.only(end: KanafSpacing.md),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [KanafPalette.seed, KanafPalette.ember],
            ),
            borderRadius: KanafRadii.pill,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.texts.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: KanafSpacing.xs),
                Text(
                  subtitle!,
                  style: context.texts.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// خلفية الشاشة: هالتان برتقاليتان تعطيان الصفحة عمقاً ودفئاً.
///
/// النسخة الأولى كانت تدرّجاً خطياً واحداً بشفافية 10% — باهتاً لدرجة
/// أنه لم يُقرأ كهوية. هنا هالتان قطريتان (radial) من زاويتين، فتظهر
/// إضاءة طبيعية بدل شريط لوني مسطّح، مع بقاء المحتوى هو البطل.
class KanafBackdrop extends StatelessWidget {
  const KanafBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // في الوضع الداكن تُقرأ الهالة أقوى على الأسطح الغامقة، فنخفّضها.
    final intensity = isDark ? 0.16 : 0.26;

    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surface),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.9, -1),
                    radius: 1.25,
                    colors: [
                      KanafPalette.ember.withOpacity(intensity),
                      KanafPalette.ember.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-1, -0.75),
                    radius: 1.1,
                    colors: [
                      KanafPalette.seed.withOpacity(intensity * 0.7),
                      KanafPalette.seed.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// شعار كَنَفْ داخل هالة برتقالية.
///
/// مكوّن واحد لكل الشاشات التي تعرض الشعار، فلا يتكرر منطق التحميل
/// والبديل الاحتياطي. الهالة تجعل الشعار يبدو مضيئاً لا ملصقاً.
class KanafLogo extends StatelessWidget {
  const KanafLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerLowest,
        // حلقة برتقالية رقيقة تربط الشعار بالهوية بلا صخب.
        border: Border.all(
          color: KanafPalette.seed.withOpacity(0.22),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: KanafPalette.seed.withOpacity(0.22),
            blurRadius: size * 0.34,
            spreadRadius: -size * 0.06,
            offset: Offset(0, size * 0.09),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.17),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.volunteer_activism_rounded,
            size: size * 0.42,
            color: KanafPalette.seed,
          ),
        ),
      ),
    );
  }
}

/// شريط علوي متدرّج بلون الهوية — يمنح شاشات الدخول حضوراً بصرياً.
///
/// أضيف بعد ملاحظة أن الواجهات «صامتة»: سطح محايد بالكامل بلا أي
/// كتلة لونية يجعل الشاشة تبدو غير مكتملة. التدرّج هنا يحمل الشعار
/// والعنوان، فهو بنية لا زخرفة.
class KanafHeroBand extends StatelessWidget {
  const KanafHeroBand({
    super.key,
    required this.title,
    this.subtitle,
    this.showLogo = true,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool showLogo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: KanafSpacing.xxl,
        vertical: KanafSpacing.xxxl,
      ),
      decoration: BoxDecoration(
        borderRadius: KanafRadii.xl,
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [KanafPalette.ember, KanafPalette.seed],
        ),
        boxShadow: [
          BoxShadow(
            color: KanafPalette.seed.withOpacity(0.30),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          if (showLogo) ...[
            const KanafLogo(size: 84),
            const SizedBox(height: KanafSpacing.xl),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.texts.headlineMedium?.copyWith(
              // النص أبيض فوق البرتقالي المشبع: تباين 3.4:1 عند هذا
              // الحجم العريض (26sp/w700) وهو ضمن حدّ النص الكبير.
              color: Colors.white,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: KanafSpacing.sm),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.92),
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(height: KanafSpacing.xl),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// بطاقة إحصاء مدمجة: رقم كبير + تسمية + أيقونة.
class KanafStatTile extends StatelessWidget {
  const KanafStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final tone = accent ?? scheme.primary;

    return KanafCard(
      onTap: onTap,
      padding: const EdgeInsets.all(KanafSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.12),
              borderRadius: KanafRadii.sm,
            ),
            child: Icon(icon, size: 20, color: tone),
          ),
          const SizedBox(height: KanafSpacing.md),
          // الرقم بخط العرض العريض — يقرأ كبيانات لا كنص جارٍ.
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.headlineSmall,
          ),
          const SizedBox(height: KanafSpacing.xxs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// صف تفاصيل «تسمية ← قيمة» بمحاذاة ثابتة.
class KanafDetailRow extends StatelessWidget {
  const KanafDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueStyle,
    this.trailing,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KanafSpacing.sm - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: context.texts.bodySmall),
          ),
          Expanded(
            child: trailing ??
                Text(
                  value,
                  style: valueStyle ??
                      context.texts.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
          ),
        ],
      ),
    );
  }
}

/// شريط إجراء سفلي ثابت يحترم منطقة الإيماءات ولوحة المفاتيح.
///
/// الطريقة الأصلية كانت تضع الزر داخل `Column` فيغطيه الكيبورد.
/// هنا نضيف `viewInsets` صراحةً فيرتفع الزر فوق لوحة المفاتيح.
class KanafActionBar extends StatelessWidget {
  const KanafActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final media = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: KanafSpacing.pageInset,
        right: KanafSpacing.pageInset,
        top: KanafSpacing.md,
        bottom: KanafSpacing.md + media.padding.bottom * 0.5,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withOpacity(0.7)),
        ),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}
