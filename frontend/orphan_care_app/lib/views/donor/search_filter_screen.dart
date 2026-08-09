import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/need_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

/// قائمة الاحتياجات والبحث فيها.
///
/// أُصلحت فيها ثلاثة عيوب:
///
/// 1. كانت تُسطّح كل احتياج إلى قاموس فيه `'orphanage': 'كنف'` و
///    `'city': 'ليبيا'` — قيمتان **ثابتتان لكل احتياج** تُعرضان كأنهما
///    اسم الدار ومدينتها.
/// 2. القاموس الناتج لم يكن يحمل `id` إطلاقاً، فالنقر على أي نتيجة
///    ينقل إلى تفاصيل بلا معرّف.
/// 3. كانت التصفية تُطابق **نصوصاً عربية** مترجمة (`'قيد التنفيذ'`)
///    بدل قيم الحالة التي يعرفها الخادم، وهي هشّة تنكسر بأي تغيير
///    في الترجمة. صارت تعمل على `status` و`priority` مباشرة.
class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final _searchController = TextEditingController();
  _NeedFilter _filter = _NeedFilter.all;
  String _query = '';

  static final DateFormat _dateFormat = DateFormat('d MMM y', 'ar');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.needs.isEmpty && !provider.isLoading) {
        provider.fetchNeeds();
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
    final all = provider.needs;
    final visible = _applyQuery(_filter.apply(all));

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاحتياجات'),
        leading: const BackButton(),
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
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
                    hintText: 'ابحث بالعنوان أو التصنيف',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              _buildFilters(all),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.fetchNeeds,
                  child: KanafAsyncView(
                    isLoading: provider.isLoading,
                    isEmpty: visible.isEmpty,
                    errorMessage: all.isEmpty ? provider.errorMessage : null,
                    errorKind: provider.errorKind,
                    onRetry: provider.fetchNeeds,
                    emptyIcon: Icons.search_off_rounded,
                    emptyTitle: _query.isEmpty
                        ? 'لا توجد احتياجات في هذا التصنيف'
                        : 'لم نجد احتياجاً مطابقاً',
                    emptyMessage: _query.isEmpty
                        ? 'ستظهر الاحتياجات هنا فور نشرها من دور الرعاية.'
                        : 'جرّب كلمة أبسط أو وسّع التصنيف.',
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
                        child: _NeedCard(
                          need: visible[index],
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

  Widget _buildFilters(List<NeedModel> all) {
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
          for (final option in _NeedFilter.values)
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

  List<NeedModel> _applyQuery(List<NeedModel> items) {
    if (_query.isEmpty) return items;
    final needle = _query.toLowerCase();
    return items.where((need) {
      return need.title.toLowerCase().contains(needle) ||
          need.description.toLowerCase().contains(needle) ||
          need.categoryLabel.contains(_query) ||
          need.category.toLowerCase().contains(needle);
    }).toList();
  }
}

enum _NeedFilter {
  all('الكل'),
  urgent('عاجل'),
  open('قيد التنفيذ'),
  completed('مكتمل');

  const _NeedFilter(this.label);

  final String label;

  /// تعمل على قيم الخادم لا على النصوص المترجمة.
  List<NeedModel> apply(List<NeedModel> items) {
    final visible = items.where((n) => n.status != 'archived').toList();
    return switch (this) {
      _NeedFilter.all => visible,
      _NeedFilter.urgent =>
        visible.where((n) => n.priority == 'urgent').toList(),
      _NeedFilter.open => visible.where((n) => n.status == 'open').toList(),
      _NeedFilter.completed =>
        visible.where((n) => n.status == 'completed').toList(),
    };
  }
}

class _NeedCard extends StatelessWidget {
  const _NeedCard({required this.need, required this.dateFormat});

  final NeedModel need;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final progress = need.progress;

    return KanafCard(
      onTap: () => Navigator.pushNamed(
        context,
        KanafRoutes.needDetails,
        arguments: <String, dynamic>{'id': need.id},
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
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: KanafRadii.sm,
                ),
                child: Icon(need.icon, size: 22, color: scheme.primary),
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
              KanafStatusChip(
                status: need.priority == 'urgent' ? 'urgent' : need.status,
                compact: true,
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: KanafSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: KanafRadii.pill,
                    child:
                        LinearProgressIndicator(value: progress, minHeight: 6),
                  ),
                ),
                const SizedBox(width: KanafSpacing.md),
                Text(
                  '${(progress * 100).round()}%',
                  style: context.texts.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          if (need.deadline != null) ...[
            const SizedBox(height: KanafSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: KanafSpacing.xs),
                Text(
                  'حتى ${dateFormat.format(need.deadline!)}',
                  style: context.texts.labelSmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
