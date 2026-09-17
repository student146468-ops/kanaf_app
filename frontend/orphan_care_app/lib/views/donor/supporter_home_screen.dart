import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/kanaf_localizations.dart';
import '../../models/need_model.dart';
import '../../models/volunteer_opportunity_model.dart';
import '../../providers/app_provider.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_nav_shell.dart';
import '../../widgets/kanaf_media_content_card.dart';
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
      provider.fetchVolunteerOpportunities(notifyLoading: false);
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
    final featuredNeeds = urgentNeeds.isNotEmpty ? urgentNeeds : openNeeds;
    final campaignNeeds =
        openNeeds.where((need) => !_isUrgentNeed(need)).toList(growable: false);
    final visibleCampaigns = campaignNeeds.isEmpty ? openNeeds : campaignNeeds;
    final visibleOpportunities = opportunities
        .where((opportunity) => opportunity.isOpen)
        .toList(growable: false);
    final visibleUpdates = notifications.take(4).toList(growable: false);
    final colors = _HomeColors.of(context);
    final appBarBackground =
        Theme.of(context).appBarTheme.backgroundColor ?? colors.background;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: appBarBackground,
        foregroundColor: colors.text,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          tooltip: l10n.tr('nav.profile'),
          onPressed: () =>
              Navigator.pushNamed(context, KanafRoutes.donorProfile),
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: colors.card,
            child: const Icon(
              Icons.person_rounded,
              size: 20,
              color: KanafPalette.ember,
            ),
          ),
        ),
        title: Text(
          l10n.tr('app.name'),
          style: context.texts.headlineSmall?.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          const KanafRoleSwitchButton(currentRole: 'donor'),
          IconButton(
            tooltip: l10n.tr('home.searchTooltip'),
            onPressed: () =>
                Navigator.pushNamed(context, KanafRoutes.searchFilter),
            icon: const Icon(Icons.search_rounded),
          ),
          KanafNotificationButton(
            unreadCount: provider.unreadNotificationsCount,
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
          backgroundColor: colors.card,
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
    );
  }

  Widget _buildSlider() {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final bannerHeight = _clampDouble(
              constraints.maxWidth * 0.56,
              212,
              280,
            );
            return SizedBox(
              height: bannerHeight,
              child: ClipRRect(
                borderRadius: KanafRadii.lg,
                child: PageView.builder(
                  controller: _sliderController,
                  onPageChanged: (index) =>
                      setState(() => _currentSlide = index),
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
            );
          },
        ),
        const SizedBox(height: KanafSpacing.md),
        Builder(
          builder: (context) {
            final colors = _HomeColors.of(context);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _sliderItemCount; i++)
                  AnimatedContainer(
                    duration: KanafDuration.standard,
                    margin: const EdgeInsets.symmetric(
                      horizontal: KanafSpacing.xs,
                    ),
                    width: i == _currentSlide ? 24 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _currentSlide
                          ? KanafPalette.seed
                          : colors.inactiveIndicator,
                      borderRadius: KanafRadii.pill,
                    ),
                  ),
              ],
            );
          },
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
}

abstract final class _HomeColors {
  static _HomeColorSet of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return _HomeColorSet(
      background: scheme.surface,
      card: scheme.surfaceContainerLow,
      cardSoft: scheme.surfaceContainerHigh,
      text: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      border: scheme.outlineVariant.withValues(alpha: 0.6),
      progressTrack: scheme.surfaceContainerHighest,
      inactiveIndicator:
          scheme.outlineVariant.withValues(alpha: isDark ? 0.55 : 0.8),
    );
  }
}

class _HomeColorSet {
  const _HomeColorSet({
    required this.background,
    required this.card,
    required this.cardSoft,
    required this.text,
    required this.muted,
    required this.border,
    required this.progressTrack,
    required this.inactiveIndicator,
  });

