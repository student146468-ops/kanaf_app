import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/need_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_nav_shell.dart';
import '../../widgets/kanaf_states.dart';
import '../../l10n/kanaf_localizations.dart';

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
  String _selectedCity = _allFilter;
  String _selectedCategory = _allFilter;
  _DiscoverySort _sort = _DiscoverySort.mostNeeded;

  static const String _allFilter = '__all__';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.careHomes.isEmpty && !provider.isLoading) {
        provider.fetchCareHomes();
      }
      if (provider.needs.isEmpty && !provider.isLoading) {
        provider.fetchNeeds(notifyLoading: false);
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
    final needs = provider.needs;
    final visible = _filter(all, needs);
    final cities = _citiesOf(all);
    final categories = _categoriesOf(needs);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('search.orphanagesTitle'))),
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
                  hintText: context.tr('search.orphanagesHint'),
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        tooltip: context.tr('search.clearSearch'),
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
              _DiscoveryControls(
                cities: cities,
                categories: categories,
                selectedCity: _selectedCity,
                selectedCategory: _selectedCategory,
                sort: _sort,
                onCityChanged: (value) => setState(() => _selectedCity = value),
                onCategoryChanged: (value) =>
                    setState(() => _selectedCategory = value),
                onSortChanged: (value) => setState(() => _sort = value),
              ),
              const SizedBox(height: KanafSpacing.sm),
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
                        ? context.tr('orphanage.noRegistered')
                        : context.tr('search.noResultsTitle'),
                    emptyMessage: all.isEmpty
                        ? context.tr('orphanage.noRegisteredMessage')
                        : context.tr('search.noResultsMessage'),
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
                          needs: _needsForHome(visible[index], needs),
                          numberFormat: NumberFormat.decimalPattern(
                              Localizations.localeOf(context).languageCode),
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
  List<Map<String, dynamic>> _filter(
    List<Map<String, dynamic>> homes,
    List<NeedModel> needs,
  ) {
    final query = _query.trim();
    final filtered = homes.where((home) {
      if (_selectedCity != _allFilter && _cityOf(home) != _selectedCity) {
        return false;
      }
      final homeNeeds = _needsForHome(home, needs);
      if (_selectedCategory != _allFilter &&
          !homeNeeds.any((need) => need.categoryLabel == _selectedCategory)) {
        return false;
      }
      if (query.isEmpty) return true;

      final haystack = [
        home['name'],
        home['address'],
        home['description'],
      ].map((value) => value?.toString() ?? '').join(' ');
      return haystack.contains(query);
    }).toList();

    filtered.sort((a, b) {
      return switch (_sort) {
        _DiscoverySort.nearest => _cityOf(a).compareTo(_cityOf(b)),
        _DiscoverySort.mostNeeded =>
          _needScore(b, needs).compareTo(_needScore(a, needs)),
      };
    });
    return filtered;
  }

  List<String> _citiesOf(List<Map<String, dynamic>> homes) {
    final cities = homes.map(_cityOf).where((city) => city.isNotEmpty).toSet()
      ..remove(_allFilter);
    return [_allFilter, ...cities.toList()..sort()];
  }

  List<String> _categoriesOf(List<NeedModel> needs) {
    final categories = needs
        .where((need) => need.status == 'open')
        .map((need) => need.categoryLabel)
        .where((category) => category.isNotEmpty)
        .toSet();
    return [_allFilter, ...categories.toList()..sort()];
  }

  List<NeedModel> _needsForHome(
    Map<String, dynamic> home,
    List<NeedModel> needs,
  ) {
    final id = int.tryParse(home['id']?.toString() ?? '');
    if (id == null) return const [];
    return needs
        .where((need) => need.careHomeId == id && need.status == 'open')
        .toList();
  }

  int _needScore(Map<String, dynamic> home, List<NeedModel> needs) {
    return _needsForHome(home, needs).fold<int>(0, (score, need) {
      final priority = need.priority == 'urgent' ? 3 : 1;
      return score + priority;
    });
  }

  static String _cityOf(Map<String, dynamic> home) {
    final city = home['city'] ?? home['region'];
    if (city != null && city.toString().trim().isNotEmpty) {
      return city.toString().trim();
    }
    final address = home['address']?.toString() ?? '';
    final parts = address
        .split(RegExp(r'[,،-]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? '' : parts.first;
  }
}

enum _DiscoverySort {
  mostNeeded('search.sortMostNeeded'),
  nearest('search.sortNearest');

  const _DiscoverySort(this.labelKey);

  final String labelKey;
}

class _DiscoveryControls extends StatelessWidget {
  const _DiscoveryControls({
    required this.cities,
    required this.categories,
    required this.selectedCity,
    required this.selectedCategory,
    required this.sort,
    required this.onCityChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
  });

  final List<String> cities;
  final List<String> categories;
  final String selectedCity;
  final String selectedCategory;
  final _DiscoverySort sort;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<_DiscoverySort> onSortChanged;

  static String _labelFor(BuildContext context, String value) {
    return value == _ExploreOrphanagesScreenState._allFilter
        ? context.tr('common.all')
        : value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KanafSpacing.pageInset),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FilterMenu(
                  icon: Icons.location_city_outlined,
                  label: _labelFor(context, selectedCity),
                  values: cities,
                  displayLabel: (value) => _labelFor(context, value),
                  onSelected: onCityChanged,
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              Expanded(
                child: _FilterMenu(
                  icon: Icons.category_outlined,
                  label: _labelFor(context, selectedCategory),
                  values: categories,
                  displayLabel: (value) => _labelFor(context, value),
                  onSelected: onCategoryChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: KanafSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_DiscoverySort>(
              selected: {sort},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => onSortChanged(selection.first),
              segments: [
                for (final option in _DiscoverySort.values)
                  ButtonSegment<_DiscoverySort>(
                    value: option,
                    icon: Icon(
                      option == _DiscoverySort.nearest
                          ? Icons.near_me_outlined
                          : Icons.priority_high_rounded,
                    ),
                    label: Text(
                      context.tr(option.labelKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.icon,
    required this.label,
    required this.values,
    required this.displayLabel,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final List<String> values;
  final String Function(String value) displayLabel;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) => OutlinedButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: Icon(icon),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      menuChildren: [
        for (final value in values)
          MenuItemButton(
            onPressed: () => onSelected(value),
            child: Text(displayLabel(value)),
          ),
      ],
    );
  }
}

class _CareHomeCard extends StatelessWidget {
  const _CareHomeCard({
    required this.data,
    required this.needs,
    required this.numberFormat,
  });

  final Map<String, dynamic> data;
  final List<NeedModel> needs;
  final NumberFormat numberFormat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final name =
        data['name']?.toString() ?? context.tr('orphanage.defaultName');
    final address = data['address']?.toString() ?? '';
    final description = data['description']?.toString() ?? '';
    final orphanCount = _intOf(data['orphan_count']);
    final phone = data['phone']?.toString() ?? '';
    final imageUrl = (data['image_url'] ?? data['logo'] ?? data['logo_url'])
        ?.toString()
        .trim();

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
              _CareHomeAvatar(imageUrl: imageUrl),
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
          if (needs.isNotEmpty) ...[
            const SizedBox(height: KanafSpacing.lg),
            _NeedsSnapshot(needs: needs),
          ],
          const Divider(height: KanafSpacing.xxl),
          Row(
            children: [
              if (orphanCount != null)
                _MetaChip(
                  icon: Icons.child_care_outlined,
                  label: context.tr('orphanage.childrenCount', args: {
                    'count': numberFormat.format(orphanCount),
                  }),
                ),
              if (phone.isNotEmpty) ...[
                const SizedBox(width: KanafSpacing.sm),
                _MetaChip(icon: Icons.call_outlined, label: phone),
              ],
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  KanafRoutes.financialDonation,
                  arguments: data,
                ),
                icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
                label: Text(context.tr('orphanage.donateNow')),
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

class _CareHomeAvatar extends StatelessWidget {
  const _CareHomeAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.12),
        borderRadius: KanafRadii.md,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.apartment_rounded,
                size: 28,
                color: scheme.primary,
              ),
            )
          : Icon(
              Icons.apartment_rounded,
              size: 28,
              color: scheme.primary,
            ),
    );
  }
}

class _NeedsSnapshot extends StatelessWidget {
  const _NeedsSnapshot({required this.needs});

  final List<NeedModel> needs;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<NeedModel>>{};
    for (final need in needs) {
      grouped.putIfAbsent(need.categoryLabel, () => []).add(need);
    }
    final visible = grouped.entries.take(3).toList();

    return Column(
      children: [
        for (final entry in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: KanafSpacing.xs),
            child: _NeedProgressRow(
              label: entry.key,
              progress: _averageProgress(entry.value),
            ),
          ),
      ],
    );
  }

  static double _averageProgress(List<NeedModel> needs) {
    final values = needs.map((need) => need.progress).whereType<double>();
    if (values.isEmpty) return 0;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    return (total / values.length).clamp(0.0, 1.0);
  }
}

class _NeedProgressRow extends StatelessWidget {
  const _NeedProgressRow({required this.label, required this.progress});

  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final remaining = ((1 - progress) * 100).round().clamp(0, 100);

    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(label, style: context.texts.labelSmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: KanafRadii.pill,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              color: scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: KanafSpacing.sm),
        Text(
          'متبقي $remaining٪',
          style: context.texts.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
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
