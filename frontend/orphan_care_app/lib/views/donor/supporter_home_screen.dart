import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../l10n/kanaf_localizations.dart';
import '../../models/need_model.dart';
import '../../models/volunteer_opportunity_model.dart';
import '../../providers/app_provider.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_nav_shell.dart';
import '../../widgets/kanaf_states.dart';

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
  static const int _featuredBannerCount = 1;

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
      if (provider.needs.isEmpty && !provider.isLoadingNeeds) {
        provider.fetchNeeds();
      }
      if (provider.volunteerOpportunities.isEmpty) {
        provider.fetchVolunteerOpportunities(notifyLoading: false);
      }
      provider.fetchNotifications(notifyLoading: false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
      final next = (_currentSlide + 1) % _sliderItemCount;
      _sliderController.animateToPage(
        next,
        duration: KanafDuration.slow,
        curve: KanafCurves.emphasized,
      );
    });
  }

  int get _sliderItemCount => _featuredBannerCount + _sliderImages.length;

  Future<void> _refreshHome() async {
    final provider = AppProviderScope.read(context);
    await provider.fetchNeeds();
    await provider.fetchVolunteerOpportunities(notifyLoading: false);
    await provider.fetchNotifications(notifyLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final needs = provider.needs;
    final opportunities = provider.volunteerOpportunityModels;
    final notifications = provider.notifications;
    final l10n = context.l10n;

    final openNeeds = needs.where(_isOpenNeed).toList(growable: false);
    final urgentNeeds = openNeeds.where(_isUrgentNeed).toList(growable: false);
    final featuredNeeds = urgentNeeds.isNotEmpty
        ? urgentNeeds.take(3).toList(growable: false)
        : openNeeds.take(3).toList(growable: false);
    final campaignNeeds = openNeeds
        .where((need) => !_isUrgentNeed(need))
        .take(6)
        .toList(growable: false);
    final visibleCampaigns =
        campaignNeeds.isEmpty ? openNeeds.take(6).toList() : campaignNeeds;
    final visibleOpportunities = opportunities
        .where((opportunity) => opportunity.isOpen)
        .take(4)
        .toList(growable: false);
    final visibleUpdates = notifications.take(4).toList(growable: false);

    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: const AppBarTheme(
          backgroundColor: _HomeColors.background,
          foregroundColor: _HomeColors.text,
          elevation: 0,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _HomeColors.nav,
          indicatorColor: KanafPalette.seed,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? Colors.white : _HomeColors.muted,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? Colors.white : _HomeColors.muted,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
            );
          }),
        ),
      ),
      child: Scaffold(
        backgroundColor: _HomeColors.background,
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.tr('nav.profile'),
            onPressed: () =>
                Navigator.pushNamed(context, KanafRoutes.donorProfile),
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: _HomeColors.card,
              child: Icon(
                Icons.person_rounded,
                size: 20,
                color: KanafPalette.ember,
              ),
            ),
          ),
          title: Text(
            l10n.tr('app.name'),
            style: context.texts.headlineSmall?.copyWith(
              color: _HomeColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              tooltip: l10n.tr('home.searchTooltip'),
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
        body: _HomeBackdrop(
          child: RefreshIndicator(
            onRefresh: _refreshHome,
            color: KanafPalette.seed,
            backgroundColor: _HomeColors.card,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    KanafSpacing.pageInset,
                    KanafSpacing.md,
                    KanafSpacing.pageInset,
                    KanafSpacing.bottomSafeGutter,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _buildSlider(),
                      const SizedBox(height: KanafSpacing.xl),
                      _buildQuickActions(),
                      const SizedBox(height: KanafSpacing.xxl),
                      _HomeSection(
                        title: l10n.tr('home.urgentNeeds'),
                        actionLabel: featuredNeeds.isEmpty
                            ? null
                            : l10n.tr('home.viewAll'),
                        onAction: featuredNeeds.isEmpty
                            ? null
                            : () => Navigator.pushNamed(
                                  context,
                                  KanafRoutes.exploreOrphanages,
                                ),
                        child: _NeedStrip(
                          provider: provider,
                          needs: featuredNeeds,
                          emptyTitle: l10n.tr('home.emptyNeedsTitle'),
                          emptyMessage: l10n.tr('home.emptyNeedsMessage'),
                          onRetry: provider.fetchNeeds,
                        ),
                      ),
                      const SizedBox(height: KanafSpacing.xxl),
                      _HomeSection(
                        title: l10n.tr('home.campaignsTitle'),
                        actionLabel: visibleCampaigns.isEmpty
                            ? null
                            : l10n.tr('home.viewAll'),
                        onAction: visibleCampaigns.isEmpty
                            ? null
                            : () => Navigator.pushNamed(
                                  context,
                                  KanafRoutes.exploreOrphanages,
                                ),
                        child: _CampaignGrid(
                          provider: provider,
                          needs: visibleCampaigns,
                          onRetry: provider.fetchNeeds,
                        ),
                      ),
                      const SizedBox(height: KanafSpacing.xxl),
                      _HomeSection(
                        title: l10n.tr('home.volunteerOpportunitiesTitle'),
                        actionLabel: visibleOpportunities.isEmpty
                            ? null
                            : l10n.tr('home.viewAll'),
                        onAction: visibleOpportunities.isEmpty
                            ? null
                            : () => Navigator.pushNamed(
                                  context,
                                  KanafRoutes.volunteerSearch,
                                ),
                        child: _VolunteerStrip(
                          provider: provider,
                          opportunities: visibleOpportunities,
                          onRetry: () => provider.fetchVolunteerOpportunities(),
                        ),
                      ),
                      const SizedBox(height: KanafSpacing.xxl),
                      _HomeSection(
                        title: l10n.tr('home.latestUpdatesTitle'),
                        actionLabel: visibleUpdates.isEmpty
                            ? null
                            : l10n.tr('home.viewAll'),
                        onAction: visibleUpdates.isEmpty
                            ? null
                            : () => Navigator.pushNamed(
                                  context,
                                  KanafRoutes.donorNotifications,
                                ),
                        child: _UpdatesStrip(
                          provider: provider,
                          notifications: visibleUpdates,
                          onRetry: provider.fetchNotifications,
                        ),
                      ),
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
              itemCount: _sliderItemCount,
              itemBuilder: (context, index) => index == 0
                  ? const _QuranGivingBanner()
                  : Image.asset(
                      _sliderImages[index - _featuredBannerCount],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _ImageFallback(icon: Icons.image_outlined),
                    ),
            ),
          ),
        ),
        const SizedBox(height: KanafSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _sliderItemCount; i++)
              AnimatedContainer(
                duration: KanafDuration.standard,
                margin: const EdgeInsets.symmetric(horizontal: KanafSpacing.xs),
                width: i == _currentSlide ? 24 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _currentSlide
                      ? KanafPalette.seed
                      : Colors.white.withOpacity(0.12),
                  borderRadius: KanafRadii.pill,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.travel_explore_outlined,
            label: l10n.tr('home.exploreAction'),
            subtitle: l10n.tr('home.quickExploreSubtitle'),
            route: KanafRoutes.exploreOrphanages,
          ),
        ),
        const SizedBox(width: KanafSpacing.md),
        Expanded(
          child: _QuickAction(
            icon: Icons.inventory_2_outlined,
            label: l10n.tr('home.inkindDonation'),
            subtitle: l10n.tr('home.quickInkindSubtitle'),
            route: KanafRoutes.inkindDonation,
          ),
        ),
        const SizedBox(width: KanafSpacing.md),
        Expanded(
          child: _QuickAction(
            icon: Icons.payments_outlined,
            label: l10n.tr('home.financialDonation'),
            subtitle: l10n.tr('home.quickFinancialSubtitle'),
            route: KanafRoutes.financialDonation,
          ),
        ),
      ],
    );
  }

  static bool _isOpenNeed(NeedModel need) {
    final status = need.status.trim().toLowerCase();
    return status.isEmpty || status == 'open' || status == 'pending';
  }

  static bool _isUrgentNeed(NeedModel need) =>
      need.priority.trim().toLowerCase() == 'urgent';

  static int _unreadCount(List<Map<String, dynamic>> notifications) {
    return notifications.where((item) => item['is_read'] != true).length;
  }
}

