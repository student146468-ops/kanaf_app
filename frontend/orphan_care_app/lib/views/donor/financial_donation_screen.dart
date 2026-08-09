import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/donation_request.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';

/// شاشة التبرع المالي.
///
/// أُعيد بناؤها بالكامل على Material 3: لا ألوان مرصوفة يدوياً، ولا
/// إطار يحاكي عرض المتصفح. المكوّنات مأخوذة من الثيم فتستجيب للوضع
/// الداكن ولتكبير الخط تلقائياً.
class FinancialDonationScreen extends StatefulWidget {
  const FinancialDonationScreen({super.key});

  @override
  State<FinancialDonationScreen> createState() =>
      _FinancialDonationScreenState();
}

class _FinancialDonationScreenState extends State<FinancialDonationScreen> {
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  String _selectedPaymentMethod = _paymentMethods.first.name;
  String _selectedDonationMode = _donationModes.first;
  String? _amountError;
  bool _isProcessing = false;

  /// لا سقف عملي على التبرع — الحد الأعلى مليون دينار، وهو نفس الحد
  /// المفروض في الخادم لصد القيم الخاطئة فقط.
  static const double _maxDonationAmount = 1000000;

  static const List<String> _donationModes = ['تبرع مرة واحدة', 'تبرع شهري'];
  static const List<int> _quickAmounts = [20, 50, 100, 200, 500, 1000];

  static const List<_PaymentMethod> _paymentMethods = [
    _PaymentMethod('السداد عبر المصرف', Icons.account_balance_outlined),
    _PaymentMethod('بطاقة محلية', Icons.credit_card_rounded),
    _PaymentMethod('تحويل مصرفي', Icons.swap_horiz_rounded),
    _PaymentMethod('محفظة إلكترونية', Icons.account_balance_wallet_outlined),
  ];

