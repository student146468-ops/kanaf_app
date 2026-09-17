import 'package:flutter/material.dart';

import '../../models/volunteer_opportunity_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_media_content_card.dart';
import '../../widgets/kanaf_nav_shell.dart';
import '../../widgets/kanaf_states.dart';
import '../../l10n/kanaf_localizations.dart';

class HomeVolunteerView extends StatefulWidget {
  const HomeVolunteerView({super.key});

  @override
  State<HomeVolunteerView> createState() => _HomeVolunteerViewState();
}

class _HomeVolunteerViewState extends State<HomeVolunteerView> {
  _OpportunityFilter _filter = _OpportunityFilter.open;

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
        title: Text(context.tr('volunteer.homeTitle')),
        centerTitle: false,
        actions: [
          const KanafRoleSwitchButton(currentRole: 'volunteer'),
          IconButton(
            tooltip: context.tr('home.searchTooltip'),
            onPressed: () =>
                Navigator.pushNamed(context, KanafRoutes.volunteerSearch),
            icon: const Icon(Icons.search_rounded),
          ),
          KanafNotificationButton(
            unreadCount: provider.unreadNotificationsCount,
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
                        ? context.tr('volunteer.emptyOpportunitiesTitle')
                        : context.tr('volunteer.emptyCategoryTitle'),
                    emptyMessage: all.isEmpty
                        ? context.tr('volunteer.emptyOpportunitiesMessage')
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
                        child: KanafMediaContentCard.opportunity(
                          context: context,
                          opportunity: visible[index],
                          onTap: () => Navigator.pushNamed(
                            context,
                            KanafRoutes.volunteerOpportunityDetails,
                            arguments: visible[index].toRouteArguments(),
                          ),
                          onApply: visible[index].canApply
                              ? () => Navigator.pushNamed(
                                    context,
                                    KanafRoutes.applyOpportunity,
                                    arguments:
                                        visible[index].toRouteArguments(),
                                  )
                              : null,
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

enum _OpportunityFilter {
  open('volunteer.filterAvailable'),
  all('common.all'),
  closed('volunteer.filterClosed');

  const _OpportunityFilter(this.labelKey);

  final String labelKey;

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
