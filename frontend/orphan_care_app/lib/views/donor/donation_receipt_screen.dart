import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/donation_model.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';
import '../../l10n/kanaf_localizations.dart';

class DonationReceiptScreen extends StatelessWidget {
  const DonationReceiptScreen({super.key});

  static final DateFormat _dateFormat = DateFormat('d MMMM y • h:mm a', 'ar');
  static final NumberFormat _amountFormat = NumberFormat.decimalPattern('ar');

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final donation = args is DonationModel ? args : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('donation.receiptTitle')),
        leading: const BackButton(),
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: donation == null
              ? KanafMessageState(
                  icon: Icons.receipt_long_outlined,
                  title: context.tr('donation.receiptUnavailable'),
                  message: context.tr('donation.openReceiptFromHistory'),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    KanafSpacing.pageInset,
                    KanafSpacing.lg,
                    KanafSpacing.pageInset,
                    KanafSpacing.bottomSafeGutter,
                  ),
                  children: [
                    _ReceiptHeader(donation: donation),
                    const SizedBox(height: KanafSpacing.lg),
                    KanafCard(
                      child: Column(
                        children: [
                          KanafDetailRow(
                            label: 'الحالة',
                            value: donation.status,
                            trailing: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: KanafStatusChip(status: donation.status),
                            ),
                          ),
                          KanafDetailRow(
                            label: 'الرقم',
                            value: 'KNF-${donation.id}',
                          ),
                          KanafDetailRow(
                            label: 'التاريخ',
                            value: _dateFormat.format(
                              donation.donationDate ??
                                  donation.createdAt ??
                                  DateTime.now(),
                            ),
                          ),
                          KanafDetailRow(
                            label: 'النوع',
                            value: _donationTypeLabel(donation),
                          ),
                          if (donation.amount != null)
                            KanafDetailRow(
                              label: 'المبلغ',
                              value:
                                  '${_amountFormat.format(donation.amount)} دينار ليبي',
                              valueStyle: context.texts.titleMedium?.copyWith(
                                color: context.colors.primary,
                              ),
                            ),
                          if (_notBlank(donation.paymentMethod))
                            KanafDetailRow(
                              label: 'طريقة الدفع',
                              value: donation.paymentMethod!,
                            ),
                          if (_notBlank(donation.donationMode))
                            KanafDetailRow(
                              label: 'التكرار',
                              value: _modeLabel(donation.donationMode!),
                            ),
                          if (_notBlank(donation.needTitle))
                            KanafDetailRow(
                              label: 'الهدف',
                              value: donation.needTitle!,
                            ),
                          if (_notBlank(donation.quantity))
                            KanafDetailRow(
                              label: 'الكمية',
                              value: donation.quantity!,
                            ),
                          if (_notBlank(donation.description))
                            KanafDetailRow(
                              label: 'الوصف',
                              value: donation.description!,
                            ),
                          if (_notBlank(donation.notes))
                            KanafDetailRow(
                              label: 'ملاحظات',
                              value: donation.notes!,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.lg),
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: 'KNF-${donation.id}'),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text(context.tr('donation.referenceCopied'))),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(context.tr('donation.copyReference')),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  static bool _notBlank(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _donationTypeLabel(DonationModel donation) {
    final isFinancial =
        donation.donationType == 'financial' || donation.amount != null;
    return isFinancial ? 'تبرع مالي' : 'تبرع عيني';
  }

  static String _modeLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('month') || normalized.contains('شهري')) {
      return 'شهري';
    }
    return 'مرة واحدة';
  }
}

class _ReceiptHeader extends StatelessWidget {
  const _ReceiptHeader({required this.donation});

  final DonationModel donation;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isFinancial =
        donation.donationType == 'financial' || donation.amount != null;

    return KanafCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.12),
              borderRadius: KanafRadii.md,
            ),
            child: Icon(
              isFinancial
                  ? Icons.payments_outlined
                  : Icons.inventory_2_outlined,
              color: scheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: KanafSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donation.itemType.isEmpty
                      ? (isFinancial ? 'تبرع مالي' : 'تبرع عيني')
                      : donation.itemType,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleMedium,
                ),
                const SizedBox(height: KanafSpacing.xs),
                Text(
                  'رقم مرجعي KNF-${donation.id}',
                  style: context.texts.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
