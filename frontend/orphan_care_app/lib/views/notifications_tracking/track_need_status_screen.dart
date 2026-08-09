import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/need_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

/// تتبّع حالة الاحتياج.
///
/// كانت هذه الشاشة **مختلقة بالكامل**: خمس مراحل مكتوبة في الكود
/// («شراء وتجهيز المواد»، «الفرز والتغليف»، «الشحن والتوصيل») بتواريخ
/// ثابتة في يونيو ٢٠٢٦، تُعرض على أي احتياج مهما كان. لا يوجد في
/// الخادم نموذج مراحل ولا شحن ولا تغليف.
///
/// أُعيد بناؤها على دورة الحياة التي يعرفها الخادم فعلاً: نشر
/// الاحتياج، ما تحقّق منه، آخر تحديث، ثم اكتماله أو أرشفته.
class TrackNeedStatusScreen extends StatefulWidget {
  const TrackNeedStatusScreen({super.key});

  @override
  State<TrackNeedStatusScreen> createState() => _TrackNeedStatusScreenState();
}

class _TrackNeedStatusScreenState extends State<TrackNeedStatusScreen> {
  int? _needId;

  static final DateFormat _dateFormat = DateFormat('d MMMM y • h:mm a', 'ar');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = _readNeedId();
    if (id == null || id == _needId) return;
    _needId = id;
    final provider = AppProviderScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) provider.fetchNeedDetails(id);
    });
  }

  int? _readNeedId() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) return args;
    if (args is Map) return int.tryParse(args['id']?.toString() ?? '');
    return int.tryParse(args?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final need = provider.selectedNeed;
    final isReady = need != null && need.id == _needId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبّع الاحتياج'),
        leading: const BackButton(),
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
            emptyIcon: Icons.timeline_rounded,
            emptyTitle: 'لم يُحدَّد الاحتياج',
            emptyMessage: 'افتح الاحتياج من قائمة الاحتياجات لتتبّع حالته.',
            builder: (context) => ListView(
              padding: const EdgeInsets.fromLTRB(
                KanafSpacing.pageInset,
                KanafSpacing.lg,
                KanafSpacing.pageInset,
                KanafSpacing.xxl,
              ),
              children: [
                KanafStaggeredEntrance(
                  index: 0,
                  child: _SummaryCard(need: need!),
                ),
                const SizedBox(height: KanafSpacing.xxl),
                const KanafStaggeredEntrance(
                  index: 1,
                  child: KanafSectionHeader(
                    title: 'مسار الاحتياج',
                    subtitle: 'المراحل التي سجّلها النظام فعلياً',
                  ),
                ),
                const SizedBox(height: KanafSpacing.md),
                KanafStaggeredEntrance(
                  index: 2,
                  child: _Timeline(
                    steps: _buildSteps(need),
                    dateFormat: _dateFormat,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// المراحل تُشتق من بيانات الخادم؛ ما لا تاريخ له يبقى «لم يحدث بعد».
  List<_Step> _buildSteps(NeedModel need) {
    final progress = need.progress;
    final isCompleted = need.status == 'completed';
    final isArchived = need.status == 'archived';
    final hasProgress = need.fulfilledQuantity > 0;

    return [
      _Step(
        title: 'نُشر الاحتياج',
        subtitle: 'أعلنت الدار حاجتها وأصبحت مرئية للمتبرعين.',
        date: need.createdAt,
        done: true,
      ),
      _Step(
        title: 'بدأ الدعم يصل',
        subtitle: hasProgress
            ? 'تحقّق ${_number(need.fulfilledQuantity)}'
                '${progress == null ? '' : ' (${(progress * 100).round()}%)'}'
                ' من المطلوب.'
            : 'لم يُسجَّل أي دعم لهذا الاحتياج بعد.',
        date: hasProgress ? need.updatedAt : null,
        done: hasProgress,
      ),
      _Step(
        title: isArchived ? 'أُرشف الاحتياج' : 'اكتمل الاحتياج',
        subtitle: isArchived
            ? 'أزالته الدار من الاحتياجات المعروضة.'
            : isCompleted
                ? 'غطّت المساهمات الاحتياج وأغلقته الدار.'
                : 'سيُغلق حين تؤكد الدار اكتمال ما طلبته.',
        date: (isCompleted || isArchived) ? need.updatedAt : null,
        done: isCompleted || isArchived,
      ),
    ];
  }

  String _number(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(2);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.need});

  final NeedModel need;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final progress = need.progress;

    return KanafCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: KanafRadii.sm,
                ),
                child: Icon(need.icon, size: 24, color: scheme.primary),
              ),
              const SizedBox(width: KanafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      need.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall,
                    ),
                    const SizedBox(height: KanafSpacing.xxs),
                    Text(need.categoryLabel, style: context.texts.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              KanafStatusChip(status: need.status, compact: true),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: KanafSpacing.lg),
            ClipRRect(
              borderRadius: KanafRadii.pill,
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: KanafSpacing.sm),
            Text(
              '${(progress * 100).round()}% من ${need.requiredQuantity}',
              style: context.texts.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.done,
  });

  final String title;
  final String subtitle;
  final DateTime? date;
  final bool done;
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps, required this.dateFormat});

  final List<_Step> steps;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return KanafCard(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: steps[i].done
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: steps[i].done
                                ? scheme.primary
                                : scheme.outlineVariant,
                          ),
                        ),
                        child: Icon(
                          steps[i].done
                              ? Icons.check_rounded
                              : Icons.circle_outlined,
                          size: 15,
                          color: steps[i].done
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      if (i != steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(
                              vertical: KanafSpacing.xxs,
                            ),
                            color: steps[i].done
                                ? scheme.primary.withValues(alpha: 0.35)
                                : scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: KanafSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i == steps.length - 1 ? 0 : KanafSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: context.texts.titleSmall?.copyWith(
                              color: steps[i].done
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: KanafSpacing.xxs),
                          Text(
                            steps[i].subtitle,
                            style: context.texts.bodySmall,
                          ),
                          if (steps[i].date != null) ...[
                            const SizedBox(height: KanafSpacing.xs),
                            Text(
                              dateFormat.format(steps[i].date!),
                              style: context.texts.labelSmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
