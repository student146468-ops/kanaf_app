import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_nav_shell.dart';
import '../../widgets/kanaf_states.dart';

/// رئيسية المتطوع — فرص التطوع المتاحة.
///
/// أُعيد بناؤها على Material 3 مع `NavigationBar`. البطاقة تعرض الآن
/// **مدى امتلاء الفرصة** (`current_volunteers` من `required_volunteers`)
/// وهي بيانات يرسلها الخادم ولم تكن الواجهة تعرضها إطلاقاً — فلم يكن
/// المتطوع يعرف إن كانت الفرصة على وشك الاكتمال قبل أن يتقدّم لها.
class HomeVolunteerView extends StatefulWidget {
  const HomeVolunteerView({super.key});

  @override
  State<HomeVolunteerView> createState() => _HomeVolunteerViewState();
}

class _HomeVolunteerViewState extends State<HomeVolunteerView> {
  _OpportunityFilter _filter = _OpportunityFilter.open;

  static final DateFormat _dateFormat = DateFormat('d MMM y', 'ar');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.volunteerOpportunities.isEmpty && !provider.isLoading) {
        provider.fetchVolunteerOpportunities();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final all = provider.volunteerOpportunities;
    final visible = _filter.apply(all);

    return Scaffold(
      appBar: AppBar(
        title: const Text('فرص التطوع'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'بحث وتصفية',
            onPressed: () =>
                Navigator.pushNamed(context, KanafRoutes.volunteerSearch),
            icon: const Icon(Icons.search_rounded),
          ),
          KanafNotificationButton(
            unreadCount: provider.notifications
                .where((n) => n['is_read'] != true)
                .length,
            route: KanafRoutes.volunteerNotifications,
          ),
          const SizedBox(width: KanafSpacing.xs),
        ],
      ),
      bottomNavigationBar: const KanafNavBar(
        destinations: KanafNavDestinations.volunteer,
        currentIndex: 0,
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildFilters(all),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.fetchVolunteerOpportunities,
                  child: KanafAsyncView(
                    isLoading: provider.isLoading,
                    isEmpty: visible.isEmpty,
                    errorMessage: all.isEmpty ? provider.errorMessage : null,
                    errorKind: provider.errorKind,
                    onRetry: provider.fetchVolunteerOpportunities,
                    emptyIcon: all.isEmpty
                        ? Icons.handshake_outlined
                        : Icons.filter_alt_off_outlined,
                    emptyTitle: all.isEmpty
                        ? 'لا توجد فرص تطوع حالياً'
                        : 'لا نتائج لهذا التصنيف',
                    emptyMessage: all.isEmpty
                        ? 'ستظهر هنا الفرص فور نشرها من دور الرعاية.'
                        : 'جرّب تصنيفاً آخر لعرض بقية الفرص.',
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
                        child: _OpportunityCard(
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
          for (final option in _OpportunityFilter.values)
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

enum _OpportunityFilter {
  open('متاحة'),
  all('الكل'),
  closed('مغلقة');

  const _OpportunityFilter(this.label);

  final String label;

  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> items) {
    return switch (this) {
      _OpportunityFilter.all => items,
      _OpportunityFilter.open =>
        items.where((o) => o['status'] == 'open').toList(),
      _OpportunityFilter.closed =>
        items.where((o) => o['status'] != 'open').toList(),
    };
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.data, required this.dateFormat});

  final Map<String, dynamic> data;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final title = data['title']?.toString() ?? 'فرصة تطوع';
    final description = data['description']?.toString() ?? '';
    final location = data['location']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'open';
    final required = _intOf(data['required_volunteers']) ?? 0;
    final current = _intOf(data['current_volunteers']) ?? 0;
    final startDate = DateTime.tryParse(data['start_date']?.toString() ?? '');
    final isFull = required > 0 && current >= required;

    return KanafCard(
      onTap: () => Navigator.pushNamed(
        context,
        KanafRoutes.volunteerOpportunityDetails,
        arguments: data,
      ),
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
                  Icons.handshake_outlined,
                  size: 22,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: KanafSpacing.md),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall,
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              KanafStatusChip(status: status, compact: true),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: KanafSpacing.md),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall,
            ),
          ],
          const SizedBox(height: KanafSpacing.md),
          Row(
            children: [
              if (location.isNotEmpty) ...[
                Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: KanafSpacing.xs),
                Flexible(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall,
                  ),
                ),
                const SizedBox(width: KanafSpacing.md),
              ],
              if (startDate != null) ...[
                Icon(
                  Icons.event_outlined,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: KanafSpacing.xs),
                Text(
                  dateFormat.format(startDate),
                  style: context.texts.labelSmall,
                ),
              ],
            ],
          ),
          if (required > 0) ...[
            const Divider(height: KanafSpacing.xxl),
            // مدى الامتلاء: بيانات يرسلها الخادم ولم تكن تُعرض إطلاقاً.
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: KanafRadii.pill,
                    child: LinearProgressIndicator(
                      value: (current / required).clamp(0.0, 1.0),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: KanafSpacing.md),
                Text(
                  isFull ? 'مكتملة' : '$current من $required',
                  style: context.texts.labelSmall?.copyWith(
                    color: isFull ? scheme.error : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static int? _intOf(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
