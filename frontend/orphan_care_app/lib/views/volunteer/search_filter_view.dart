import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/volunteer_opportunity_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../services/api_config.dart';
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.data, required this.dateFormat});

  final VolunteerOpportunityModel data;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
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
          if ((data.imageUrl ?? '').trim().isNotEmpty) ...[
            _OpportunityImage(imageUrl: data.imageUrl!.trim()),
            const SizedBox(height: KanafSpacing.md),
          ],
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
                      data.title.isEmpty
                          ? context.tr('volunteer.defaultOpportunity')
                          : data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall,
                    ),
                    const SizedBox(height: KanafSpacing.xxs),
                    Text(
                      data.categoryLabelFor(context),
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              KanafStatusChip(
                status: data.myApplicationStatus ?? data.status,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: KanafSpacing.md),
          Wrap(
            spacing: KanafSpacing.xs,
            runSpacing: KanafSpacing.xs,
            children: [
              if (data.location.isNotEmpty)
                _MetaChip(
                  icon: Icons.location_on_outlined,
                  label: data.location,
                ),
              if (dateText != null)
                _MetaChip(icon: Icons.event_outlined, label: dateText),
              if ((data.careHomeName ?? '').isNotEmpty)
                _MetaChip(
                  icon: Icons.home_work_outlined,
                  label: data.careHomeName!,
                ),
              _MetaChip(
                icon: Icons.groups_outlined,
                label: data.effectiveRemainingSlots == 0
                    ? context.tr('volunteer.capacityFull')
                    : context.tr(
                        'volunteer.remainingSlots',
                        args: {'count': data.effectiveRemainingSlots},
                      ),
              ),
            ],
          ),
          if (data.requiredVolunteers > 0) ...[
            const SizedBox(height: KanafSpacing.md),
            ClipRRect(
              borderRadius: KanafRadii.pill,
              child: LinearProgressIndicator(
                value: data.capacityRatio,
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpportunityImage extends StatelessWidget {
  const _OpportunityImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final resolvedUrl = ApiConfig.buildImageUrl(imageUrl);
    if (resolvedUrl == null) {
      return _OpportunityImageFallback(scheme: scheme);
    }
    return ClipRRect(
      borderRadius: KanafRadii.md,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          resolvedUrl,
          headers: ApiConfig.imageRequestHeaders,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            ApiConfig.logImageLoadError(
              source: imageUrl,
              resolved: resolvedUrl,
              error: error,
            );
            return _OpportunityImageFallback(scheme: scheme);
          },
        ),
      ),
    );
  }
}

class _OpportunityImageFallback extends StatelessWidget {
  const _OpportunityImageFallback({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

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
            constraints: const BoxConstraints(maxWidth: 180),
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
