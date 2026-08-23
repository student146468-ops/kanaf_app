import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/volunteer_opportunity_model.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

class VolunteerOpportunityDetailsView extends StatelessWidget {
  const VolunteerOpportunityDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final opportunity = VolunteerOpportunityModel.fromJson(
      _readArguments(context),
    );
    final title = opportunity.title.isEmpty ? 'فرصة تطوع' : opportunity.title;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الفرصة'),
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
                    KanafStaggeredEntrance(
                      index: 0,
                      child: _HeaderCard(
                        opportunity: opportunity,
                        title: title,
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.lg),
                    KanafStaggeredEntrance(
                      index: 1,
                      child: _CapacityCard(opportunity: opportunity),
                    ),
                    const SizedBox(height: KanafSpacing.lg),
                    KanafStaggeredEntrance(
                      index: 2,
                      child: _DetailsCard(opportunity: opportunity),
                    ),
                    if (opportunity.skills.isNotEmpty) ...[
                      const SizedBox(height: KanafSpacing.lg),
                      KanafStaggeredEntrance(
                        index: 3,
                        child: _SkillsSection(skills: opportunity.skills),
                      ),
                    ],
                    if (opportunity.description.isNotEmpty) ...[
                      const SizedBox(height: KanafSpacing.lg),
                      KanafStaggeredEntrance(
                        index: 4,
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
                    switch ((opportunity.isOpen, opportunity.isFull)) {
                      (false, _) => 'الفرصة مغلقة',
                      (true, true) => 'اكتمل العدد',
                      _ => 'تطوع الآن',
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
              Text('المتطوعون', style: context.texts.titleSmall),
              const Spacer(),
              Text(
                '${opportunity.currentVolunteers} من ${opportunity.requiredVolunteers}',
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
                ? 'اكتمل العدد المطلوب'
                : 'متبقي ${opportunity.effectiveRemainingSlots} مقاعد',
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
    final dateFormat = DateFormat('d MMMM y', 'ar');
    final timeFormat = DateFormat('h:mm a', 'ar');
    final rows = <Widget>[
      if ((opportunity.careHomeName ?? '').isNotEmpty)
        KanafDetailRow(label: 'دار الرعاية', value: opportunity.careHomeName!),
      if (opportunity.location.isNotEmpty)
        KanafDetailRow(label: 'المكان', value: opportunity.location),
      if ((opportunity.careHomeLocation ?? '').isNotEmpty)
        KanafDetailRow(
          label: 'عنوان الدار',
          value: opportunity.careHomeLocation!,
        ),
      if (opportunity.startDate != null)
        KanafDetailRow(
          label: 'التاريخ',
          value: dateFormat.format(opportunity.startDate!),
        ),
      if (opportunity.startDate != null)
        KanafDetailRow(
          label: 'الوقت',
          value: timeFormat.format(opportunity.startDate!),
        ),
      if (opportunity.endDate != null)
        KanafDetailRow(
          label: 'ينتهي',
          value: dateFormat.format(opportunity.endDate!),
        ),
      KanafDetailRow(
        label: 'عدد الطلبات',
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
        const KanafSectionHeader(title: 'المهارات المطلوبة'),
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
        const KanafSectionHeader(title: 'عن الفرصة'),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(child: Text(description, style: context.texts.bodyMedium)),
      ],
    );
  }
}
