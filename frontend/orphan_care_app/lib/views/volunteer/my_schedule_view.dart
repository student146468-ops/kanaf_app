import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider_scope.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_nav_shell.dart';
import '../../widgets/kanaf_states.dart';
import '../../l10n/kanaf_localizations.dart';

/// جدول المتطوع — طلباته وحالتها.
///
/// النسخة السابقة كانت تعرض شريط أيام **بتواريخ ثابتة مكتوبة يدوياً**
/// (٣٠ / ٠١ / ٠٢ …) لا علاقة لها بالتقويم الحقيقي ولا ببيانات الطلبات،
/// فالاختيار بينها لم يكن يغيّر شيئاً. استُبدل بتصنيف حسب حالة الطلب،
/// وهي المعلومة التي يحتاجها المتطوع فعلاً.
class MyScheduleView extends StatefulWidget {
  const MyScheduleView({super.key});

  @override
  State<MyScheduleView> createState() => _MyScheduleViewState();
}

class _MyScheduleViewState extends State<MyScheduleView> {
  _ScheduleFilter _filter = _ScheduleFilter.upcoming;

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
    final dateFormat = DateFormat(
      'd MMMM y',
      Localizations.localeOf(context).languageCode,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('common.mySchedule'))),
      bottomNavigationBar: const KanafNavBar(
        destinations: KanafNavDestinations.volunteer,
        currentIndex: 1,
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
                        ? Icons.event_available_outlined
                        : Icons.filter_alt_off_outlined,
                    emptyTitle: all.isEmpty
                        ? context.tr('volunteer.noApplicationsTitle')
                        : context.tr('volunteer.emptyCategoryTitle'),
                    emptyMessage: all.isEmpty
                        ? context.tr('volunteer.noApplicationsMessage')
                        : context.tr('volunteer.emptyCategoryMessage'),
                    builder: (context) => ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        KanafSpacing.pageInset,
                        0,
                        KanafSpacing.pageInset,
                        KanafSpacing.bottomSafeGutter,
                      ),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: KanafSpacing.md),
                      itemBuilder: (context, index) => KanafStaggeredEntrance(
                        index: index,
                        child: _ApplicationCard(
                          data: visible[index],
                          dateFormat: dateFormat,
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
          for (final option in _ScheduleFilter.values)
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
    );
  }
}

enum _ScheduleFilter {
  upcoming('volunteer.filterUpcoming'),
  pending('donation.pending'),
  completed('donation.completed'),
  all('common.all');

  const _ScheduleFilter(this.labelKey);

  final String labelKey;

  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> items) {
    String statusOf(Map<String, dynamic> item) =>
        item['status']?.toString() ?? '';

    return switch (this) {
      _ScheduleFilter.all => items,
      _ScheduleFilter.pending =>
        items.where((i) => statusOf(i) == 'pending').toList(),
      _ScheduleFilter.completed =>
        items.where((i) => statusOf(i) == 'completed').toList(),
      // «القادمة» = المقبولة التي لم تكتمل بعد.
      _ScheduleFilter.upcoming => items
          .where((i) => statusOf(i) == 'accepted' || statusOf(i) == 'approved')
          .toList(),
    };
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.data, required this.dateFormat});

  final Map<String, dynamic> data;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final status = data['status']?.toString() ?? 'pending';
    final message = data['message']?.toString() ?? '';
    final created = DateTime.tryParse(data['created_at']?.toString() ?? '');

    // عنوان الفرصة يصل إما مسطّحاً أو داخل كائن `opportunity`.
    final opportunity = data['opportunity'];
    final title = data['opportunity_title']?.toString() ??
        (opportunity is Map ? opportunity['title']?.toString() : null) ??
        context.tr('volunteer.defaultOpportunity');
    final location =
        opportunity is Map ? opportunity['location']?.toString() ?? '' : '';

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
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: KanafRadii.sm,
                ),
                child: Icon(
                  Icons.event_note_outlined,
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
          if (message.isNotEmpty) ...[
            const Divider(height: KanafSpacing.xxl),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall,
            ),
          ],
          if (created != null) ...[
            const SizedBox(height: KanafSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: KanafSpacing.xs),
                Text(
                  context.tr(
                    'volunteer.submittedAt',
                    args: {'date': dateFormat.format(created)},
                  ),
                  style: context.texts.labelSmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
