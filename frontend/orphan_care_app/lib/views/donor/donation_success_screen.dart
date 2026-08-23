import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
    final amount = args?['amount'];
    final paymentMethod = args?['payment_method']?.toString();
    final donationMode = args?['donation_mode']?.toString();
    final target = args?['target']?.toString();
    final error = args?['error']?.toString();
    final retryRoute = args?['retryRoute']?.toString();
    final date =
        DateTime.tryParse(args?['date']?.toString() ?? '') ?? DateTime.now();
    final state = _DonationResultState.fromStatus(status);
    final amountText = _amountText(amount);

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
                    _ResultSeal(state: state),
                    const SizedBox(height: KanafSpacing.xxl),
                    Text(
                      state.title,
                      textAlign: TextAlign.center,
                      style: context.texts.headlineMedium,
                    ),
                    const SizedBox(height: KanafSpacing.md),
                    Text(
                      error ?? state.message,
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
                          KanafDetailRow(
                            label: 'التاريخ',
                            value: DateFormat('d MMMM y • h:mm a', 'ar')
                                .format(date),
                          ),
                          if (amountText != null)
                            KanafDetailRow(
                              label: 'المبلغ',
                              value: amountText,
                              valueStyle: context.texts.titleMedium?.copyWith(
                                color: context.colors.primary,
                              ),
                            ),
                          if (_notBlank(donationMode))
                            KanafDetailRow(
                              label: 'نوع التبرع',
                              value: _modeLabel(donationMode!),
                            ),
                          if (_notBlank(paymentMethod))
                            KanafDetailRow(
                              label: 'طريقة الدفع',
                              value: paymentMethod!,
                            ),
                          if (_notBlank(target))
                            KanafDetailRow(label: 'الهدف', value: target!),
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
                      onPressed: state == _DonationResultState.failed &&
                              retryRoute != null
                          ? () => Navigator.pushReplacementNamed(
                                context,
                                retryRoute,
                              )
                          : () => Navigator.pushNamedAndRemoveUntil(
                                context,
                                KanafRoutes.donationHistory,
                                (route) =>
                                    route.settings.name ==
                                    KanafRoutes.donorHome,
                              ),
                      icon: Icon(
                        state == _DonationResultState.failed
                            ? Icons.refresh_rounded
                            : Icons.receipt_long_outlined,
                      ),
                      label: Text(
                        state == _DonationResultState.failed
                            ? 'إعادة المحاولة'
                            : 'عرض سجل تبرعاتي',
                      ),
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

  static bool _notBlank(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String? _amountText(dynamic amount) {
    final value =
        amount is num ? amount.toDouble() : double.tryParse('$amount');
    if (value == null) return null;
    return '${NumberFormat.decimalPattern('ar').format(value)} دينار ليبي';
  }

  static String _modeLabel(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('month') || normalized.contains('شهري')
        ? 'شهري'
        : 'مرة واحدة';
  }
}

enum _DonationResultState {
  success(
    'تم تسجيل مساهمتك',
    'تمت العملية بنجاح وحُفظت تفاصيلها في سجل تبرعاتك.',
  ),
  pending(
    'تم تسجيل مساهمتك',
    'وصلت مساهمتك إلى المنظومة. ستراجعها دار الرعاية وتظهر تحديثاتها في السجل.',
  ),
  failed(
    'تعذر إكمال التبرع',
    'لم يتم تسجيل العملية. راجع السبب وحاول مرة أخرى.',
  );

  const _DonationResultState(this.title, this.message);

  final String title;
  final String message;

  static _DonationResultState fromStatus(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'failed' || normalized == 'failure') {
      return _DonationResultState.failed;
    }
    if (normalized == 'completed' || normalized == 'accepted') {
      return _DonationResultState.success;
    }
    return _DonationResultState.pending;
  }
}

class _ResultSeal extends StatefulWidget {
  const _ResultSeal({required this.state});

  final _DonationResultState state;

  @override
  State<_ResultSeal> createState() => _ResultSealState();
}

class _ResultSealState extends State<_ResultSeal>
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
    final scheme = context.colors;
    final (Color container, Color foreground, IconData icon) =
        switch (widget.state) {
      _DonationResultState.success => (
          semantic.successContainer,
          semantic.success,
          Icons.check_rounded,
        ),
      _DonationResultState.pending => (
          semantic.warningContainer,
          semantic.onWarningContainer,
          Icons.hourglass_top_rounded,
        ),
      _DonationResultState.failed => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.close_rounded,
        ),
    };
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
                  color: container,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 52,
                  color: foreground,
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