abstract final class _HomeColors {
  static const Color background = Color(0xFF080604);
  static const Color card = Color(0xFF111111);
  static const Color cardSoft = Color(0xFF17120F);
  static const Color nav = Color(0xFF11100F);
  static const Color text = Color(0xFFF8F2ED);
  static const Color muted = Color(0xFFC3B5AA);
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: _HomeColors.background),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.85, -0.95),
                    radius: 1.2,
                    colors: [
                      KanafPalette.seed.withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _QuranGivingBanner extends StatelessWidget {
  const _QuranGivingBanner();

  static const String _backgroundAsset = 'assets/images/quran_giving_hero.png';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _backgroundAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) =>
              const _ImageFallback(icon: Icons.eco_outlined),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFFFFF4E7).withOpacity(0.78),
                const Color(0xFFFFE2C4).withOpacity(0.52),
                Colors.transparent,
              ],
              stops: const [0, 0.44, 0.76],
            ),
          ),
        ),
        Positioned(
          left: KanafSpacing.lg,
          top: KanafSpacing.md,
          bottom: KanafSpacing.md,
          width: 190,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: 230,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KanafSpacing.lg,
                      vertical: KanafSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: KanafPalette.seed.withOpacity(0.15),
                      borderRadius: KanafRadii.pill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_florist_rounded,
                          size: 15,
                          color: KanafPalette.brandInk,
                        ),
                        const SizedBox(width: KanafSpacing.xs),
                        Text(
                          l10n.tr('banner.title'),
                          style: context.texts.labelLarge?.copyWith(
                            color: KanafPalette.brandInk,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KanafSpacing.sm),
                  Text(
                    l10n.tr('banner.verse'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleSmall?.copyWith(
                      color: const Color(0xFF3A2519),
                      fontSize: 14,
                      height: 1.22,
                      fontWeight: FontWeight.w900,
                      fontFamily: l10n.isArabic ? 'Tajawal' : null,
                    ),
                  ),
                  const SizedBox(height: KanafSpacing.xxs),
                  Text(
                    l10n.tr('banner.intent'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelLarge?.copyWith(
                      color: const Color(0xFF3A2519),
                      fontSize: 12,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                      fontFamily: l10n.isArabic ? 'Tajawal' : null,
                    ),
                  ),
                  const SizedBox(height: KanafSpacing.xs),
                  Text(
                    l10n.tr('banner.source'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall?.copyWith(
                      color: const Color(0xFF75533E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: KanafSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _BannerValue(
                        icon: Icons.verified_user_outlined,
                        label: l10n.tr('banner.trust'),
                      ),
                      const _BannerDivider(),
                      _BannerValue(
                        icon: Icons.volunteer_activism_outlined,
                        label: l10n.tr('banner.giving'),
                      ),
                      const _BannerDivider(),
                      _BannerValue(
                        icon: Icons.groups_2_outlined,
                        label: l10n.tr('banner.community'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerValue extends StatelessWidget {
  const _BannerValue({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: KanafPalette.brandInk),
          const SizedBox(height: KanafSpacing.xxs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.texts.labelSmall?.copyWith(
              color: const Color(0xFF4E3425),
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerDivider extends StatelessWidget {
  const _BannerDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: KanafPalette.brandInk.withOpacity(0.22),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _HomeColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: KanafRadii.lg,
        side: BorderSide(color: KanafPalette.seed.withOpacity(0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: KanafSpacing.lg,
            horizontal: KanafSpacing.sm,
          ),
          child: Column(
            children: [
              Icon(icon, size: 29, color: KanafPalette.ember),
              const SizedBox(height: KanafSpacing.md),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.texts.titleSmall?.copyWith(
                  color: _HomeColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: KanafSpacing.xs),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.texts.labelSmall?.copyWith(
                  color: _HomeColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 34,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [KanafPalette.seed, KanafPalette.ember],
                ),
                borderRadius: KanafRadii.pill,
              ),
            ),
            const SizedBox(width: KanafSpacing.md),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.end,
                style: context.texts.titleLarge?.copyWith(
                  color: _HomeColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: KanafSpacing.md),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
        const SizedBox(height: KanafSpacing.md),
        child,
      ],
    );
  }
}

class _NeedStrip extends StatelessWidget {
  const _NeedStrip({
    required this.provider,
    required this.needs,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRetry,
  });

  final AppProvider provider;
  final List<NeedModel> needs;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (needs.isEmpty) {
      return _SectionState(
        isLoading: provider.isLoadingNeeds,
        errorMessage: provider.needsErrorMessage,
        title: emptyTitle,
        message: emptyMessage,
        icon: Icons.checklist_rtl_rounded,
        onRetry: onRetry,
      );
    }

    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: Directionality.of(context) == TextDirection.rtl,
        itemCount: needs.length,
        separatorBuilder: (_, __) => const SizedBox(width: KanafSpacing.md),
        itemBuilder: (context, index) => SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.82,
          child: _FeaturedNeedCard(need: needs[index]),
        ),
      ),
    );
  }
}

class _CampaignGrid extends StatelessWidget {
  const _CampaignGrid({
    required this.provider,
    required this.needs,
    required this.onRetry,
  });

  final AppProvider provider;
  final List<NeedModel> needs;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (needs.isEmpty) {
      return _SectionState(
        isLoading: provider.isLoadingNeeds,
        errorMessage: provider.needsErrorMessage,
        title: context.tr('home.noCampaignsTitle'),
        message: context.tr('home.noCampaignsMessage'),
        icon: Icons.campaign_outlined,
        onRetry: onRetry,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: needs.length.clamp(0, 6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: KanafSpacing.md,
        mainAxisSpacing: KanafSpacing.md,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) => _CampaignNeedCard(need: needs[index]),
    );
  }
}

class _VolunteerStrip extends StatelessWidget {
  const _VolunteerStrip({
    required this.provider,
    required this.opportunities,
    required this.onRetry,
  });

  final AppProvider provider;
  final List<VolunteerOpportunityModel> opportunities;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (opportunities.isEmpty) {
      return _SectionState(
        isLoading: provider.isLoading,
        errorMessage: provider.errorMessage,
        title: context.tr('home.noVolunteersTitle'),
        message: context.tr('home.noVolunteersMessage'),
        icon: Icons.volunteer_activism_outlined,
        onRetry: onRetry,
      );
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: Directionality.of(context) == TextDirection.rtl,
        itemCount: opportunities.length,
        separatorBuilder: (_, __) => const SizedBox(width: KanafSpacing.md),
        itemBuilder: (context, index) => SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.72,
          child: _VolunteerCard(opportunity: opportunities[index]),
        ),
      ),
    );
  }
}

class _UpdatesStrip extends StatelessWidget {
  const _UpdatesStrip({
    required this.provider,
    required this.notifications,
    required this.onRetry,
  });

  final AppProvider provider;
  final List<Map<String, dynamic>> notifications;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return _SectionState(
        isLoading: provider.isLoading,
        errorMessage: provider.errorMessage,
        title: context.tr('home.noUpdatesTitle'),
        message: context.tr('home.noUpdatesMessage'),
        icon: Icons.notifications_none_rounded,
        onRetry: onRetry,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < notifications.length; i++) ...[
          if (i > 0) const SizedBox(height: KanafSpacing.sm),
          _UpdateCard(data: notifications[i]),
        ],
      ],
    );
  }
}

class _FeaturedNeedCard extends StatelessWidget {
  const _FeaturedNeedCard({required this.need});

  final NeedModel need;

  @override
  Widget build(BuildContext context) {
    final progress = need.progress ?? 0;

    return Material(
      color: _HomeColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: KanafRadii.lg,
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openNeed(context, need),
        child: Row(
          children: [
            SizedBox(
              width: 128,
              height: double.infinity,
              child: _NeedImage(need: need, fallbackAsset: _needImage(need)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(KanafSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (need.priority == 'urgent') const _UrgentPill(),
                        const Spacer(),
                        Icon(need.icon, size: 19, color: KanafPalette.ember),
                      ],
                    ),
                    const SizedBox(height: KanafSpacing.sm),
                    Text(
                      need.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: context.texts.titleMedium?.copyWith(
                        color: _HomeColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.xs),
                    Text(
                      _needSubtitle(context, need),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: context.texts.bodySmall?.copyWith(
                        color: _HomeColors.muted,
                      ),
                    ),
                    const Spacer(),
                    _NeedProgress(need: need, progress: progress),
                    const SizedBox(height: KanafSpacing.sm),
                    FilledButton(
                      onPressed: () => _donateToNeed(context, need),
                      child: Text(context.tr('home.donateNow')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignNeedCard extends StatelessWidget {
  const _CampaignNeedCard({required this.need});

  final NeedModel need;

  @override
  Widget build(BuildContext context) {
    final progress = need.progress ?? 0;

    return Material(
      color: _HomeColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: KanafRadii.lg,
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openNeed(context, need),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _NeedImage(need: need, fallbackAsset: _needImage(need)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.76),
                        ],
                      ),
                    ),
                  ),
                  if (need.priority == 'urgent')
                    const PositionedDirectional(
                      top: KanafSpacing.sm,
                      start: KanafSpacing.sm,
                      child: _UrgentPill(),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(KanafSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    need.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: context.texts.titleSmall?.copyWith(
                      color: _HomeColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: KanafSpacing.xs),
                  Text(
                    _needSubtitle(context, need),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: context.texts.labelSmall?.copyWith(
                      color: _HomeColors.muted,
                    ),
                  ),
                  const SizedBox(height: KanafSpacing.sm),
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: Colors.white.withOpacity(0.10),
                    color: KanafPalette.ember,
                    borderRadius: KanafRadii.pill,
                  ),
                  const SizedBox(height: KanafSpacing.sm),
                  FilledButton(
                    onPressed: () => _donateToNeed(context, need),
                    child: Text(context.tr('home.donateNow')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolunteerCard extends StatelessWidget {
  const _VolunteerCard({required this.opportunity});

  final VolunteerOpportunityModel opportunity;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _HomeColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: KanafRadii.lg,
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          KanafRoutes.volunteerOpportunityDetails,
          arguments: opportunity.toRouteArguments(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KanafSpacing.md),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: KanafPalette.seed.withOpacity(0.18),
                  borderRadius: KanafRadii.md,
                ),
                child: Icon(opportunity.icon, color: KanafPalette.ember),
              ),
              const SizedBox(width: KanafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      opportunity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: context.texts.titleSmall?.copyWith(
                        color: _HomeColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.xs),
                    Text(
                      _opportunityMeta(context, opportunity),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: context.texts.labelSmall?.copyWith(
                        color: _HomeColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString().trim();
    final message = data['message']?.toString().trim();
    final isUnread = data['is_read'] != true;

    return Material(
      color: _HomeColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: KanafRadii.lg,
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.pushNamed(context, KanafRoutes.donorNotifications),
        child: Padding(
          padding: const EdgeInsets.all(KanafSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.chevron_left_rounded,
                color: _HomeColors.muted.withOpacity(0.8),
              ),
              const SizedBox(width: KanafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title == null || title.isEmpty
                          ? context.tr('notifications.defaultTitle')
                          : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: context.texts.titleSmall?.copyWith(
                        color: _HomeColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (message != null && message.isNotEmpty) ...[
                      const SizedBox(height: KanafSpacing.xs),
                      Text(
                        message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: context.texts.bodySmall?.copyWith(
                          color: _HomeColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: KanafSpacing.md),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: KanafPalette.seed.withOpacity(isUnread ? 0.22 : 0.12),
                  borderRadius: KanafRadii.md,
                ),
                child: Icon(
                  isUnread
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_rounded,
                  color: KanafPalette.ember,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeedProgress extends StatelessWidget {
  const _NeedProgress({required this.need, required this.progress});

  final NeedModel need;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final format = NumberFormat.decimalPattern(locale);
    final collected = format.format(need.fulfilledQuantity);
    final percent = (progress.clamp(0.0, 1.0) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: KanafRadii.pill,
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: Colors.white.withOpacity(0.10),
            color: KanafPalette.ember,
          ),
        ),
        const SizedBox(height: KanafSpacing.xs),
        Row(
          children: [
            Text(
              '$percent%',
              style: context.texts.labelSmall?.copyWith(
                color: KanafPalette.ember,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                context.tr(
                  'home.collectedOf',
                  args: {
                    'collected': collected,
                    'target': need.requiredQuantity,
                  },
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: context.texts.labelSmall?.copyWith(
                  color: _HomeColors.muted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NeedImage extends StatelessWidget {
  const _NeedImage({required this.need, required this.fallbackAsset});

  final NeedModel need;
  final String fallbackAsset;

  @override
  Widget build(BuildContext context) {
    final imageUrl = need.imageUrl?.trim();
    if (imageUrl != null && imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _LocalNeedImage(asset: fallbackAsset),
      );
    }
    return _LocalNeedImage(asset: fallbackAsset);
  }
}

class _LocalNeedImage extends StatelessWidget {
  const _LocalNeedImage({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const _ImageFallback(icon: Icons.image_outlined),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _HomeColors.cardSoft,
      child: Icon(icon, color: KanafPalette.ember, size: 42),
    );
  }
}

class _UrgentPill extends StatelessWidget {
  const _UrgentPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KanafSpacing.sm,
        vertical: KanafSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: KanafRadii.pill,
      ),
      child: Text(
        context.tr('home.urgent'),
        style: context.texts.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionState extends StatelessWidget {
  const _SectionState({
    required this.isLoading,
    required this.errorMessage,
    required this.title,
    required this.message,
    required this.icon,
    required this.onRetry,
  });

  final bool isLoading;
  final String? errorMessage;
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Column(
        children: [
          KanafSkeleton.card(),
          SizedBox(height: KanafSpacing.md),
          KanafSkeleton.card(),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KanafSpacing.xxl),
      decoration: BoxDecoration(
        color: _HomeColors.card,
        borderRadius: KanafRadii.lg,
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: KanafPalette.seed.withOpacity(0.14),
              borderRadius: KanafRadii.lg,
            ),
            child: Icon(icon, color: KanafPalette.ember, size: 34),
          ),
          const SizedBox(height: KanafSpacing.lg),
          Text(
            errorMessage ?? title,
            textAlign: TextAlign.center,
            style: context.texts.titleMedium?.copyWith(
              color: _HomeColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: KanafSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(color: _HomeColors.muted),
          ),
          const SizedBox(height: KanafSpacing.lg),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.tr('common.retry')),
          ),
        ],
      ),
    );
  }
}

String _needSubtitle(BuildContext context, NeedModel need) {
  final home = need.careHomeName?.trim();
  final location = need.careHomeLocation?.trim();
  if (home != null &&
      home.isNotEmpty &&
      location != null &&
      location.isNotEmpty) {
    return '$home - $location';
  }
  if (home != null && home.isNotEmpty) return home;
  if (location != null && location.isNotEmpty) return location;
  return need.categoryLabel;
}

String _opportunityMeta(
  BuildContext context,
  VolunteerOpportunityModel opportunity,
) {
  final place = opportunity.location.trim().isNotEmpty
      ? opportunity.location.trim()
      : opportunity.careHomeLocation?.trim();
  final count = context.tr(
    'home.volunteersCount',
    args: {'count': opportunity.requiredVolunteers},
  );
  if (place != null && place.isNotEmpty) return '$place - $count';
  return count;
}

String _needImage(NeedModel need) {
  return switch (need.category) {
    'food' => 'assets/images/a.png',
    'clothes' => 'assets/images/c.png',
    'medical' => 'assets/images/d.png',
    'education' => 'assets/images/b.png',
    _ => 'assets/images/image2.png',
  };
}

void _openNeed(BuildContext context, NeedModel need) {
  Navigator.pushNamed(
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
  );
}

void _donateToNeed(BuildContext context, NeedModel need) {
  Navigator.pushNamed(
    context,
    KanafRoutes.financialDonation,
    arguments: <String, dynamic>{
      'need_id': need.id,
      'name': need.title,
      'address': need.careHomeLocation ?? need.careHomeName ?? '',
    },
  );
}
