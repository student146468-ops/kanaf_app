import 'package:flutter/material.dart';

import '../../models/volunteer_opportunity_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_media_content_card.dart';
import '../../widgets/kanaf_states.dart';
import '../../l10n/kanaf_localizations.dart';

class SearchFilterView extends StatefulWidget {
  const SearchFilterView({super.key});

  @override
  State<SearchFilterView> createState() => _SearchFilterViewState();
}

class _SearchFilterViewState extends State<SearchFilterView> {
  final _searchController = TextEditingController();
  _OpportunityScope _scope = _OpportunityScope.open;
  String _category = _allCategory;
  String _query = '';

  static const String _allCategory = '__all__';

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final all = provider.volunteerOpportunityModels;
    final visible = _applyCategory(context, _applyQuery(_scope.apply(all)));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('volunteer.searchTitle')),
        leading: const BackButton(),
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildSearchField(),
              _buildScopes(all),
              _buildCategories(all),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.fetchVolunteerOpportunities,
                  child: KanafAsyncView(
                    isLoading: provider.isLoading,
                    isEmpty: visible.isEmpty,
                    errorMessage: all.isEmpty ? provider.errorMessage : null,
                    errorKind: provider.errorKind,
                    onRetry: provider.fetchVolunteerOpportunities,
                    emptyIcon: _query.isEmpty
                        ? Icons.handshake_outlined
                        : Icons.search_off_rounded,
                    emptyTitle: _query.isEmpty
                        ? context.tr('volunteer.noCategoryOpportunities')
                        : context.tr(
                            'volunteer.noSearchResults',
                            args: {'query': _query},
                          ),
                    emptyMessage: _query.isEmpty
                        ? context.tr('volunteer.searchEmptyMessage')
                        : context.tr('volunteer.searchNoResultsMessage'),
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

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KanafSpacing.pageInset,
        KanafSpacing.lg,
        KanafSpacing.pageInset,
        0,
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _query = value.trim()),
        decoration: InputDecoration(
          hintText: context.tr('volunteer.searchHint'),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: context.tr('common.clear'),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildScopes(List<VolunteerOpportunityModel> all) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        KanafSpacing.pageInset,
        KanafSpacing.md,
        KanafSpacing.pageInset,
        KanafSpacing.sm,
      ),
      child: Row(
        children: [
          for (final option in _OpportunityScope.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: KanafSpacing.sm),
              child: FilterChip(
                label: Text(
                  '${context.tr(option.labelKey)} (${option.apply(all).length})',
                ),
                selected: _scope == option,
                onSelected: (_) => setState(() => _scope = option),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategories(List<VolunteerOpportunityModel> all) {
    final categories = <String>{
      _allCategory,
      ...all.map((item) => item.categoryLabelFor(context)),
    }.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        KanafSpacing.pageInset,
        0,
        KanafSpacing.pageInset,
        KanafSpacing.md,
      ),
      child: Row(
        children: [
          for (final category in categories)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: KanafSpacing.sm),
              child: ChoiceChip(
                label: Text(
                  category == _allCategory
                      ? context.tr('common.all')
                      : category,
                ),
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
              ),
            ),
        ],
      ),
    );
  }

  List<VolunteerOpportunityModel> _applyQuery(
    List<VolunteerOpportunityModel> items,
  ) {
    if (_query.isEmpty) return items;
    final needle = _query.toLowerCase();
    return items.where((item) {
      return item.title.toLowerCase().contains(needle) ||
          item.description.toLowerCase().contains(needle) ||
          item.location.toLowerCase().contains(needle) ||
          item.requiredSkills.toLowerCase().contains(needle) ||
          (item.careHomeName ?? '').toLowerCase().contains(needle);
    }).toList();
  }

  List<VolunteerOpportunityModel> _applyCategory(
    BuildContext context,
    List<VolunteerOpportunityModel> items,
  ) {
    if (_category == _allCategory) return items;
    return items
        .where((item) => item.categoryLabelFor(context) == _category)
        .toList();
  }
}

enum _OpportunityScope {
  open('volunteer.filterAvailable'),
  all('common.all'),
  closed('volunteer.filterClosed');

  const _OpportunityScope(this.labelKey);

  final String labelKey;

  List<VolunteerOpportunityModel> apply(List<VolunteerOpportunityModel> items) {
    return switch (this) {
      _OpportunityScope.all => items,
      _OpportunityScope.open =>
        items.where((opportunity) => opportunity.status == 'open').toList(),
      _OpportunityScope.closed =>
        items.where((opportunity) => opportunity.status != 'open').toList(),
    };
  }
}
