import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../router/kanaf_router.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

/// شاشة تأكيد التبرع.
///
/// تُعرض فقط بعد أن يؤكد الخادم الحفظ ويُعيد معرّفاً حقيقياً.
/// النص يقول «تم تسجيل» لا «تم إتمام» — لأن الحالة الفعلية عند
/// الإنشاء هي `pending` بانتظار مراجعة دار الرعاية. الصدق في
/// الصياغة هو استمرار لإصلاح باغ عدم التزامن.
class DonationSuccessScreen extends StatelessWidget {
  const DonationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final reference = args?['reference']?.toString();
    final type = args?['type']?.toString() ?? 'تبرع';
    final summary = args?['summary']?.toString();
    final status = args?['status']?.toString() ?? 'pending';

    return Scaffold(
      body: KanafBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(KanafSpacing.pageInset),
                  children: [
                    const SizedBox(height: KanafSpacing.xxl),
                    const _SuccessSeal(),
                    const SizedBox(height: KanafSpacing.xxl),
                    Text(
                      'تم تسجيل مساهمتك',
                      textAlign: TextAlign.center,
                      style: context.texts.headlineMedium,
                    ),
                    const SizedBox(height: KanafSpacing.md),
                    Text(
                      'وصلت مساهمتك إلى المنظومة بنجاح. ستراجعها دار الرعاية '
                      'وتصلك التحديثات في سجل تبرعاتك.',
                      textAlign: TextAlign.center,
                      style: context.texts.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.xxl),
                    KanafCard(
                      child: Column(
                        children: [
                          KanafDetailRow(
                            label: 'الحالة',
                            value: status,
                            trailing: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: KanafStatusChip(status: status),
                            ),
                          ),
                          KanafDetailRow(label: 'النوع', value: type),
                          if (summary != null)
                            KanafDetailRow(label: 'التفاصيل', value: summary),
                          if (reference != null) ...[
                            const Divider(height: KanafSpacing.xxl),
                            _ReferenceRow(reference: reference),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              KanafActionBar(
                child: Column(
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        KanafRoutes.donationHistory,
                        (route) => route.settings.name == KanafRoutes.donorHome,
                      ),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('عرض سجل تبرعاتي'),
                    ),
                    const SizedBox(height: KanafSpacing.sm),
                    TextButton(
                      // إفراغ المكدّس حتى لا يعود المستخدم إلى نموذج
                      // التبرع بزر الرجوع فيتبرع مرتين بالخطأ.
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        KanafRoutes.donorHome,
                        (route) => false,
                      ),
                      child: const Text('العودة إلى الرئيسية'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// خاتم النجاح: حلقة برتقالية حول علامة صحّ خضراء.
/// لمسة كَنَفْ تظهر في الحلقة، والدلالة (النجاح) تبقى خضراء
/// لأن اللون الدلالي أهم من الهوية في لحظة التأكيد.
class _SuccessSeal extends StatefulWidget {
  const _SuccessSeal();

  @override
  State<_SuccessSeal> createState() => _SuccessSealState();
}

class _SuccessSealState extends State<_SuccessSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: KanafDuration.slow,
    vsync: this,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final ring = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.65, curve: KanafCurves.emphasizedDecelerate),
    );
    final mark = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1, curve: Curves.elasticOut),
    );

    return Center(
      child: SizedBox.square(
        dimension: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // الحلقة ترتسم تدريجياً — إحساس «الختم» لا مجرد ظهور.
            AnimatedBuilder(
              animation: ring,
              builder: (context, _) => SizedBox.square(
                dimension: 132,
                child: CircularProgressIndicator(
                  value: ring.value,
                  strokeWidth: 4,
                  color: KanafPalette.seed,
                  backgroundColor: context.colors.surfaceContainerHighest,
                ),
              ),
            ),
            ScaleTransition(
              scale: mark,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: semantic.successContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: semantic.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// الرقم المرجعي مع إمكانية النسخ.
/// الرقم صار حقيقياً (معرّف قاعدة البيانات) فنسخه صار ذا معنى.
class _ReferenceRow extends StatelessWidget {
  const _ReferenceRow({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الرقم المرجعي', style: context.texts.bodySmall),
              const SizedBox(height: KanafSpacing.xs),
              Text(
                reference,
                style: context.texts.titleMedium?.copyWith(
                  letterSpacing: 0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'نسخ الرقم المرجعي',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: reference));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم نسخ الرقم المرجعي')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 20),
        ),
      ],
    );
  }
}
