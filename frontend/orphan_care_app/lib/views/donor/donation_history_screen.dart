import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/donation_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

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

  static final DateFormat _dateFormat = DateFormat('d MMMM y • h:mm a', 'ar');
  static final NumberFormat _amountFormat = NumberFormat.decimalPattern('ar');

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
      appBar: AppBar(title: const Text('سجل التبرعات')),
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
                        ? 'لم تقدّم أي تبرع بعد'
                        : 'لا نتائج لهذا التصنيف',
                    emptyMessage: all.isEmpty
                        ? 'عندما تقدّم مساهمتك الأولى ستظهر هنا مع رقمها المرجعي وحالتها.'
                        : 'جرّب تصنيفاً آخر لعرض بقية تبرعاتك.',
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
                  label: Text('${option.label} (${option.apply(all).length})'),
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
            dateFormat: _dateFormat,
            amountFormat: _amountFormat,
          ),
        );
      },
    );
  }
}

enum _HistoryFilter {
  all('الكل'),
  completed('مكتملة'),
  pending('قيد المراجعة'),
  rejected('مرفوضة');

  const _HistoryFilter(this.label);

  final String label;

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
    final isFinancial =
        donation.donationType == 'financial' || donation.amount != null;
    final date = donation.donationDate ?? donation.createdAt;

    return KanafCard(
      onTap: () => Navigator.pushNamed(
        context,
        KanafRoutes.donationReceipt,
        arguments: donation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: KanafRadii.sm,
                ),
                child: Icon(
                  isFinancial
                      ? Icons.payments_outlined
                      : Icons.inventory_2_outlined,
                  size: 22,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: KanafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donation.itemType.isEmpty
                          ? (isFinancial ? 'تبرع مالي' : 'تبرع عيني')
                          : donation.itemType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall,
                    ),
                    if (date != null) ...[
                      const SizedBox(height: KanafSpacing.xxs),
                      Text(dateFormat.format(date),
                          style: context.texts.bodySmall),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  KanafStatusChip(status: donation.status, compact: true),
                  const SizedBox(height: KanafSpacing.xs),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
          if (isFinancial && donation.amount != null) ...[
            const Divider(height: KanafSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('القيمة', style: context.texts.bodySmall),
                Text(
                  '${amountFormat.format(donation.amount)} د.ل',
                  style: context.texts.titleMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ],
          if (donation.needTitle != null) ...[
            const SizedBox(height: KanafSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: KanafSpacing.sm),
                Expanded(
                  child: Text(
                    donation.needTitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: KanafSpacing.md),
          Wrap(
            spacing: KanafSpacing.sm,
            runSpacing: KanafSpacing.xs,
            children: [
              _HistoryMetaChip(
                icon: Icons.tag_rounded,
                label: 'KNF-${donation.id}',
              ),
              if (_notBlank(donation.paymentMethod))
                _HistoryMetaChip(
                  icon: Icons.account_balance_wallet_outlined,
                  label: donation.paymentMethod!,
                ),
              if (_isMonthly(donation))
                const _HistoryMetaChip(
                  icon: Icons.event_repeat_rounded,
                  label: 'شهري',
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
