import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

/// البحث عن فرص التطوع.
///
/// أُصلح فيها عيبان قاتلان:
///
/// 1. `if (_selectedFilter == 'ط§ظ„ظƒظ„')` — سلسلة «الكل» مشوّهة بترميز
///    خاطئ، فلم تكن تساوي القيمة الابتدائية أبداً. النتيجة أن الشاشة
///    كانت تسقط إلى فرع التصفية وتبحث عن فرص عنوانها يحوي كلمة
///    «الكل» حرفياً، فتعرض **صفر نتائج** عند فتحها.
/// 2. التصنيفات «تعليم/أنشطة/إغاثة» كانت تُطابَق ضد `status` الذي لا
///    يحمل إلا `open`/`closed`/`completed`. لا يوجد حقل تصنيف في
///    `VolunteerOpportunity` أصلاً، فاستُبدلت بتصفية حسب الحالة —
///    وهي المعلومة الموجودة فعلاً.
class SearchFilterView extends StatefulWidget {
  const SearchFilterView({super.key});

  @override
  State<SearchFilterView> createState() => _SearchFilterViewState();
}

class _SearchFilterViewState extends State<SearchFilterView> {
  final _searchController = TextEditingController();
  _OpportunityScope _scope = _OpportunityScope.open;
  String _query = '';

  static final DateFormat _dateFormat = DateFormat('d MMM y', 'ar');

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
    final scoped = _scope.apply(provider.volunteerOpportunities);
    final visible = _applyQuery(scoped);

    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث عن فرص'),
        leading: const BackButton(),
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildSearchField(),
              _buildScopes(provider.volunteerOpportunities),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.fetchVolunteerOpportunities,
                  child: KanafAsyncView(
                    isLoading: provider.isLoading,
                    isEmpty: visible.isEmpty,
                    errorMessage: provider.volunteerOpportunities.isEmpty
                        ? provider.errorMessage
                        : null,
                    onRetry: provider.fetchVolunteerOpportunities,
                    emptyIcon: _query.isEmpty
                        ? Icons.handshake_outlined
                        : Icons.search_off_rounded,
                    emptyTitle: _query.isEmpty
                        ? 'لا توجد فرص في هذا التصنيف'
                        : 'لا نتائج لـ «$_query»',
                    emptyMessage: _query.isEmpty
                        ? 'ستظهر الفرص هنا فور نشرها من دور الرعاية.'
                        : 'جرّب كلمة أخرى أو وسّع التصنيف.',
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
                        child: _ResultCard(
                          data: visible[index],
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
          hintText: 'ابحث بالعنوان أو المكان',
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
    );
  }

  Widget _buildScopes(List<Map<String, dynamic>> all) {
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
          for (final option in _OpportunityScope.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: KanafSpacing.sm),
              child: FilterChip(
                label: Text('${option.label} (${option.apply(all).length})'),
                selected: _scope == option,
                onSelected: (_) => setState(() => _scope = option),
              ),
            ),
        ],
      ),
    );
  }

  /// بحث نصي على الحقول التي يرسلها الخادم فعلاً.
  List<Map<String, dynamic>> _applyQuery(List<Map<String, dynamic>> items) {
    if (_query.isEmpty) return items;
    final needle = _query.toLowerCase();
    return items.where((item) {
      bool has(String key) =>
          (item[key]?.toString().toLowerCase() ?? '').contains(needle);
      return has('title') || has('description') || has('location');
    }).toList();
  }
}

enum _OpportunityScope {
  open('متاحة'),
  all('الكل'),
  closed('مغلقة');

  const _OpportunityScope(this.label);

  final String label;

  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> items) {
    return switch (this) {
      _OpportunityScope.all => items,
      _OpportunityScope.open =>
        items.where((o) => o['status'] == 'open').toList(),
      _OpportunityScope.closed =>
        items.where((o) => o['status'] != 'open').toList(),
    };
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.data, required this.dateFormat});

  final Map<String, dynamic> data;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final title = data['title']?.toString() ?? 'فرصة تطوع';
    final location = data['location']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'open';
    final start = DateTime.tryParse(data['start_date']?.toString() ?? '');
    final required = int.tryParse(
          data['required_volunteers']?.toString() ?? '',
        ) ??
        0;
    final current =
        int.tryParse(data['current_volunteers']?.toString() ?? '') ?? 0;
    final remaining = (required - current).clamp(0, required);

    return KanafCard(
      onTap: () => Navigator.pushNamed(
        context,
        KanafRoutes.volunteerOpportunityDetails,
        arguments: data,
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
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: KanafRadii.sm,
                ),
                child: Icon(
                  Icons.handshake_outlined,
                  size: 22,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: KanafSpacing.md),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall,
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              KanafStatusChip(status: status, compact: true),
            ],
          ),
          const SizedBox(height: KanafSpacing.md),
          Row(
            children: [
              if (location.isNotEmpty) ...[
                Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: KanafSpacing.xs),
                Flexible(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall,
                  ),
                ),
                const SizedBox(width: KanafSpacing.md),
              ],
              if (start != null) ...[
                Icon(
                  Icons.event_outlined,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: KanafSpacing.xs),
                Text(
                  dateFormat.format(start),
                  style: context.texts.labelSmall,
                ),
              ],
              const Spacer(),
              if (required > 0)
                Text(
                  remaining == 0 ? 'مكتملة' : 'متبقٍ $remaining',
                  style: context.texts.labelSmall?.copyWith(
                    color: remaining == 0 ? scheme.error : scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
