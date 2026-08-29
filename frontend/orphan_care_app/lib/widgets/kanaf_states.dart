import 'package:flutter/material.dart';

import '../services/api_failure.dart';
import '../theme/kanaf_tokens.dart';
import '../l10n/kanaf_localizations.dart';

/// حالات المحتوى الأربع: تحميل، خطأ، فراغ، ومحتوى.
///
/// الواجهة القديمة لم تكن تملك أياً منها بشكل صريح: القوائم الفارغة
/// كانت تظهر كشاشة بيضاء، والأخطاء كـ SnackBar عابر يختفي قبل أن
/// يقرأه المستخدم. هذا الملف يجعل الحالات مواطنين من الدرجة الأولى.

/// هيكل عظمي متحرك (shimmer) يُعرض أثناء التحميل.
///
/// مفضّل على المؤشر الدائري لأنه يوصّل **شكل** المحتوى القادم،
/// فيبدو الانتظار أقصر ولا تقفز الواجهة عند وصول البيانات.
class KanafSkeleton extends StatefulWidget {
  const KanafSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius = KanafRadii.sm,
  });

  /// هيكل يحاكي بطاقة كاملة.
  const KanafSkeleton.card({super.key})
      : height = 108,
        width = double.infinity,
        borderRadius = KanafRadii.lg;

  final double height;
  final double? width;
  final BorderRadius borderRadius;

  @override
  State<KanafSkeleton> createState() => _KanafSkeletonState();
}

class _KanafSkeletonState extends State<KanafSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1300),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // اللمعان يتحرك من الحافة الخلفية للأمامية حسب اتجاه النص.
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final progress = _controller.value * 2 - 1;
        final slide = isRtl ? -progress : progress;

        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 + slide, 0),
              end: Alignment(1 + slide, 0),
              colors: [
                scheme.surfaceContainerHighest,
                scheme.surfaceContainerHighest.withOpacity(0.45),
                scheme.surfaceContainerHighest,
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}

/// قائمة هياكل عظمية — تُستخدم كحالة تحميل للقوائم.
class KanafSkeletonList extends StatelessWidget {
  const KanafSkeletonList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(KanafSpacing.pageInset),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: KanafSpacing.md),
      itemBuilder: (_, __) => const KanafSkeleton.card(),
    );
  }
}

/// حالة عرض مركزية: أيقونة + عنوان + شرح + إجراء اختياري.
/// أساس مشترك لحالتي الفراغ والخطأ لضمان تطابق الإيقاع البصري.
class KanafMessageState extends StatelessWidget {
  const KanafMessageState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tone = KanafMessageTone.neutral,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final KanafMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final semantic = context.semantic;

    final (Color iconColor, Color iconBackground) = switch (tone) {
      KanafMessageTone.neutral => (
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest,
        ),
      KanafMessageTone.error => (scheme.error, scheme.errorContainer),
      KanafMessageTone.success => (
          semantic.success,
          semantic.successContainer,
        ),
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KanafSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: KanafRadii.xl,
              ),
              child: Icon(icon, size: 42, color: iconColor),
            ),
            const SizedBox(height: KanafSpacing.xxl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.texts.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: KanafSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.texts.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: KanafSpacing.xxl),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum KanafMessageTone { neutral, error, success }

/// يختار الحالة المناسبة تلقائياً: تحميل / خطأ / فراغ / محتوى.
///
/// وجود هذا المكوّن يمنع تكرار منطق `if (isLoading) ... else if (error)`
/// في ستين شاشة، ويضمن أن كل شاشة تتصرف بنفس الطريقة.
class KanafAsyncView extends StatelessWidget {
  const KanafAsyncView({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.builder,
    this.errorMessage,
    this.errorKind,
    this.onRetry,
    this.loadingPlaceholder,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle,
    this.emptyMessage,
  });

  final bool isLoading;
  final bool isEmpty;
  final String? errorMessage;

  /// سبب الفشل. يحدد **أي** حالة خطأ تُعرض — وبدونه كانت كل الأعطال
  /// تظهر كانقطاع في الاتصال.
  final ApiFailureKind? errorKind;

  final VoidCallback? onRetry;
  final WidgetBuilder builder;
  final Widget? loadingPlaceholder;
  final IconData emptyIcon;
  final String? emptyTitle;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    // التحميل يُعرض فقط عندما لا يوجد محتوى سابق، حتى لا يختفي
    // ما يراه المستخدم عند التحديث في الخلفية.
    if (isLoading && isEmpty) {
      return loadingPlaceholder ?? const KanafSkeletonList();
    }

    if (errorMessage != null && isEmpty) {
      return KanafFailureState(
        message: errorMessage!,
        kind: errorKind,
        onRetry: onRetry,
      );
    }

