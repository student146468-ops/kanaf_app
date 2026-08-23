import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/need_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

/// تفاصيل الاحتياج كما يراها المتبرع.
///
/// أُصلحت فيها ثلاثة عيوب:
///
/// 1. كانت تعرض ما وصلها في `needData` فقط ولا تسأل الخادم إطلاقاً،
///    فتبقى الأرقام على ما كانت عليه لحظة بناء البطاقة في الشاشة
///    السابقة مهما تغيّر الاحتياج فعلياً. صارت تجلب السجل بمعرّفه.
/// 2. كانت **تخترع نصوصاً** عند غياب البيانات: وصف جاهز، ومدينة
///    «غريان» ثابتة، وقسم «الأثر المتوقع» مكتوب في الكود بحسب
///    التصنيف. كلها تظهر للمتبرع كأنها معلومات عن هذه الدار.
/// 3. كان فيها زر «مفضلة» لا يحفظ شيئاً — لا حقل له في الخادم.
class NeedDetailsScreen extends StatefulWidget {
  const NeedDetailsScreen({super.key, required this.needData});

  final Map<String, dynamic> needData;

  @override
  State<NeedDetailsScreen> createState() => _NeedDetailsScreenState();
}

class _NeedDetailsScreenState extends State<NeedDetailsScreen> {
  int? _needId;

  static final DateFormat _dateFormat = DateFormat('d MMMM y', 'ar');

  @override
  void initState() {
    super.initState();
    final id = int.tryParse(widget.needData['id']?.toString() ?? '');
    _needId = id;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppProviderScope.of(context).fetchNeedDetails(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final need = provider.selectedNeed;
    final isReady = need != null && need.id == _needId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الاحتياج'),
        leading: const BackButton(),
        actions: [
          if (isReady)
            IconButton(
              tooltip: 'تتبّع الحالة',
              onPressed: () => Navigator.pushNamed(
                context,
                KanafRoutes.trackNeedStatus,
                arguments: need.id,
              ),
              icon: const Icon(Icons.timeline_rounded),
            ),
          const SizedBox(width: KanafSpacing.xs),
        ],
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: KanafAsyncView(
            isLoading: provider.isLoading && !isReady,
            isEmpty: !isReady,
            errorMessage: provider.errorMessage,
            errorKind: provider.errorKind,
            onRetry: _needId == null
                ? null
                : () => provider.fetchNeedDetails(_needId!),
            emptyIcon: Icons.search_off_rounded,
            emptyTitle: 'تعذر العثور على الاحتياج',
            emptyMessage: 'قد يكون اكتمل أو أُرشف من قِبل الدار.',
            builder: (context) => Column(
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
                        child: _HeaderCard(need: need!),
                      ),
                      const SizedBox(height: KanafSpacing.lg),
                      KanafStaggeredEntrance(
                        index: 1,
                        child: _ProgressCard(need: need),
                      ),
                      if (need.description.trim().isNotEmpty) ...[
                        const SizedBox(height: KanafSpacing.xxl),
                        KanafStaggeredEntrance(
                          index: 2,
                          child: _DescriptionSection(text: need.description),
                        ),
                      ],
                      const SizedBox(height: KanafSpacing.xxl),
                      KanafStaggeredEntrance(
                        index: 3,
                        child: _FactsSection(
                          need: need,
                          dateFormat: _dateFormat,
                        ),
                      ),
                    ],
                  ),
                ),
                KanafActionBar(
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: need.status == 'open'
                              ? () => Navigator.pushNamed(
                                    context,
                                    KanafRoutes.financialDonation,
                                    arguments: {'need_id': need.id},
                                  )
                              : null,
                          icon: const Icon(Icons.payments_outlined),
                          label: Text(
                            need.status == 'open' ? 'تبرّع الآن' : 'اكتمل',
                          ),
                        ),
                      ),
                      if (need.status == 'open') ...[
                        const SizedBox(width: KanafSpacing.md),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              KanafRoutes.inkindDonation,
                              arguments: {'need_id': need.id},
                            ),
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('تبرّع عيني'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.need});

  final NeedModel need;

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
            child: Icon(need.icon, size: 27, color: scheme.primary),
          ),
          const SizedBox(width: KanafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(need.title, style: context.texts.titleLarge),
                const SizedBox(height: KanafSpacing.xs),
                Text(need.categoryLabel, style: context.texts.bodySmall),
                const SizedBox(height: KanafSpacing.sm),
                Wrap(
                  spacing: KanafSpacing.xs,
                  runSpacing: KanafSpacing.xs,
                  children: [
                    KanafStatusChip(status: need.status),
                    if (need.priority == 'urgent')
                      const KanafStatusChip(status: 'urgent'),
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.need});

  final NeedModel need;

  @override
  Widget build(BuildContext context) {
    final progress = need.progress;

    return KanafCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ما تحقّق', style: context.texts.titleSmall),
              const Spacer(),
              if (progress != null)
                Text(
                  '${(progress * 100).round()}%',
                  style: context.texts.titleSmall?.copyWith(
                    color: context.colors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: KanafSpacing.md),
          if (progress != null) ...[
            ClipRRect(
              borderRadius: KanafRadii.pill,
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: KanafSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'المطلوب',
                  value: need.requiredQuantity.isEmpty
                      ? 'غير محدد'
                      : need.requiredQuantity,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'المحقَّق',
                  value: _number(need.fulfilledQuantity),
                ),
              ),
              if (need.remainingQuantity != null)
                Expanded(
                  child: _Figure(
                    label: 'المتبقي',
                    value: _number(need.remainingQuantity!),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _number(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(2);
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.texts.labelSmall),
        const SizedBox(height: KanafSpacing.xxs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.texts.titleSmall,
        ),
      ],
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KanafSectionHeader(title: 'عن الاحتياج'),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(child: Text(text, style: context.texts.bodyMedium)),
      ],
    );
  }
}

class _FactsSection extends StatelessWidget {
  const _FactsSection({required this.need, required this.dateFormat});

  final NeedModel need;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if ((need.careHomeName ?? '').isNotEmpty)
        KanafDetailRow(label: 'دار الرعاية', value: need.careHomeName!),
      if ((need.careHomeLocation ?? '').isNotEmpty)
        KanafDetailRow(label: 'الموقع', value: need.careHomeLocation!),
      KanafDetailRow(label: 'الأولوية', value: need.priorityLabel),
      KanafDetailRow(label: 'التصنيف', value: need.categoryLabel),
      if (need.needType.isNotEmpty)
        KanafDetailRow(label: 'النوع', value: need.needType),
      if (need.deadline != null)
        KanafDetailRow(
          label: 'آخر موعد',
          value: dateFormat.format(need.deadline!),
        ),
      if (need.createdAt != null)
        KanafDetailRow(
          label: 'نُشر في',
          value: dateFormat.format(need.createdAt!),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KanafSectionHeader(title: 'تفاصيل'),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(child: Column(children: rows)),
      ],
    );
  }
}
