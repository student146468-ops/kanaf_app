import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/donation_request.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../l10n/kanaf_localizations.dart';

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

  Map<String, dynamic>? get _targetHome {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) return Map<String, dynamic>.from(args);
    return null;
  }

  int? get _targetNeedId {
    final raw = _targetHome?['need_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('home.financialDonation')),
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
                    if (_targetHome != null) ...[
                      const SizedBox(height: KanafSpacing.lg),
                      KanafStaggeredEntrance(
                        index: 1,
                        child: _buildTargetSection(_targetHome!),
                      ),
                    ],
                    const SizedBox(height: KanafSpacing.xxl),
                    KanafStaggeredEntrance(
                      index: 2,
                      child: _buildAmountSection(),
                    ),
                    const SizedBox(height: KanafSpacing.xxl),
                    KanafStaggeredEntrance(
                      index: 3,
                      child: _buildPaymentSection(),
                    ),
                    const SizedBox(height: KanafSpacing.lg),
                    KanafStaggeredEntrance(
                      index: 4,
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
                    _isProcessing
                        ? context.tr('donation.confirming')
                        : context.tr('donation.continuePayment'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _donationModeLabel(BuildContext context, String mode) {
    return mode == _donationModes.first
        ? context.tr('donation.oneTime')
        : context.tr('donation.monthly');
  }

  String _paymentMethodLabel(BuildContext context, String method) {
    return switch (method) {
      'السداد عبر المصرف' => context.tr('payment.bankPay'),
      'بطاقة محلية' => context.tr('payment.localCard'),
      'تحويل مصرفي' => context.tr('payment.bankTransfer'),
      'محفظة إلكترونية' => context.tr('payment.wallet'),
      _ => method,
    };
  }
  // ── الأقسام ──────────────────────────────────────────────────

  Widget _buildTargetSection(Map<String, dynamic> home) {
    final scheme = context.colors;
    final name =
        home['name']?.toString() ?? context.tr('orphanage.defaultName');
    final address = home['address']?.toString() ?? '';

    return KanafCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.12),
              borderRadius: KanafRadii.sm,
            ),
            child: Icon(Icons.apartment_rounded, color: scheme.primary),
          ),
          const SizedBox(width: KanafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('donation.targetOrphanage'),
                    style: context.texts.bodySmall),
                const SizedBox(height: KanafSpacing.xxs),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall,
                ),
                if (address.isNotEmpty)
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    // SegmentedButton هو المكوّن الأصلي في M3 لاختيار واحد من قليل.
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: [
          for (final mode in _donationModes)
            ButtonSegment<String>(
              value: mode,
              label: Text(_donationModeLabel(context, mode),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
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
        KanafSectionHeader(
          title: context.tr('donation.amountTitle'),
          subtitle: context.tr('donation.amountSubtitle'),
        ),
        const SizedBox(height: KanafSpacing.lg),
        Wrap(
          spacing: KanafSpacing.sm,
          runSpacing: KanafSpacing.sm,
          children: [
            for (final amount in _quickAmounts)
              ChoiceChip(
                label: Text(
                  '${_amountFormat.format(amount)} ${context.tr('common.lydShort')}',
                ),
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
            hintText: context.tr('donation.enterAmount'),
            errorText: _amountError,
            suffixText: context.tr('common.lydShort'),
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
        KanafSectionHeader(title: context.tr('donation.paymentMethod')),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < _paymentMethods.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: KanafSpacing.lg),
                RadioListTile<String>(
                  value: _paymentMethods[i].name,
                  groupValue: _selectedPaymentMethod,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPaymentMethod = value);
                    }
                  },
                  title: Text(
                      _paymentMethodLabel(context, _paymentMethods[i].name)),
                  secondary: Icon(_paymentMethods[i].icon),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: KanafSpacing.md,
                  ),
                ),
              ],
            ],
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
              context.tr('donation.securityNote'),
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
      setState(() => _amountError = context.tr('donation.amountInvalid'));
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
                Text(sheetContext.tr('donation.reviewTitle'),
                    style: sheetContext.texts.titleLarge),
                const SizedBox(height: KanafSpacing.lg),
                KanafDetailRow(
                  label: sheetContext.tr('donation.value'),
                  value: '${_amountFormat.format(amount)} د.ل',
                  valueStyle: sheetContext.texts.titleLarge?.copyWith(
                    color: sheetContext.colors.primary,
                  ),
                ),
                KanafDetailRow(
                  label: sheetContext.tr('donation.type'),
                  value:
                      _donationModeLabel(sheetContext, _selectedDonationMode),
                ),
                KanafDetailRow(
                  label: sheetContext.tr('donation.paymentMethod'),
                  value:
                      _paymentMethodLabel(sheetContext, _selectedPaymentMethod),
                ),
                KanafDetailRow(
                  label: sheetContext.tr('donation.targetOrphanage'),
                  value: _targetHome?['name']?.toString() ??
                      sheetContext.tr('donation.generalFund'),
                ),
                const SizedBox(height: KanafSpacing.xxl),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(sheetContext.tr('donation.confirmComplete')),
                ),
                const SizedBox(height: KanafSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(sheetContext.tr('donation.edit')),
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
      needId: _targetNeedId,
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
      Navigator.pushNamed(
        context,
        KanafRoutes.donationSuccess,
        arguments: {
          'type': context.tr('home.financialDonation'),
          'status': 'failed',
          'summary': '${_amountFormat.format(amount)} دينار ليبي عبر '
              '$_selectedPaymentMethod',
          'amount': amount,
          'payment_method': _selectedPaymentMethod,
          'donation_mode': _selectedDonationMode,
          'target': _targetHome?['name']?.toString() ?? 'صندوق كنف العام',
          'error': provider.errorMessage ?? 'تعذر حفظ التبرع حالياً.',
          'retryRoute': KanafRoutes.financialDonation,
        },
      );
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      KanafRoutes.donationSuccess,
      arguments: {
        'type': context.tr('home.financialDonation'),
        // الرقم المرجعي هو المعرّف الحقيقي في قاعدة البيانات.
        'reference': 'KNF-${created.id}',
        'status': created.status,
        'amount': amount,
        'payment_method': _selectedPaymentMethod,
        'donation_mode': _selectedDonationMode,
        'target': _targetHome?['name']?.toString() ?? 'صندوق كنف العام',
        'date': DateTime.now().toIso8601String(),
        'summary': '${_amountFormat.format(amount)} د.ل عبر '
            '$_selectedPaymentMethod',
      },
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
