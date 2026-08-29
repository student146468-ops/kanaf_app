import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/kanaf_localizations.dart';
import '../../models/volunteer_opportunity_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

class VolunteerOpportunityDetailsView extends StatefulWidget {
  const VolunteerOpportunityDetailsView({super.key});

  @override
  State<VolunteerOpportunityDetailsView> createState() =>
      _VolunteerOpportunityDetailsViewState();
}

class _VolunteerOpportunityDetailsViewState
    extends State<VolunteerOpportunityDetailsView> {
  VolunteerOpportunityModel? _routeOpportunity;
  int? _requestedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeOpportunity = VolunteerOpportunityModel.fromJson(
      _readArguments(context),
    );
    _routeOpportunity = routeOpportunity.id == 0 ? null : routeOpportunity;
    final id = _routeOpportunity?.id;
    if (id != null && _requestedId != id) {
      _requestedId = id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppProviderScope.of(context).fetchVolunteerOpportunityDetails(id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final fetched = provider.selectedVolunteerOpportunity;
    final routeOpportunity = _routeOpportunity;
    final opportunity = fetched?.id == routeOpportunity?.id
        ? fetched!
        : routeOpportunity ?? fetched;
    final isEmpty = opportunity == null;

    if (isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('volunteer.detailsTitle')),
          leading: const BackButton(),
        ),
        body: KanafBackdrop(
          child: KanafAsyncView(
            isLoading: provider.isLoadingVolunteerOpportunityDetails,
            isEmpty: isEmpty,
            errorMessage: provider.volunteerOpportunityDetailsErrorMessage,
            errorKind: provider.volunteerOpportunityDetailsErrorKind,
            onRetry: _requestedId == null
                ? null
                : () =>
                    provider.fetchVolunteerOpportunityDetails(_requestedId!),
            emptyIcon: Icons.handshake_outlined,
            emptyTitle: context.tr('volunteer.defaultOpportunity'),
            emptyMessage: context.tr('volunteer.missingOpportunity'),
            builder: (_) => const SizedBox.shrink(),
          ),
        ),
      );
    }

    final title = opportunity.title.isEmpty
        ? context.tr('volunteer.defaultOpportunity')
        : opportunity.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('volunteer.detailsTitle')),
        leading: const BackButton(),
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    KanafSpacing.pageInset,
                    KanafSpacing.lg,
                    KanafSpacing.pageInset,
                    KanafSpacing.xxl,
                  ),
                  children: [
                    if (provider.isLoadingVolunteerOpportunityDetails)
                      const Padding(
                        padding: EdgeInsets.only(bottom: KanafSpacing.md),
                        child: KanafSkeleton(height: 4),
                      ),
                    if (provider.volunteerOpportunityDetailsErrorMessage !=
                        null) ...[
                      KanafFailureState(
                        message:
                            provider.volunteerOpportunityDetailsErrorMessage!,
                        kind: provider.volunteerOpportunityDetailsErrorKind,
                        onRetry: _requestedId == null
                            ? null
                            : () => provider.fetchVolunteerOpportunityDetails(
                                _requestedId!),
                      ),
                      const SizedBox(height: KanafSpacing.lg),
                    ],
                    if ((opportunity.imageUrl ?? '').isNotEmpty) ...[
                      KanafStaggeredEntrance(
                        index: 0,
                        child: _OpportunityImage(
                          imageUrl: opportunity.imageUrl!,
                        ),
                      ),
                      const SizedBox(height: KanafSpacing.lg),
                    ],
                    KanafStaggeredEntrance(
                      index: 1,
                      child: _HeaderCard(
                        opportunity: opportunity,
                        title: title,
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.lg),
                    KanafStaggeredEntrance(
                      index: 2,
                      child: _CapacityCard(opportunity: opportunity),
                    ),
                    const SizedBox(height: KanafSpacing.lg),
                    KanafStaggeredEntrance(
                      index: 3,
                      child: _DetailsCard(opportunity: opportunity),
                    ),
                    if (opportunity.skills.isNotEmpty) ...[
                      const SizedBox(height: KanafSpacing.lg),
                      KanafStaggeredEntrance(
                        index: 4,
                        child: _SkillsSection(skills: opportunity.skills),
                      ),
                    ],
                    if (opportunity.description.isNotEmpty) ...[
                      const SizedBox(height: KanafSpacing.lg),
                      KanafStaggeredEntrance(
                        index: 5,
                        child: _DescriptionSection(
                          description: opportunity.description,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              KanafActionBar(
                child: FilledButton.icon(
                  onPressed: opportunity.canApply
                      ? () => Navigator.pushNamed(
                            context,
                            KanafRoutes.applyOpportunity,
                            arguments: opportunity.toRouteArguments(),
                          )
                      : null,
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  label: Text(
                    switch ((
                      opportunity.myApplicationStatus,
                      opportunity.isOpen,
                      opportunity.isFull
                    )) {
                      (final applicationStatus?, _, _) =>
                        _applicationStatusLabel(context, applicationStatus),
                      (_, false, _) => context.tr('volunteer.filterClosed'),
                      (_, true, true) => context.tr('volunteer.capacityFull'),
                      _ => context.tr('volunteer.applyButton'),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _readArguments(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['opportunity'] is Map) {
      return Map<String, dynamic>.from(args['opportunity'] as Map);
    }
    if (args is Map) return Map<String, dynamic>.from(args);
    return const {};
  }
}

class _OpportunityImage extends StatelessWidget {
  const _OpportunityImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return ClipRRect(
      borderRadius: KanafRadii.lg,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.opportunity, required this.title});

  final VolunteerOpportunityModel opportunity;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return KanafCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.12),
              borderRadius: KanafRadii.md,
            ),
            child: Icon(opportunity.icon, size: 27, color: scheme.primary),
          ),
          const SizedBox(width: KanafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.texts.titleLarge),
                const SizedBox(height: KanafSpacing.sm),
                Wrap(
                  spacing: KanafSpacing.xs,
                  runSpacing: KanafSpacing.xs,
                  children: [
                    KanafStatusChip(status: opportunity.status),
                    if (opportunity.hasApplication)
                      KanafStatusChip(status: opportunity.myApplicationStatus!),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(opportunity.categoryLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _applicationStatusLabel(BuildContext context, String status) {
  return switch (status.trim().toLowerCase()) {
    'accepted' || 'approved' => context.tr('status.accepted'),
    'completed' => context.tr('status.completed'),
    'rejected' => context.tr('status.rejected'),
    'pending' => context.tr('status.pending'),
    _ => status,
  };
}

class _CapacityCard extends StatelessWidget {
  const _CapacityCard({required this.opportunity});

  final VolunteerOpportunityModel opportunity;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return KanafCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr('volunteer.volunteers'),
                style: context.texts.titleSmall,
              ),
              const Spacer(),
              Text(
                context.tr(
                  'volunteer.capacityCount',
                  args: {
                    'current': opportunity.currentVolunteers,
                    'required': opportunity.requiredVolunteers,
                  },
                ),
                style: context.texts.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: KanafSpacing.md),
          ClipRRect(
            borderRadius: KanafRadii.pill,
            child: LinearProgressIndicator(
              value: opportunity.capacityRatio,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: KanafSpacing.sm),
          Text(
            opportunity.effectiveRemainingSlots == 0
                ? context.tr('volunteer.capacityFull')
                : context.tr(
                    'volunteer.remainingSlots',
                    args: {'count': opportunity.effectiveRemainingSlots},
                  ),
            style: context.texts.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.opportunity});

  final VolunteerOpportunityModel opportunity;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat('d MMMM y', locale);
    final timeFormat = DateFormat('h:mm a', locale);
    final rows = <Widget>[
      if ((opportunity.careHomeName ?? '').isNotEmpty)
        KanafDetailRow(
          label: context.tr('volunteer.detailCareHome'),
          value: opportunity.careHomeName!,
        ),
      if (opportunity.location.isNotEmpty)
        KanafDetailRow(
          label: context.tr('volunteer.detailPlace'),
          value: opportunity.location,
        ),
      if ((opportunity.careHomeLocation ?? '').isNotEmpty)
        KanafDetailRow(
          label: context.tr('volunteer.detailAddress'),
          value: opportunity.careHomeLocation!,
        ),
      if (opportunity.startDate != null)
        KanafDetailRow(
          label: context.tr('volunteer.detailDate'),
          value: dateFormat.format(opportunity.startDate!),
        ),
      if (opportunity.startDate != null)
        KanafDetailRow(
          label: context.tr('volunteer.detailTime'),
          value: timeFormat.format(opportunity.startDate!),
        ),
      if (opportunity.endDate != null)
        KanafDetailRow(
          label: context.tr('volunteer.detailEnds'),
          value: dateFormat.format(opportunity.endDate!),
        ),
      KanafDetailRow(
        label: context.tr('volunteer.detailApplications'),
        value: opportunity.applicationsCount.toString(),
      ),
    ];

    return KanafCard(child: Column(children: rows));
  }
}

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({required this.skills});

  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KanafSectionHeader(title: context.tr('volunteer.skillsRequired')),
        const SizedBox(height: KanafSpacing.md),
        Wrap(
          spacing: KanafSpacing.sm,
          runSpacing: KanafSpacing.sm,
          children: [
            for (final skill in skills)
              Chip(
                avatar: const Icon(Icons.workspace_premium_outlined, size: 16),
                label: Text(skill),
              ),
          ],
        ),
      ],
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KanafSectionHeader(title: context.tr('volunteer.aboutOpportunity')),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(child: Text(description, style: context.texts.bodyMedium)),
      ],
    );
  }
}
