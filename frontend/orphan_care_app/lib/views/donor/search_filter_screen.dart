import 'package:flutter/material.dart';

import '../../models/need_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_media_content_card.dart';
import '../../widgets/kanaf_states.dart';
import '../../l10n/kanaf_localizations.dart';

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
  String _selectedCategory = _allCategory;
  String _query = '';

  static const String _allCategory = '__all__';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.needs.isEmpty && !provider.isLoadingNeeds) {
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
    final visible =
        _applyCategory(context, _applyQuery(context, _filter.apply(all)));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('search.needsTitle')),
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
                    hintText: context.tr('search.needsHint'),
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
              ),
              _buildFilters(all),
              _buildCategories(all),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.fetchNeeds,
                  child: KanafAsyncView(
                    isLoading: provider.isLoadingNeeds,
                    isEmpty: visible.isEmpty,
                    errorMessage:
                        all.isEmpty ? provider.needsErrorMessage : null,
                    errorKind: provider.needsErrorKind,
                    onRetry: provider.fetchNeeds,
                    emptyIcon: Icons.search_off_rounded,
                    emptyTitle: _query.isEmpty
                        ? context.tr('need.emptyCategoryTitle')
                        : context.tr('search.noResultsTitle'),
                    emptyMessage: _query.isEmpty
                        ? context.tr('need.emptyCategoryMessage')
                        : context.tr('need.noResultsMessage'),
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
                        child: KanafMediaContentCard.need(
                          context: context,
                          need: visible[index],
                          onTap: () => Navigator.pushNamed(
                            context,
                            KanafRoutes.needDetails,
                            arguments: <String, dynamic>{
                              'id': visible[index].id,
                            },
                          ),
                          onDonate: visible[index].status == 'open'
                              ? () => Navigator.pushNamed(
                                    context,
                                    KanafRoutes.financialDonation,
                                    arguments: {'need_id': visible[index].id},
                                  )
                              : null,
                          onInkindDonate: visible[index].status == 'open'
                              ? () => Navigator.pushNamed(
                                    context,
                                    KanafRoutes.inkindDonation,
                                    arguments: {'need_id': visible[index].id},
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

  Widget _buildCategories(List<NeedModel> all) {
    final categories = <String>{
      _allCategory,
      ...all
          .map((need) => need.categoryLabelFor(context))
          .where((label) => label.trim().isNotEmpty),
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
                label: Text(category == _allCategory
                    ? context.tr('common.all')
                    : category),
                selected: _selectedCategory == category,
                onSelected: (_) => setState(() => _selectedCategory = category),
              ),
            ),
        ],
      ),
    );
  }

  List<NeedModel> _applyQuery(BuildContext context, List<NeedModel> items) {
    if (_query.isEmpty) return items;
    final needle = _query.toLowerCase();
    return items.where((need) {
      return need.title.toLowerCase().contains(needle) ||
          need.description.toLowerCase().contains(needle) ||
          need.categoryLabelFor(context).toLowerCase().contains(needle) ||
          need.category.toLowerCase().contains(needle);
    }).toList();
  }

  List<NeedModel> _applyCategory(BuildContext context, List<NeedModel> items) {
    if (_selectedCategory == _allCategory) return items;
    return items
        .where((need) => need.categoryLabelFor(context) == _selectedCategory)
        .toList();
  }
}

enum _NeedFilter {
  all('common.all'),
  urgent('home.urgent'),
  open('need.open'),
  completed('need.completed');

  const _NeedFilter(this.labelKey);

  final String labelKey;

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