  /// تنسيق عربي بفواصل آلاف — «١٠٠٠» وحدها تُقرأ بصعوبة.
  static final NumberFormat _amountFormat = NumberFormat.decimalPattern('ar');

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  double? get _enteredAmount {
    final raw = _amountController.text.trim().replaceAll(',', '');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  bool get _canSubmit {
    final amount = _enteredAmount;
    return !_isProcessing && amount != null && amount > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التبرع المالي'),
        leading: const BackButton(),
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  // BouncingScrollPhysics على أندرويد يبدو غريباً؛
                  // الافتراضي في M3 يطابق سلوك المنصة.
                  padding: const EdgeInsets.fromLTRB(
                    KanafSpacing.pageInset,
                    KanafSpacing.lg,
                    KanafSpacing.pageInset,
                    KanafSpacing.xxl,
                  ),
                  children: [
                    KanafStaggeredEntrance(
                      index: 0,
                      child: _buildModeSelector(),
                    ),
                    const SizedBox(height: KanafSpacing.xxl),
                    KanafStaggeredEntrance(
                      index: 1,
                      child: _buildAmountSection(),
                    ),
                    const SizedBox(height: KanafSpacing.xxl),
                    KanafStaggeredEntrance(
                      index: 2,
                      child: _buildPaymentSection(),
                    ),
                    const SizedBox(height: KanafSpacing.lg),
                    KanafStaggeredEntrance(
                      index: 3,
                      child: _buildSecurityNote(),
                    ),
                  ],
                ),
              ),
              KanafActionBar(
                child: FilledButton.icon(
                  onPressed: _canSubmit ? _reviewDonation : null,
                  icon: _isProcessing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline_rounded),
                  label: Text(
                    _isProcessing ? 'جاري التأكيد...' : 'متابعة الدفع',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── الأقسام ──────────────────────────────────────────────────

  Widget _buildModeSelector() {
    // SegmentedButton هو المكوّن الأصلي في M3 لاختيار واحد من قليل.
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: [
          for (final mode in _donationModes)
            ButtonSegment<String>(
              value: mode,
              label: Text(mode, maxLines: 1, overflow: TextOverflow.ellipsis),
              icon: Icon(
                mode == _donationModes.first
                    ? Icons.bolt_rounded
                    : Icons.event_repeat_rounded,
              ),
            ),
        ],
        selected: {_selectedDonationMode},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          setState(() => _selectedDonationMode = selection.first);
        },
      ),
    );
  }

  Widget _buildAmountSection() {
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KanafSectionHeader(
          title: 'قيمة التبرع',
          subtitle: 'اختر مبلغاً جاهزاً أو أدخل ما تشاء — لا حد أدنى',
        ),
        const SizedBox(height: KanafSpacing.lg),
        Wrap(
          spacing: KanafSpacing.sm,
          runSpacing: KanafSpacing.sm,
          children: [
            for (final amount in _quickAmounts)
              ChoiceChip(
                label: Text('${_amountFormat.format(amount)} د.ل'),
                selected: _enteredAmount == amount,
                onSelected: (_) {
                  setState(() {
                    _amountController.text = '$amount';
                    _amountError = null;
                  });
                  _amountFocus.unfocus();
                },
              ),
          ],
        ),
        const SizedBox(height: KanafSpacing.lg),
        TextField(
          controller: _amountController,
          focusNode: _amountFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          // منع إدخال حروف أو رموز — أنظف من التحقق بعد الإدخال.
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: context.texts.displaySmall?.copyWith(
            color: scheme.primary,
            fontFamily: KanafThemeFonts.display,
          ),
          decoration: InputDecoration(
            hintText: 'أدخل المبلغ',
            errorText: _amountError,
            suffixText: 'د.ل',
            suffixStyle: context.texts.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            prefixIcon: const Icon(Icons.savings_outlined),
          ),
          onChanged: (_) => setState(() => _amountError = null),
          onSubmitted: (_) {
            if (_canSubmit) _reviewDonation();
          },
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KanafSectionHeader(title: 'طريقة الدفع'),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(
          padding: EdgeInsets.zero,
          // RadioGroup هو الواجهة الحديثة: تدير المجموعة قيمة واحدة
          // وتتولى الوصولية (a11y) بدل تمرير groupValue لكل عنصر.
          child: RadioGroup<String>(
            groupValue: _selectedPaymentMethod,
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedPaymentMethod = value);
              }
            },
            child: Column(
              children: [
                for (var i = 0; i < _paymentMethods.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: KanafSpacing.lg),
                  RadioListTile<String>(
                    value: _paymentMethods[i].name,
                    title: Text(_paymentMethods[i].name),
                    secondary: Icon(_paymentMethods[i].icon),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: KanafSpacing.md,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityNote() {
    final semantic = context.semantic;
    return Container(
      padding: const EdgeInsets.all(KanafSpacing.md),
      decoration: BoxDecoration(
        color: semantic.infoContainer,
        borderRadius: KanafRadii.md,
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 20, color: semantic.info),
          const SizedBox(width: KanafSpacing.md),
          Expanded(
            child: Text(
              'لا يُسجَّل التبرع إلا بعد تأكيد الخادم، ويصلك رقم مرجعي حقيقي.',
              style: context.texts.bodySmall?.copyWith(
                color: semantic.onInfoContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── منطق الإرسال ─────────────────────────────────────────────

  Future<void> _reviewDonation() async {
    final amount = _enteredAmount;
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'أدخل قيمة صحيحة للتبرع');
      return;
    }
    if (amount > _maxDonationAmount) {
      setState(() {
        _amountError =
            'الحد الأعلى ${_amountFormat.format(_maxDonationAmount)} د.ل';
      });
      return;
    }

    _amountFocus.unfocus();
    final confirmed = await _showReviewSheet(amount);
    if (confirmed != true || !mounted) return;
    await _submitDonation(amount);
  }

  Future<bool?> _showReviewSheet(double amount) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KanafSpacing.pageInset,
              0,
              KanafSpacing.pageInset,
              KanafSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مراجعة التبرع', style: sheetContext.texts.titleLarge),
                const SizedBox(height: KanafSpacing.lg),
                KanafDetailRow(
                  label: 'القيمة',
                  value: '${_amountFormat.format(amount)} د.ل',
                  valueStyle: sheetContext.texts.titleLarge?.copyWith(
                    color: sheetContext.colors.primary,
                  ),
                ),
                KanafDetailRow(
                  label: 'نوع التبرع',
                  value: _selectedDonationMode,
                ),
                KanafDetailRow(
                  label: 'وسيلة الدفع',
                  value: _selectedPaymentMethod,
                ),
                const SizedBox(height: KanafSpacing.xxl),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('تأكيد وإتمام التبرع'),
                ),
                const SizedBox(height: KanafSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('تعديل'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitDonation(double amount) async {
    final request = DonationRequest.financial(
      amount: amount,
      paymentMethod: _selectedPaymentMethod,
      donationMode: _selectedDonationMode,
    );
    final validationError = request.validationError();
    if (validationError != null) {
      setState(() => _amountError = validationError);
      return;
    }

    setState(() => _isProcessing = true);
    final provider = AppProviderScope.of(context);
    final created = await provider.submitDonation(request);
    if (!mounted) return;
    setState(() => _isProcessing = false);

    // `created == null` تعني أن الخادم لم يؤكد الحفظ — لا شاشة نجاح إطلاقاً.
    if (created == null) {
      _showError(provider.errorMessage ?? 'تعذر حفظ التبرع حالياً.');
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      KanafRoutes.donationSuccess,
      arguments: {
        'type': 'تبرع مالي',
        // الرقم المرجعي هو المعرّف الحقيقي في قاعدة البيانات.
        'reference': 'KNF-${created.id}',
        'status': created.status,
        'summary': '${_amountFormat.format(amount)} د.ل عبر '
            '$_selectedPaymentMethod',
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        // الأخطاء تحتاج وقتاً للقراءة، والمستخدم يملك إغلاقها.
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'حسناً',
          onPressed: () =>
              ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }
}

class _PaymentMethod {
  const _PaymentMethod(this.name, this.icon);

  final String name;
  final IconData icon;
}

/// أسماء خطوط الثيم، مكشوفة للاستخدام في أنماط نصية موضعية.
abstract final class KanafThemeFonts {
  static const String display = 'Tajawal';
  static const String body = 'Vazirmatn';
}
