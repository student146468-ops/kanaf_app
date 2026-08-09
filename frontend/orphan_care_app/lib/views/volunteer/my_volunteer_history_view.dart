import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider_scope.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

/// سجل مشاركات المتطوع.
///
/// النسخة السابقة كانت تُسطّح كل طلب إلى `Map<String, String>` فيه
/// حقول `hours` و`children` **فارغة دائماً** لأن الخادم لا يرسلها،
/// وصورة ثابتة `image7.png` لكل عنصر. كما كانت تترجم `completed`
/// إلى «قيد المراجعة» لأن `_statusLabel` لا تعرف هذه الحالة — فمشاركة
/// منتهية تظهر كأنها لم تُراجع بعد.
class MyVolunteerHistoryView extends StatefulWidget {
  const MyVolunteerHistoryView({super.key});

  @override
  State<MyVolunteerHistoryView> createState() => _MyVolunteerHistoryViewState();
}

class _MyVolunteerHistoryViewState extends State<MyVolunteerHistoryView> {
  _HistoryFilter _filter = _HistoryFilter.all;

  static final DateFormat _dateFormat = DateFormat('d MMMM y', 'ar');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.volunteerApplications.isEmpty && !provider.isLoading) {
        provider.fetchVolunteerApplications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final all = provider.volunteerApplications;
    final visible = _filter.apply(all);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التطوع'),
        leading: const BackButton(),
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildFilters(all),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.fetchVolunteerApplications,
                  child: KanafAsyncView(
                    isLoading: provider.isLoading,
                    isEmpty: visible.isEmpty,
                    errorMessage: all.isEmpty ? provider.errorMessage : null,
                    errorKind: provider.errorKind,
                    onRetry: provider.fetchVolunteerApplications,
                    emptyIcon: all.isEmpty
                        ? Icons.history_edu_outlined
                        : Icons.filter_alt_off_outlined,
                    emptyTitle: all.isEmpty
                        ? 'سجلّك فارغ حتى الآن'
                        : 'لا نتائج لهذا التصنيف',
                    emptyMessage: all.isEmpty
                        ? 'أول مشاركة تطوعية لك ستظهر هنا.'
                        : 'جرّب تصنيفاً آخر لعرض بقية المشاركات.',
                    builder: (context) => ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        KanafSpacing.pageInset,
                        0,
                        KanafSpacing.pageInset,
                        KanafSpacing.xxl,
                      ),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: KanafSpacing.md),
                      itemBuilder: (context, index) => KanafStaggeredEntrance(
                        index: index,
                        child: _HistoryCard(
                          data: visible[index],
                          dateFormat: _dateFormat,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(List<Map<String, dynamic>> all) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        KanafSpacing.pageInset,
        KanafSpacing.md,
        KanafSpacing.pageInset,
        KanafSpacing.md,
      ),
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
    );
  }
}

enum _HistoryFilter {
  all('الكل'),
  completed('مكتملة'),
  active('جارية'),
  pending('قيد المراجعة');

  const _HistoryFilter(this.label);

  final String label;

  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> items) {
    String statusOf(Map<String, dynamic> i) => i['status']?.toString() ?? '';

    return switch (this) {
      _HistoryFilter.all => items,
      _HistoryFilter.completed =>
        items.where((i) => statusOf(i) == 'completed').toList(),
      _HistoryFilter.active => items
          .where((i) =>
              statusOf(i) == 'accepted' || statusOf(i) == 'approved')
          .toList(),
      _HistoryFilter.pending =>
        items.where((i) => statusOf(i) == 'pending').toList(),
    };
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.data, required this.dateFormat});

  final Map<String, dynamic> data;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final title = data['opportunity_title']?.toString() ?? 'مشاركة تطوعية';
    final location = data['opportunity_location']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pending';
    final created = DateTime.tryParse(data['created_at']?.toString() ?? '');
    final start =
        DateTime.tryParse(data['opportunity_start_date']?.toString() ?? '');
    final rating = int.tryParse(data['rating']?.toString() ?? '') ?? 0;

    return KanafCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: KanafRadii.sm,
                ),
                child: Icon(
                  Icons.history_edu_outlined,
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
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall,
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: KanafSpacing.xxs),
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              KanafStatusChip(status: status, compact: true),
            ],
          ),
          const Divider(height: KanafSpacing.xxl),
          Row(
            children: [
              if (start != null) ...[
                Icon(
                  Icons.event_outlined,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: KanafSpacing.xs),
                Text(
                  dateFormat.format(start),
                  style: context.texts.labelSmall,
                ),
              ] else if (created != null) ...[
                Icon(
                  Icons.schedule_outlined,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: KanafSpacing.xs),
                Text(
                  'قُدّم في ${dateFormat.format(created)}',
                  style: context.texts.labelSmall,
                ),
              ],
              const Spacer(),
              if (rating > 0)
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: context.semantic.warning,
                    ),
                    const SizedBox(width: KanafSpacing.xxs),
                    Text('$rating/5', style: context.texts.labelSmall),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
