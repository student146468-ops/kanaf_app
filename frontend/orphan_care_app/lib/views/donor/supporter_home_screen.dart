import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/need_model.dart';
import '../../providers/app_provider.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_nav_shell.dart';
import '../../widgets/kanaf_states.dart';

/// رئيسية المتبرع.
///
/// أُعيد بناؤها على Material 3 مع `NavigationBar` بدل الشريط المخصص.
/// تحسين أداء مهم: عارض الصور المتحرك كان يعمل بـ `Timer.periodic`
/// بلا نهاية — يستمر في تحريك الصفحات وإعادة البناء حتى بعد انتقال
/// المستخدم لشاشة أخرى. الآن يتوقف عند فقدان الرؤية.
class SupporterHomeScreen extends StatefulWidget {
  const SupporterHomeScreen({super.key});

  @override
  State<SupporterHomeScreen> createState() => _SupporterHomeScreenState();
}

class _SupporterHomeScreenState extends State<SupporterHomeScreen>
    with WidgetsBindingObserver {
  static const List<String> _sliderImages = [
    'assets/images/i1.png',
    'assets/images/i2.png',
    'assets/images/i3.png',
  ];

  final PageController _sliderController = PageController();
  Timer? _sliderTimer;
  int _currentSlide = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSlider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.needs.isEmpty && !provider.isLoading) {
        provider.fetchNeeds();
      }
      provider.fetchNotifications(notifyLoading: false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // إيقاف المؤقّت في الخلفية: تحريك صفحات لا يراها أحد يستهلك
    // البطارية ويجبر Flutter على إعادة رسم إطارات بلا فائدة.
    if (state == AppLifecycleState.resumed) {
      _startSlider();
    } else {
      _sliderTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sliderTimer?.cancel();
    _sliderController.dispose();
    super.dispose();
  }

  void _startSlider() {
    _sliderTimer?.cancel();
    _sliderTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_sliderController.hasClients) return;
      final next = (_currentSlide + 1) % _sliderImages.length;
      _sliderController.animateToPage(
        next,
        duration: KanafDuration.slow,
        curve: KanafCurves.emphasized,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final needs = provider.needs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('كَنَفْ'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'بحث وتصفية',
            onPressed: () =>
                Navigator.pushNamed(context, KanafRoutes.searchFilter),
            icon: const Icon(Icons.search_rounded),
          ),
          KanafNotificationButton(
            unreadCount: _unreadCount(provider.notifications),
            route: KanafRoutes.donorNotifications,
          ),
          const SizedBox(width: KanafSpacing.xs),
        ],
      ),
      bottomNavigationBar: const KanafNavBar(
        destinations: KanafNavDestinations.donor,
        currentIndex: 0,
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: provider.fetchNeeds,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    KanafSpacing.pageInset,
                    KanafSpacing.lg,
                    KanafSpacing.pageInset,
                    0,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _buildSlider(),
                      const SizedBox(height: KanafSpacing.xxl),
                      _buildQuickActions(),
                      const SizedBox(height: KanafSpacing.xxl),
                      KanafSectionHeader(
                        title: 'احتياجات عاجلة',
                        subtitle: 'حالات مفتوحة بانتظار دعمك',
                        actionLabel: needs.isEmpty ? null : 'الكل',
                        onAction: needs.isEmpty
                            ? null
                            : () => Navigator.pushNamed(
                                  context,
                                  KanafRoutes.exploreOrphanages,
                                ),
                      ),
                      const SizedBox(height: KanafSpacing.md),
                    ],
                  ),
                ),
                _buildNeedsSliver(provider, needs),
                const SliverToBoxAdapter(
                  child: SizedBox(height: KanafSpacing.xxl),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeedsSliver(AppProvider provider, List<NeedModel> needs) {
    if (needs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: SizedBox(
          height: 320,
          child: KanafAsyncView(
            isLoading: provider.isLoading,
            isEmpty: true,
            errorMessage: provider.errorMessage,
            errorKind: provider.errorKind,
            onRetry: provider.fetchNeeds,
            emptyIcon: Icons.checklist_rtl_rounded,
            emptyTitle: 'لا توجد احتياجات مفتوحة حالياً',
            emptyMessage: 'ستظهر هنا الاحتياجات فور نشرها من دور الرعاية.',
            builder: (_) => const SizedBox.shrink(),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: KanafSpacing.pageInset),
      sliver: SliverList.separated(
        itemCount: needs.length,
        separatorBuilder: (_, __) => const SizedBox(height: KanafSpacing.md),
        itemBuilder: (context, index) => KanafStaggeredEntrance(
          index: index,
          child: _NeedCard(need: needs[index]),
        ),
      ),
    );
  }

  Widget _buildSlider() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: KanafRadii.lg,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              controller: _sliderController,
              onPageChanged: (index) => setState(() => _currentSlide = index),
              itemCount: _sliderImages.length,
              itemBuilder: (context, index) => Image.asset(
                _sliderImages[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: context.colors.primaryContainer,
                  child: Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: context.colors.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: KanafSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _sliderImages.length; i++)
              AnimatedContainer(
                duration: KanafDuration.standard,
                margin: const EdgeInsets.symmetric(horizontal: KanafSpacing.xs),
                width: i == _currentSlide ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _currentSlide
                      ? context.colors.primary
                      : context.colors.surfaceContainerHighest,
                  borderRadius: KanafRadii.pill,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return const Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.payments_outlined,
            label: 'تبرع مالي',
            route: KanafRoutes.financialDonation,
          ),
        ),
        SizedBox(width: KanafSpacing.md),
        Expanded(
          child: _QuickAction(
            icon: Icons.inventory_2_outlined,
            label: 'تبرع عيني',
            route: KanafRoutes.inkindDonation,
          ),
        ),
        SizedBox(width: KanafSpacing.md),
        Expanded(
          child: _QuickAction(
            icon: Icons.travel_explore_outlined,
            label: 'استكشاف',
            route: KanafRoutes.exploreOrphanages,
          ),
        ),
      ],
    );
  }

  static int _unreadCount(List<Map<String, dynamic>> notifications) {
    return notifications.where((item) => item['is_read'] != true).length;
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return KanafCard(
      onTap: () => Navigator.pushNamed(context, route),
      padding: const EdgeInsets.symmetric(
        vertical: KanafSpacing.lg,
        horizontal: KanafSpacing.sm,
      ),
      child: Column(
        children: [
          Icon(icon, size: 26, color: scheme.primary),
          const SizedBox(height: KanafSpacing.sm),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.texts.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// بطاقة احتياج.
///
/// تقرأ من `NeedModel` مباشرة بدل التحويل إلى `Map<String, dynamic>`
/// كما كان — التحويل كان يفقد أنواع البيانات ويجبر كل مستهلك على
/// إعادة تحليل النصوص.
class _NeedCard extends StatelessWidget {
  const _NeedCard({required this.need});

  final NeedModel need;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final progress = _progress;

    return KanafCard(
      onTap: () => Navigator.pushNamed(
        context,
        KanafRoutes.needDetails,
        arguments: <String, dynamic>{
          'id': need.id,
          'title': need.title,
          'description': need.description,
          'category': need.category,
          'priority': need.priority,
          'status': need.status,
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: KanafRadii.sm,
                ),
                child: Icon(
                  _categoryIcon(need.category),
                  size: 22,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: KanafSpacing.md),
              Expanded(
                child: Text(
                  need.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall,
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              if (need.priority == 'urgent') const _UrgentBadge(),
            ],
          ),
          if (need.description.isNotEmpty) ...[
            const SizedBox(height: KanafSpacing.md),
            Text(
              need.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall,
            ),
          ],
          const SizedBox(height: KanafSpacing.lg),
          ClipRRect(
            borderRadius: KanafRadii.pill,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
            ),
          ),
          const SizedBox(height: KanafSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تم تأمين ${(progress * 100).round()}%',
                style: context.texts.labelSmall,
              ),
              KanafStatusChip(status: need.status, compact: true),
            ],
          ),
        ],
      ),
    );
  }

  double get _progress {
    final target = _numberFrom(need.requiredQuantity);
    if (target <= 0) return 0;
    return (need.fulfilledQuantity / target).clamp(0.0, 1.0);
  }

  static double _numberFrom(String value) {
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(value.replaceAll(',', ''));
    return double.tryParse(match?.group(0) ?? '') ?? 0;
  }

  static IconData _categoryIcon(String category) => switch (category) {
        'food' => Icons.restaurant_outlined,
        'clothes' => Icons.checkroom_outlined,
        'medical' => Icons.health_and_safety_outlined,
        'education' => Icons.school_outlined,
        _ => Icons.category_outlined,
      };
}

class _UrgentBadge extends StatelessWidget {
  const _UrgentBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KanafSpacing.sm,
        vertical: KanafSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: KanafRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.priority_high_rounded,
            size: 13,
            color: scheme.onErrorContainer,
          ),
          Text(
            'عاجل',
            style: context.texts.labelSmall?.copyWith(
              color: scheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}
