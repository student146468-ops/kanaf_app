import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

/// تفاصيل فرصة التطوع.
///
/// أُعيد بناؤها لتقرأ حقول `VolunteerOpportunity` الفعلية من الخادم.
/// النسخة السابقة كانت تتوقع مفاتيح لا يرسلها الخادم إطلاقاً
/// (`organization`, `city`, `skill`, `seats`, `tasks`, `skillsList`)
/// وتبدأ بقالب فيه سلاسل فارغة — فكانت الشاشة تعرض حقولاً خاوية.
///
/// كما يُعطَّل زر التقديم عندما تكون الفرصة مغلقة أو مكتملة العدد،
/// بدل السماح بطلب مرفوض سلفاً من الخادم.
class VolunteerOpportunityDetailsView extends StatelessWidget {
  const VolunteerOpportunityDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final opportunity = _readArguments(context);

    final title = opportunity['title']?.toString() ?? 'فرصة تطوع';
    final description = opportunity['description']?.toString() ?? '';
    final location = opportunity['location']?.toString() ?? '';
    final status = opportunity['status']?.toString() ?? 'open';
    final required = _intOf(opportunity['required_volunteers']) ?? 0;
    final current = _intOf(opportunity['current_volunteers']) ?? 0;
    final start = DateTime.tryParse(opportunity['start_date']?.toString() ?? '');
    final end = DateTime.tryParse(opportunity['end_date']?.toString() ?? '');

    final isOpen = status == 'open';
    final isFull = required > 0 && current >= required;
    final canApply = isOpen && !isFull;

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
                      child: _buildHeader(context, title, status),
                    ),
                    const SizedBox(height: KanafSpacing.lg),
                    if (required > 0)
                      KanafStaggeredEntrance(
                        index: 1,
                        child: _buildCapacity(context, current, required),
                      ),
                    const SizedBox(height: KanafSpacing.lg),
                    KanafStaggeredEntrance(
                      index: 2,
                      child: _buildDetails(context, location, start, end),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: KanafSpacing.lg),
                      KanafStaggeredEntrance(
                        index: 3,
                        child: _buildDescription(context, description),
                      ),
                    ],
                  ],
                ),
              ),
              KanafActionBar(
                child: FilledButton.icon(
                  onPressed: canApply
                      ? () => Navigator.pushNamed(
                            context,
                            KanafRoutes.applyOpportunity,
                            arguments: opportunity,
                          )
                      : null,
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  label: Text(
                    switch ((isOpen, isFull)) {
                      (false, _) => 'الفرصة مغلقة',
                      (true, true) => 'اكتمل العدد',
                      _ => 'تطوّع الآن',
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

  Widget _buildHeader(BuildContext context, String title, String status) {
    final scheme = context.colors;
    return KanafCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: KanafRadii.md,
            ),
            child: Icon(
              Icons.handshake_outlined,
              size: 27,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: KanafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.texts.titleLarge),
                const SizedBox(height: KanafSpacing.sm),
                KanafStatusChip(status: status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacity(BuildContext context, int current, int required) {
    final scheme = context.colors;
    final ratio = (current / required).clamp(0.0, 1.0);
    final remaining = (required - current).clamp(0, required);

    return KanafCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('المتطوعون', style: context.texts.titleSmall),
              const Spacer(),
              Text(
                '$current من $required',
                style: context.texts.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: KanafSpacing.md),
          ClipRRect(
            borderRadius: KanafRadii.pill,
            child: LinearProgressIndicator(value: ratio, minHeight: 8),
          ),
          const SizedBox(height: KanafSpacing.sm),
          Text(
            remaining == 0
                ? 'اكتمل العدد المطلوب'
                : 'متبقٍ $remaining ${remaining == 1 ? "مقعد" : "مقاعد"}',
            style: context.texts.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(
    BuildContext context,
    String location,
    DateTime? start,
    DateTime? end,
  ) {
    final dateFormat = DateFormat('d MMMM y', 'ar');
    final timeFormat = DateFormat('h:mm a', 'ar');

    return KanafCard(
      child: Column(
        children: [
          if (location.isNotEmpty)
            KanafDetailRow(label: 'المكان', value: location),
          if (start != null) ...[
            KanafDetailRow(label: 'يبدأ', value: dateFormat.format(start)),
            KanafDetailRow(label: 'الوقت', value: timeFormat.format(start)),
          ],
          if (end != null)
            KanafDetailRow(label: 'ينتهي', value: dateFormat.format(end)),
          if (location.isEmpty && start == null && end == null)
            Text(
              'لم تُحدَّد تفاصيل الزمان والمكان بعد.',
              style: context.texts.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KanafSectionHeader(title: 'عن الفرصة'),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(
          child: Text(description, style: context.texts.bodyMedium),
        ),
      ],
    );
  }

  /// يقبل الفرصة مباشرة أو داخل مفتاح `opportunity`.
  Map<String, dynamic> _readArguments(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['opportunity'] is Map) {
      return Map<String, dynamic>.from(args['opportunity'] as Map);
    }
    if (args is Map) return Map<String, dynamic>.from(args);
    return const {};
  }

  static int? _intOf(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