    if (isEmpty) {
      return KanafMessageState(
        icon: emptyIcon,
        title: emptyTitle ?? context.tr('state.emptyTitle'),
        message: emptyMessage,
        actionLabel: onRetry == null ? null : context.tr('common.update'),
        onAction: onRetry,
      );
    }

    return builder(context);
  }
}

/// حالة الفشل، معروضة حسب **سببه** لا كقالب واحد.
///
/// شاشة «لا يوجد اتصال بالإنترنت» بأيقونة السحابة المقطوعة لا تظهر
/// إلا عند انقطاع فعلي مؤكَّد. المستخدم المتصل الذي يصادف عطباً في
/// الخادم أو انتهاء جلسة يرى الرسالة التي تخص حالته — فلا يُرسَل
/// لفحص شبكة سليمة.
class KanafFailureState extends StatelessWidget {
  const KanafFailureState({
    super.key,
    required this.message,
    this.kind,
    this.onRetry,
  });

  final String message;
  final ApiFailureKind? kind;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String title, KanafMessageTone tone) = switch (kind) {
      ApiFailureKind.offline => (
          Icons.wifi_off_rounded,
          context.tr('state.offlineTitle'),
          KanafMessageTone.neutral,
        ),
      ApiFailureKind.unreachable => (
          Icons.cloud_off_rounded,
          context.tr('state.unreachableTitle'),
          KanafMessageTone.error,
        ),
      ApiFailureKind.timeout => (
          Icons.hourglass_disabled_rounded,
          context.tr('state.timeoutTitle'),
          KanafMessageTone.neutral,
        ),
      ApiFailureKind.server => (
          Icons.dns_outlined,
          context.tr('state.serverTitle'),
          KanafMessageTone.error,
        ),
      ApiFailureKind.unauthorized => (
          Icons.lock_outline_rounded,
          context.tr('state.unauthorizedTitle'),
          KanafMessageTone.error,
        ),
      ApiFailureKind.request => (
          Icons.report_gmailerrorred_rounded,
          context.tr('state.requestTitle'),
          KanafMessageTone.error,
        ),
      // بلا تصنيف: رسالة محايدة لا تدّعي معرفة السبب.
      _ => (
          Icons.error_outline_rounded,
          context.tr('state.loadFailedTitle'),
          KanafMessageTone.error,
        ),
    };

    final canRetry = onRetry != null && (kind?.isRetryable ?? true);

    return KanafMessageState(
      icon: icon,
      title: title,
      message: message,
      tone: tone,
      actionLabel: canRetry ? context.tr('common.retry') : null,
      onAction: canRetry ? onRetry : null,
    );
  }
}

/// شريحة حالة ملوّنة — تحوّل حالات الخادم الإنجليزية إلى عربية واضحة.
///
/// هذا هو المكان **الوحيد** الذي يترجم `pending/accepted/...`،
/// فلا تتناقض التسميات بين الشاشات كما كان يحدث.
class KanafStatusChip extends StatelessWidget {
  const KanafStatusChip(
      {super.key, required this.status, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final scheme = context.colors;

    final (String label, Color foreground, Color background, IconData icon) =
        switch (status.trim().toLowerCase()) {
      'pending' => (
          context.tr('status.pending'),
          semantic.onWarningContainer,
          semantic.warningContainer,
          Icons.hourglass_top_rounded,
        ),
      'accepted' || 'approved' => (
          context.tr('status.accepted'),
          semantic.onInfoContainer,
          semantic.infoContainer,
          Icons.thumb_up_outlined,
        ),
      'completed' => (
          context.tr('status.completed'),
          semantic.onSuccessContainer,
          semantic.successContainer,
          Icons.check_circle_outline_rounded,
        ),
      'rejected' => (
          context.tr('status.rejected'),
          scheme.onErrorContainer,
          scheme.errorContainer,
          Icons.cancel_outlined,
        ),
      'open' => (
          context.tr('status.open'),
          semantic.onSuccessContainer,
          semantic.successContainer,
          Icons.lock_open_rounded,
        ),
      'closed' || 'archived' => (
          context.tr('status.closed'),
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest,
          Icons.archive_outlined,
        ),
      _ => (
          status,
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest,
          Icons.label_outline_rounded,
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? KanafSpacing.sm : KanafSpacing.md,
        vertical: compact ? KanafSpacing.xs : KanafSpacing.sm - 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: KanafRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: foreground),
          SizedBox(width: compact ? KanafSpacing.xs : KanafSpacing.sm - 2),
          Text(
            label,
            style:
                (compact ? context.texts.labelSmall : context.texts.labelMedium)
                    ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
