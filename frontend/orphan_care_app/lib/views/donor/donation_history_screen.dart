import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/donation_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_nav_shell.dart';
import '../../widgets/kanaf_states.dart';
import '../../l10n/kanaf_localizations.dart';

/// سجل تبرعات المتبرع.
///
/// أُعيد بناؤها على Material 3 مع حالات صريحة: هيكل عظمي أثناء
/// التحميل، رسالة خطأ قابلة لإعادة المحاولة، وحالة فراغ موجّهة.
/// سابقاً كان الفراغ يظهر كقائمة بيضاء بلا تفسير.
class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    // الجلب في initState لا في build — الجلب داخل build يُنتج
    // حلقة طلبات عند الفشل لأن notifyListeners يعيد البناء.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.myDonations.isEmpty && !provider.isLoading) {
        provider.fetchMyDonations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final all = provider.myDonations;
    final visible = _filter.apply(all);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('donation.historyTitle')),
        leading: IconButton(
          tooltip: context.tr('common.back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBack,
        ),
      ),
      bottomNavigationBar: const KanafNavBar(
        destinations: KanafNavDestinations.donor,
        currentIndex: 2,
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildFilterBar(all),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.fetchMyDonations,
                  child: KanafAsyncView(
                    isLoading: provider.isLoading,
                    isEmpty: visible.isEmpty,
                    errorMessage: all.isEmpty ? provider.errorMessage : null,
                    errorKind: provider.errorKind,
                    onRetry: provider.fetchMyDonations,
                    emptyIcon: all.isEmpty
                        ? Icons.volunteer_activism_outlined
                        : Icons.filter_alt_off_outlined,
                    emptyTitle: all.isEmpty
                        ? context.tr('donation.emptyHistory')
                        : context.tr('donation.emptyFilterTitle'),
                    emptyMessage: all.isEmpty
                        ? context.tr('donation.emptyHistoryMessage')
                        : context.tr('donation.emptyFilterMessage'),
                    builder: (context) => _buildList(visible),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(KanafRoutes.donorHome);
  }

  Widget _buildFilterBar(List<DonationModel> all) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KanafSpacing.pageInset,
        KanafSpacing.md,
        KanafSpacing.pageInset,
        KanafSpacing.md,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final option in _HistoryFilter.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: KanafSpacing.sm),
                child: FilterChip(
                  label: Text(
                    '${context.tr(option.labelKey)} (${option.apply(all).length})',
                  ),
                  selected: _filter == option,
                  onSelected: (_) => setState(() => _filter = option),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<DonationModel> donations) {
    final locale = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat('d MMMM y • h:mm a', locale);
    final amountFormat = NumberFormat.decimalPattern(locale);

    return ListView.separated(
      // AlwaysScrollable مطلوب حتى يعمل السحب للتحديث مع قائمة قصيرة.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        KanafSpacing.pageInset,
        0,
        KanafSpacing.pageInset,
        KanafSpacing.bottomSafeGutter,
      ),
      itemCount: donations.length,
      separatorBuilder: (_, __) => const SizedBox(height: KanafSpacing.md),
      itemBuilder: (context, index) {
        return KanafStaggeredEntrance(
          index: index,
          child: _DonationCard(
            donation: donations[index],
            dateFormat: dateFormat,
            amountFormat: amountFormat,
          ),
        );
      },
    );
  }
}

enum _HistoryFilter {
  all('common.all'),
  completed('donation.completed'),
  pending('donation.pending'),
  rejected('donation.rejected');

  const _HistoryFilter(this.labelKey);

  final String labelKey;

  List<DonationModel> apply(List<DonationModel> donations) {
    return switch (this) {
      _HistoryFilter.all => donations,
      _HistoryFilter.completed => donations
          .where((d) => d.status == 'completed' || d.status == 'accepted')
          .toList(),
      _HistoryFilter.pending =>
        donations.where((d) => d.status == 'pending').toList(),
      _HistoryFilter.rejected =>
        donations.where((d) => d.status == 'rejected').toList(),
    };
  }
}

class _DonationCard extends StatelessWidget {
  const _DonationCard({
    required this.donation,
    required this.dateFormat,
    required this.amountFormat,
  });

  final DonationModel donation;
  final DateFormat dateFormat;
  final NumberFormat amountFormat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final semantic = context.semantic;
    final isFinancial =
        donation.donationType == 'financial' || donation.amount != null;
    final date = donation.donationDate ?? donation.createdAt;
    final statusTone = _statusTone(context, donation.status);
    final title = donation.itemType.trim().isEmpty
        ? (isFinancial
            ? context.tr('home.financialDonation')
            : context.tr('inkind.title'))
        : donation.itemType.trim();
    final amountText = donation.amount == null
        ? null
        : '${amountFormat.format(donation.amount)} ${context.tr('common.lydShort')}';

