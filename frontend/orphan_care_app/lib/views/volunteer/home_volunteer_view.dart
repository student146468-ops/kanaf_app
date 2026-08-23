import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/volunteer_opportunity_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_nav_shell.dart';
import '../../widgets/kanaf_states.dart';

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
      provider.fetchNotifications(notifyLoading: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final all = provider.volunteerOpportunityModels;
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
                .where((notification) => notification['is_read'] != true)
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
                        : 'جرب تصنيفاً آخر لعرض بقية الفرص.',
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

  Widget _buildFilters(List<VolunteerOpportunityModel> all) {
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

  List<VolunteerOpportunityModel> apply(List<VolunteerOpportunityModel> items) {
    return switch (this) {
      _OpportunityFilter.all => items,
      _OpportunityFilter.open =>
        items.where((opportunity) => opportunity.status == 'open').toList(),
      _OpportunityFilter.closed =>
        items.where((opportunity) => opportunity.status != 'open').toList(),
    };
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.data, required this.dateFormat});

  final VolunteerOpportunityModel data;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final title = data.title.isEmpty ? 'فرصة تطوع' : data.title;
    final dateText =
        data.startDate == null ? null : dateFormat.format(data.startDate!);

    return KanafCard(
      onTap: () => Navigator.pushNamed(
        context,
        KanafRoutes.volunteerOpportunityDetails,
        arguments: data.toRouteArguments(),
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
                child: Icon(data.icon, size: 22, color: scheme.primary),
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
                    const SizedBox(height: KanafSpacing.xxs),
                    Text(data.categoryLabel, style: context.texts.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              KanafStatusChip(status: data.status, compact: true),
            ],
          ),
          if (data.description.isNotEmpty) ...[
            const SizedBox(height: KanafSpacing.md),
            Text(
              data.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall,
            ),
          ],
          const SizedBox(height: KanafSpacing.md),
          Wrap(
            spacing: KanafSpacing.xs,
            runSpacing: KanafSpacing.xs,
            children: [
              if ((data.careHomeName ?? '').isNotEmpty)
                _OpportunityMetaChip(
                  icon: Icons.home_work_outlined,
                  label: data.careHomeName!,
                ),
              if (data.location.isNotEmpty)
                _OpportunityMetaChip(
                  icon: Icons.location_on_outlined,
                  label: data.location,
                ),
              if (dateText != null)
                _OpportunityMetaChip(
                  icon: Icons.event_outlined,
                  label: dateText,
                ),
            ],
          ),
          if (data.skills.isNotEmpty) ...[
            const SizedBox(height: KanafSpacing.md),
            Wrap(
              spacing: KanafSpacing.xs,
              runSpacing: KanafSpacing.xs,
              children: [
                for (final skill in data.skills.take(3))
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(
                      Icons.workspace_premium_outlined,
                      size: 16,
                    ),
                    label: Text(skill),
                  ),
              ],
            ),
          ],
          if (data.requiredVolunteers > 0) ...[
            const Divider(height: KanafSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: KanafRadii.pill,
                    child: LinearProgressIndicator(
                      value: data.capacityRatio,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: KanafSpacing.md),
                Text(
                  data.isFull
                      ? 'مكتملة'
                      : '${data.currentVolunteers} من ${data.requiredVolunteers}',
                  style: context.texts.labelSmall?.copyWith(
                    color: data.isFull ? scheme.error : scheme.onSurfaceVariant,
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
}

class _OpportunityMetaChip extends StatelessWidget {
  const _OpportunityMetaChip({required this.icon, required this.label});

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
        color: scheme.surfaceContainerHighest.withOpacity(0.62),
        borderRadius: KanafRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: KanafSpacing.xxs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
