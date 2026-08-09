import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_nav_shell.dart';
import '../../widgets/kanaf_states.dart';

/// استكشاف دور الرعاية.
///
/// كانت هذه الشاشة تعرض **ثلاث دور مخترعة** مكتوبة يدوياً في الكود مع
/// تعليق `TODO: Replace with AppProvider ... when available` — بينما
/// `fetchCareHomes()` ونقطة `/care-homes/` موجودتان في المشروع أصلاً.
/// النتيجة أن المتبرع يرى دوراً لا وجود لها ولا يرى الدور الحقيقية.
/// الآن تقرأ من الخادم، والبحث يجري على البيانات الفعلية.
class ExploreOrphanagesScreen extends StatefulWidget {
  const ExploreOrphanagesScreen({super.key});

  @override
  State<ExploreOrphanagesScreen> createState() =>
      _ExploreOrphanagesScreenState();
}

class _ExploreOrphanagesScreenState extends State<ExploreOrphanagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static final NumberFormat _numberFormat = NumberFormat.decimalPattern('ar');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.careHomes.isEmpty && !provider.isLoading) {
        provider.fetchCareHomes();
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
    final all = provider.careHomes;
    final visible = _filter(all);

    return Scaffold(
      appBar: AppBar(title: const Text('استكشاف دور الرعاية')),
      bottomNavigationBar: const KanafNavBar(
        destinations: KanafNavDestinations.donor,
        currentIndex: 1,
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KanafSpacing.pageInset,
                  KanafSpacing.md,
                  KanafSpacing.pageInset,
                  KanafSpacing.md,
                ),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'ابحث باسم الدار أو العنوان',
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.fetchCareHomes,
                  child: KanafAsyncView(
                    isLoading: provider.isLoading,
                    isEmpty: visible.isEmpty,
                    errorMessage: all.isEmpty ? provider.errorMessage : null,
                    errorKind: provider.errorKind,
                    onRetry: provider.fetchCareHomes,
                    emptyIcon: all.isEmpty
                        ? Icons.apartment_outlined
                        : Icons.search_off_rounded,
                    emptyTitle: all.isEmpty
                        ? 'لا توجد دور رعاية مسجّلة بعد'
                        : 'لا نتائج لبحثك',
                    emptyMessage: all.isEmpty
                        ? 'ستظهر هنا الدور فور تسجيلها في المنظومة.'
                        : 'جرّب اسماً آخر أو امسح البحث.',
                    builder: (context) => ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        KanafSpacing.pageInset,
                        0,
                        KanafSpacing.pageInset,
                        KanafSpacing.bottomSafeGutter,
                      ),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: KanafSpacing.md),
                      itemBuilder: (context, index) => KanafStaggeredEntrance(
                        index: index,
                        child: _CareHomeCard(
                          data: visible[index],
                          numberFormat: _numberFormat,
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

  /// بحث نصي على الاسم والعنوان والوصف.
  /// كانت التصفية السابقة على «المدينة» تطابق نصاً داخل عنوان مخترع،
  /// وهو معيار لا يصمد مع بيانات حقيقية بصيغ عناوين متنوعة.
  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> homes) {
    final query = _query.trim();
    if (query.isEmpty) return homes;

    return homes.where((home) {
      final haystack = [
        home['name'],
        home['address'],
        home['description'],
      ].map((value) => value?.toString() ?? '').join(' ');
      return haystack.contains(query);
    }).toList();
  }
}

class _CareHomeCard extends StatelessWidget {
  const _CareHomeCard({required this.data, required this.numberFormat});

  final Map<String, dynamic> data;
  final NumberFormat numberFormat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final name = data['name']?.toString() ?? 'دار رعاية';
    final address = data['address']?.toString() ?? '';
    final description = data['description']?.toString() ?? '';
    final orphanCount = _intOf(data['orphan_count']);
    final phone = data['phone']?.toString() ?? '';

    return KanafCard(
      onTap: () => Navigator.pushNamed(
        context,
        KanafRoutes.orphanageProfile,
        arguments: data,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: KanafRadii.md,
                ),
                child: Icon(
                  Icons.apartment_rounded,
                  size: 25,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: KanafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall,
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: KanafSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: KanafSpacing.xs),
                          Expanded(
                            child: Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: KanafSpacing.md),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall,
            ),
          ],
          const Divider(height: KanafSpacing.xxl),
          Row(
            children: [
              if (orphanCount != null)
                _MetaChip(
                  icon: Icons.child_care_outlined,
                  label: '${numberFormat.format(orphanCount)} طفل',
                ),
              if (phone.isNotEmpty) ...[
                const SizedBox(width: KanafSpacing.sm),
                _MetaChip(icon: Icons.call_outlined, label: phone),
              ],
              const Spacer(),
              Icon(
                Icons.chevron_left_rounded,
                color: scheme.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static int? _intOf(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
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
        horizontal: KanafSpacing.md,
        vertical: KanafSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: KanafRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: KanafSpacing.xs),
          Text(
            label,
            style: context.texts.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