  final Color background;
  final Color card;
  final Color cardSoft;
  final Color text;
  final Color muted;
  final Color border;
  final Color progressTrack;
  final Color inactiveIndicator;
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = _HomeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final intensity = isDark ? 0.16 : 0.26;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.background),
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
                      KanafPalette.ember.withValues(alpha: intensity),
                      KanafPalette.ember.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-1, -0.75),
                    radius: 1.1,
                    colors: [
                      KanafPalette.seed.withValues(alpha: intensity * 0.7),
                      KanafPalette.seed.withValues(alpha: 0),
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
    final verseText =
        '${l10n.tr('banner.verse')} ۝ ${l10n.tr('banner.intent')}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPanelWidth = _clampDouble(
          constraints.maxWidth * 0.58,
          205,
          370,
        );
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
                    const Color(0xFFFFF4E7).withValues(alpha: 0.90),
                    const Color(0xFFFFE8CF).withValues(alpha: 0.70),
                    const Color(0xFFFFE0BD).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.48, 0.66, 0.84],
                ),
              ),
            ),
            Positioned(
              left: KanafSpacing.md,
              top: KanafSpacing.sm,
              bottom: KanafSpacing.sm,
              width: textPanelWidth,
              child: Align(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 328,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KanafSpacing.lg,
                            vertical: KanafSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: KanafPalette.seed.withValues(alpha: 0.14),
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
                                  fontWeight: FontWeight.w800,
                                  fontFamily: l10n.isArabic ? 'Tajawal' : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: KanafSpacing.sm),
                        Text(
                          verseText,
                          textAlign: TextAlign.center,
                          textDirection:
                              l10n.isArabic ? TextDirection.rtl : null,
                          style: context.texts.titleSmall?.copyWith(
                            color: const Color(0xFF3A2519),
                            fontSize: l10n.isArabic ? 15.5 : 13.5,
                            height: l10n.isArabic ? 1.45 : 1.32,
                            fontWeight: FontWeight.w400,
                            fontFamily: l10n.isArabic ? 'Cairo' : null,
                          ),
                        ),
                        const SizedBox(height: KanafSpacing.xs),
                        Text(
                          l10n.tr('banner.source'),
                          textAlign: TextAlign.center,
                          style: context.texts.labelMedium?.copyWith(
                            color: const Color(0xFF75533E),
                            fontWeight: FontWeight.w600,
                            fontFamily: l10n.isArabic ? 'Tajawal' : null,
                          ),
                        ),
                        const SizedBox(height: KanafSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _BannerValue(
                              icon: Icons.groups_2_outlined,
                              label: l10n.tr('banner.community'),
                            ),
                            const _BannerDivider(),
                            _BannerValue(
                              icon: Icons.volunteer_activism_outlined,
                              label: l10n.tr('banner.giving'),
                            ),
                            const _BannerDivider(),
                            _BannerValue(
                              icon: Icons.verified_user_outlined,
                              label: l10n.tr('banner.trust'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
      color: KanafPalette.brandInk.withValues(alpha: 0.22),
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
    final colors = _HomeColors.of(context);
    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: KanafRadii.lg,
        side: BorderSide(color: KanafPalette.seed.withValues(alpha: 0.28)),
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
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: KanafSpacing.xs),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.texts.labelSmall?.copyWith(color: colors.muted),
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
    final colors = _HomeColors.of(context);
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
                textAlign: TextAlign.start,
                style: context.texts.titleLarge?.copyWith(
                  color: colors.text,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final cardWidth = maxWidth <= 430
            ? maxWidth
            : _clampDouble(maxWidth * 0.78, 360, 460);
        final stripHeight = _clampDouble(cardWidth * 0.66, 236, 288);
        return SizedBox(
          height: stripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            reverse: Directionality.of(context) == TextDirection.rtl,
            clipBehavior: Clip.hardEdge,
            itemCount: needs.length,
            separatorBuilder: (_, __) => const SizedBox(width: KanafSpacing.md),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: KanafMediaContentCard.need(
                context: context,
                need: needs[index],
                onTap: () => _openNeed(context, needs[index]),
                onDonate: () => _donateToNeed(context, needs[index]),
                onInkindDonate: () =>
                    _donateInKindToNeed(context, needs[index]),
              ),
            ),
          ),
        );
      },
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

    return Column(
      children: [
        for (var i = 0; i < needs.length; i++) ...[
          if (i > 0) const SizedBox(height: KanafSpacing.md),
          KanafMediaContentCard.need(
            context: context,
            need: needs[i],
            onTap: () => _openNeed(context, needs[i]),
            onDonate: () => _donateToNeed(context, needs[i]),
            onInkindDonate: () => _donateInKindToNeed(context, needs[i]),
          ),
        ],
      ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _clampDouble(constraints.maxWidth * 0.86, 320, 440);
        final height = _clampDouble(width * 0.66, 236, 288);
        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            reverse: Directionality.of(context) == TextDirection.rtl,
            itemCount: opportunities.length,
            separatorBuilder: (_, __) => const SizedBox(width: KanafSpacing.md),
            itemBuilder: (context, index) => SizedBox(
              width: width,
              child: KanafMediaContentCard.opportunity(
                context: context,
                opportunity: opportunities[index],
                onTap: () => Navigator.pushNamed(
                  context,
                  KanafRoutes.volunteerOpportunityDetails,
                  arguments: opportunities[index].toRouteArguments(),
                ),
                onApply: () => Navigator.pushNamed(
                  context,
                  KanafRoutes.applyOpportunity,
                  arguments: opportunities[index].toRouteArguments(),
                ),
              ),
            ),
          ),
        );
      },
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

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString().trim();
    final message = data['message']?.toString().trim();
    final isUnread = data['is_read'] != true;
    final colors = _HomeColors.of(context);

    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: KanafRadii.lg,
        side: BorderSide(color: colors.border),
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
                color: colors.muted.withValues(alpha: 0.8),
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
                        color: colors.text,
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
                          color: colors.muted,
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
                  color: KanafPalette.seed
                      .withValues(alpha: isUnread ? 0.22 : 0.12),
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

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = _HomeColors.of(context);
    return ColoredBox(
      color: colors.cardSoft,
      child: Icon(icon, color: KanafPalette.ember, size: 42),
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
    final colors = _HomeColors.of(context);
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
        color: colors.card,
        borderRadius: KanafRadii.lg,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: KanafPalette.seed.withValues(alpha: 0.14),
              borderRadius: KanafRadii.lg,
            ),
            child: Icon(icon, color: KanafPalette.ember, size: 34),
          ),
          const SizedBox(height: KanafSpacing.lg),
          Text(
            errorMessage ?? title,
            textAlign: TextAlign.center,
            style: context.texts.titleMedium?.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: KanafSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(color: colors.muted),
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

double _clampDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
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

void _donateInKindToNeed(BuildContext context, NeedModel need) {
  Navigator.pushNamed(
    context,
    KanafRoutes.inkindDonation,
    arguments: <String, dynamic>{'need_id': need.id},
  );
}
