import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/donation_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_nav_shell.dart';
import '../../l10n/kanaf_localizations.dart';

/// حساب المتبرع.
///
/// أُعيد بناؤها على Material 3 وربطت بشريط التنقل السفلي. الإحصاءات
/// تُحسب من الحالات الإنجليزية التي يعيدها الخادم فعلاً — الحساب
/// السابق كان يبحث عن نصوص عربية («مكتمل»، «استلام») لا يرسلها
/// الخادم إطلاقاً، فكان عدّاد «المكتملة» صفراً دائماً.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.currentUser.isEmpty) {
        provider.fetchCurrentUser(notifyLoading: false);
      }
      if (provider.myDonations.isEmpty && !provider.isLoading) {
        provider.fetchMyDonations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final user = provider.currentUser;
    final donations = provider.myDonations;
    final stats = _DonationStats.from(donations);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('common.profile')),
        actions: [
          IconButton(
            tooltip: context.tr('common.settings'),
            onPressed: () => Navigator.pushNamed(context, KanafRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavigationBar: const KanafNavBar(
        destinations: KanafNavDestinations.donor,
        currentIndex: 3,
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () async {
              await provider.fetchCurrentUser(notifyLoading: false);
              await provider.fetchMyDonations();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                KanafSpacing.pageInset,
                KanafSpacing.lg,
                KanafSpacing.pageInset,
                KanafSpacing.xxxl,
              ),
              children: [
                KanafStaggeredEntrance(
                  index: 0,
                  child: _ProfileHeader(user: user),
                ),
                const SizedBox(height: KanafSpacing.xxl),
                KanafStaggeredEntrance(
                  index: 1,
                  child: _buildStats(stats),
                ),
                const SizedBox(height: KanafSpacing.xxl),
                KanafStaggeredEntrance(index: 2, child: _buildMenu()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats(_DonationStats stats) {
    final semantic = context.semantic;
    final locale = Localizations.localeOf(context).languageCode;
    final numberFormat = NumberFormat.decimalPattern(locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KanafSectionHeader(
          title: context.tr('profile.impactTitle'),
          subtitle: context.tr('profile.impactSubtitle'),
        ),
        const SizedBox(height: KanafSpacing.md),
        Row(
          children: [
            Expanded(
              child: KanafStatTile(
                label: context.tr('donation.total'),
                value: numberFormat.format(stats.total),
                icon: Icons.volunteer_activism_outlined,
              ),
            ),
            const SizedBox(width: KanafSpacing.md),
            Expanded(
              child: KanafStatTile(
                label: context.tr('donation.completed'),
                value: numberFormat.format(stats.completed),
                icon: Icons.check_circle_outline_rounded,
                accent: semantic.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: KanafSpacing.md),
        Row(
          children: [
            Expanded(
              child: KanafStatTile(
                label: context.tr('donation.pending'),
                value: numberFormat.format(stats.pending),
                icon: Icons.hourglass_top_rounded,
                accent: semantic.warning,
              ),
            ),
            const SizedBox(width: KanafSpacing.md),
            Expanded(
              child: KanafStatTile(
                label: context.tr('donation.totalFinancial'),
                value:
                    '${numberFormat.format(stats.totalAmount)} ${context.tr('common.lydShort')}',
                icon: Icons.payments_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KanafSectionHeader(title: context.tr('profile.accountManagement')),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MenuTile(
                icon: Icons.receipt_long_outlined,
                title: context.tr('donation.historyTitle'),
                subtitle: context.tr('profile.donationHistorySubtitle'),
                route: KanafRoutes.donationHistory,
              ),
              const Divider(height: 1, indent: KanafSpacing.lg),
              _MenuTile(
                icon: Icons.notifications_outlined,
                title: context.tr('common.notifications'),
                subtitle: context.tr('profile.notificationsSubtitle'),
                route: KanafRoutes.donorNotifications,
              ),
              const Divider(height: 1, indent: KanafSpacing.lg),
              _MenuTile(
                icon: Icons.alternate_email_rounded,
                title: context.tr('settings.changeEmail'),
                subtitle: context.tr('profile.changeEmailSubtitle'),
                route: KanafRoutes.changeEmail,
              ),
              const Divider(height: 1, indent: KanafSpacing.lg),
              _MenuTile(
                icon: Icons.lock_outline_rounded,
                title: context.tr('settings.changePassword'),
                subtitle: context.tr('profile.changePasswordSubtitle'),
                route: KanafRoutes.changePassword,
              ),
              const Divider(height: 1, indent: KanafSpacing.lg),
              _MenuTile(
                icon: Icons.settings_outlined,
                title: context.tr('common.settings'),
                subtitle: context.tr('profile.settingsSubtitle'),
                route: KanafRoutes.settings,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// إحصاءات مشتقة من قائمة التبرعات.
class _DonationStats {
  const _DonationStats({
    required this.total,
    required this.completed,
    required this.pending,
    required this.totalAmount,
  });

  factory _DonationStats.from(List<DonationModel> donations) {
    var completed = 0;
    var amount = 0.0;

    for (final donation in donations) {
      // الخادم يرسل الحالات بالإنجليزية (`STATUS_CHOICES`)؛ المطابقة
      // بالعربية كانت تفشل دائماً وتُبقي العدّاد صفراً.
      final status = donation.status.trim().toLowerCase();
      if (status == 'completed' ||
          status == 'accepted' ||
          status == 'approved') {
        completed++;
      }
      amount += donation.amount ?? 0;
    }

    return _DonationStats(
      total: donations.length,
      completed: completed,
      pending: donations.length - completed,
      totalAmount: amount,
    );
  }

  final int total;
  final int completed;
  final int pending;
  final double totalAmount;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final name = _firstNonEmpty(
      user,
      const ['first_name', 'full_name', 'name', 'username'],
      fallback: context.tr('role.donor'),
    );
    final email = _firstNonEmpty(user, const ['email'], fallback: '');
    final phone = _firstNonEmpty(user, const ['phone_number'], fallback: '');

    return KanafCard(
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  name.characters.first,
                  style: context.texts.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: KanafSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleLarge,
                    ),
                    const SizedBox(height: KanafSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KanafSpacing.md,
                        vertical: KanafSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.12),
                        borderRadius: KanafRadii.pill,
                      ),
                      child: Text(
                        context.tr('role.donor'),
                        style: context.texts.labelSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (email.isNotEmpty || phone.isNotEmpty) ...[
            const Divider(height: KanafSpacing.xxl),
            if (email.isNotEmpty)
              KanafDetailRow(label: context.tr('profile.email'), value: email),
            if (phone.isNotEmpty)
              KanafDetailRow(label: context.tr('profile.phone'), value: phone),
          ],
        ],
      ),
    );
  }

  static String _firstNonEmpty(
    Map<String, dynamic> source,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = source[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_left_rounded, size: 22),
      onTap: () => Navigator.pushNamed(context, route),
      contentPadding: const EdgeInsets.symmetric(horizontal: KanafSpacing.lg),
    );
  }
}
