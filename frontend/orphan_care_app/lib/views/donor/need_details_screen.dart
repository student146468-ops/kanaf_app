import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/need_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_media_content_card.dart';
import '../../widgets/kanaf_states.dart';
import '../../l10n/kanaf_localizations.dart';

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
    final dateFormat = DateFormat(
      'd MMMM y',
      Localizations.localeOf(context).languageCode,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('need.detailsTitle')),
        leading: const BackButton(),
        actions: [
          if (isReady)
            IconButton(
              tooltip: context.tr('need.trackStatus'),
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
            emptyTitle: context.tr('need.notFoundTitle'),
            emptyMessage: context.tr('need.notFoundMessage'),
            builder: (context) {
              final readyNeed = need!;
              return Column(
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
                          child: KanafMediaContentCard.need(
                            context: context,
                            need: readyNeed,
                            onDonate: () => Navigator.pushNamed(
                              context,
                              KanafRoutes.financialDonation,
                              arguments: {'need_id': readyNeed.id},
                            ),
                            onInkindDonate: () => Navigator.pushNamed(
                              context,
                              KanafRoutes.inkindDonation,
                              arguments: {'need_id': readyNeed.id},
                            ),
                          ),
                        ),
                        const SizedBox(height: KanafSpacing.lg),
                        KanafStaggeredEntrance(
                          index: 1,
                          child: _FactsSection(
                            need: readyNeed,
                            dateFormat: dateFormat,
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
                            onPressed: readyNeed.status == 'open'
                                ? () => Navigator.pushNamed(
                                      context,
                                      KanafRoutes.financialDonation,
                                      arguments: {'need_id': readyNeed.id},
                                    )
                                : null,
                            icon: const Icon(Icons.payments_outlined),
                            label: Text(
                              readyNeed.status == 'open'
                                  ? context.tr('need.contributeNow')
                                  : context.tr('need.completed'),
                            ),
                          ),
                        ),
                        if (readyNeed.status == 'open') ...[
                          const SizedBox(width: KanafSpacing.md),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                KanafRoutes.inkindDonation,
                                arguments: {'need_id': readyNeed.id},
                              ),
                              icon: const Icon(Icons.inventory_2_outlined),
                              label: Text(context.tr('need.inkindDonate')),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
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
        KanafDetailRow(
          label: context.tr('need.careHome'),
          value: need.careHomeName!,
        ),
      if ((need.careHomeLocation ?? '').isNotEmpty)
        KanafDetailRow(
          label: context.tr('need.location'),
          value: need.careHomeLocation!,
        ),
      KanafDetailRow(
        label: context.tr('need.priority'),
        value: need.priorityLabelFor(context),
      ),
      KanafDetailRow(
        label: context.tr('need.category'),
        value: need.categoryLabelFor(context),
      ),
      if (need.needType.isNotEmpty)
        KanafDetailRow(label: context.tr('need.type'), value: need.needType),
      if (need.deadline != null)
        KanafDetailRow(
          label: context.tr('need.deadline'),
          value: dateFormat.format(need.deadline!),
        ),
      if (need.createdAt != null)
        KanafDetailRow(
          label: context.tr('need.publishedAt'),
          value: dateFormat.format(need.createdAt!),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KanafSectionHeader(title: context.tr('need.details')),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(child: Column(children: rows)),
      ],
    );
  }
}