    return KanafCard(
      onTap: () => Navigator.pushNamed(
        context,
        KanafRoutes.donationReceipt,
        arguments: donation,
      ),
      color: scheme.surfaceContainerLow.withOpacity(0.98),
      borderColor: statusTone.withOpacity(0.38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusTone.withOpacity(0.24),
                      scheme.primary.withOpacity(0.10),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: KanafRadii.md,
                ),
                child: Icon(
                  isFinancial
                      ? Icons.payments_outlined
                      : Icons.inventory_2_outlined,
                  size: 24,
                  color: statusTone,
                ),
              ),
              const SizedBox(width: KanafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.xxs),
                    Text(
                      '${context.tr('donation.reference')} KNF-${donation.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KanafSpacing.sm,
                  vertical: KanafSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusTone.withOpacity(0.13),
                  borderRadius: KanafRadii.pill,
                  border: Border.all(color: statusTone.withOpacity(0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(donation.status),
                        size: 14, color: statusTone),
                    const SizedBox(width: KanafSpacing.xs),
                    Text(
                      _statusLabel(context, donation.status),
                      style: context.texts.labelSmall?.copyWith(
                        color: statusTone,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KanafSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KanafSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.50),
              borderRadius: KanafRadii.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DonationInfoBlock(
                    icon: Icons.account_balance_wallet_outlined,
                    label: context.tr('donation.value'),
                    value: amountText ?? (donation.quantity ?? '-'),
                    accent: isFinancial ? scheme.primary : semantic.info,
                  ),
                ),
                Container(
                  width: 1,
                  height: 42,
                  color: scheme.outlineVariant.withOpacity(0.65),
                ),
                Expanded(
                  child: _DonationInfoBlock(
                    icon: Icons.schedule_outlined,
                    label: context.tr('donation.date'),
                    value: date == null ? '-' : dateFormat.format(date),
                  ),
                ),
              ],
            ),
          ),
          if (donation.needTitle != null) ...[
            const SizedBox(height: KanafSpacing.md),
            Container(
              padding: const EdgeInsets.all(KanafSpacing.md),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.08),
                borderRadius: KanafRadii.md,
              ),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: KanafSpacing.sm),
                  Expanded(
                    child: Text(
                      '${context.tr('donation.needTarget')}: ${donation.needTitle!}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: KanafSpacing.md),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: KanafSpacing.sm,
                  runSpacing: KanafSpacing.xs,
                  children: [
                    _HistoryMetaChip(
                      icon: Icons.tag_rounded,
                      label: 'KNF-${donation.id}',
                    ),
                    _HistoryMetaChip(
                      icon: Icons.credit_card_rounded,
                      label: _notBlank(donation.paymentMethod)
                          ? donation.paymentMethod!
                          : context.tr('donation.noPaymentMethod'),
                    ),
                    if (_isMonthly(donation))
                      _HistoryMetaChip(
                        icon: Icons.event_repeat_rounded,
                        label: context.tr('settings.monthlyDonation'),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              Tooltip(
                message: context.tr('donation.openReceipt'),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static bool _notBlank(String? value) =>
      value != null && value.trim().isNotEmpty;

  static bool _isMonthly(DonationModel donation) {
    final mode = donation.donationMode?.toLowerCase() ?? '';
    return mode.contains('month') || mode.contains('شهري');
  }

  static Color _statusTone(BuildContext context, String status) {
    final normalized = status.trim().toLowerCase();
    final semantic = context.semantic;
    final scheme = context.colors;
    if (normalized == 'completed' ||
        normalized == 'accepted' ||
        normalized == 'approved') {
      return semantic.success;
    }
    if (normalized == 'pending') return semantic.warning;
    if (normalized == 'rejected' || normalized == 'failed') {
      return scheme.error;
    }
    return context.colors.primary;
  }

  static IconData _statusIcon(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'completed' ||
        normalized == 'accepted' ||
        normalized == 'approved') {
      return Icons.check_circle_outline_rounded;
    }
    if (normalized == 'pending') return Icons.hourglass_top_rounded;
    if (normalized == 'rejected' || normalized == 'failed') {
      return Icons.cancel_outlined;
    }
    return Icons.info_outline_rounded;
  }

  static String _statusLabel(BuildContext context, String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'completed') return context.tr('status.completed');
    if (normalized == 'accepted' || normalized == 'approved') {
      return context.tr('status.accepted');
    }
    if (normalized == 'pending') return context.tr('donation.pending');
    if (normalized == 'rejected' || normalized == 'failed') {
      return context.tr('donation.rejected');
    }
    return status;
  }
}

class _DonationInfoBlock extends StatelessWidget {
  const _DonationInfoBlock({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final tone = accent ?? scheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18, color: tone),
        const SizedBox(width: KanafSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: KanafSpacing.xxs),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.texts.titleSmall?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryMetaChip extends StatelessWidget {
  const _HistoryMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KanafSpacing.sm,
        vertical: KanafSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: KanafRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: KanafSpacing.xs),
          Text(label, style: context.texts.labelSmall),
        ],
      ),
    );
  }
}
