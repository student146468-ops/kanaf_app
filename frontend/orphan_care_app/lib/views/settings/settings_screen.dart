import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/donation_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../services/api_service.dart';
import '../../theme/kanaf_locale_controller.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_theme_controller.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../l10n/kanaf_localizations.dart';

/// ط´ط§ط´ط© ط§ظ„ط¥ط¹ط¯ط§ط¯ط§طھ.
///
/// ط£ظڈطµظ„ط­ ظپظٹظ‡ط§ ط¹ظٹط¨ط§ظ† ط­ظ‚ظٹظ‚ظٹط§ظ† ط¨ط¬ط§ظ†ط¨ ط§ظ„ظ…ط¸ظ‡ط±:
/// * **طھط³ط¬ظٹظ„ ط§ظ„ط®ط±ظˆط¬ ظƒط§ظ† ظ„ط§ ظٹظ…ط³ط­ ط§ظ„طھظˆظƒظ†** â€” ظƒط§ظ† ظٹظ†طھظ‚ظ„ ط¥ظ„ظ‰ ط´ط§ط´ط© ط§ظ„ط¯ط®ظˆظ„
///   ظپظ‚ط·طŒ ظپظٹط¨ظ‚ظ‰ ط§ظ„ظ…ط³طھط®ط¯ظ… ظ…طµط§ط¯ظژظ‚ط§ظ‹ ظپط¹ظ„ظٹط§ظ‹ ظˆط£ظٹ ط·ظ„ط¨ ظ„ط§ط­ظ‚ ظٹظ†ط¬ط­ ط¨ط§ط³ظ…ظ‡.
/// * **ظ…ظپطھط§ط­ ط§ظ„ظˆط¶ط¹ ط§ظ„ط¯ط§ظƒظ† ظƒط§ظ† ط²ط®ط±ظپظٹط§ظ‹** â€” ظٹظ‚ظ„ط¨ `bool` ظ…ط­ظ„ظٹط§ظ‹ ط¨ظ„ط§ ط£ط«ط±.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoggingOut = false;
  final Set<int> _cancelRequested = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.currentUser.isEmpty && !provider.isLoading) {
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

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings.title'))),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              KanafSpacing.pageInset,
              KanafSpacing.lg,
              KanafSpacing.pageInset,
              KanafSpacing.xxxl,
            ),
            children: [
              KanafStaggeredEntrance(
                index: 0,
                child: _AccountHeader(user: user),
              ),
              const SizedBox(height: KanafSpacing.xxl),
              KanafStaggeredEntrance(
                index: 1,
                child: _buildSection(
                  title: context.tr('settings.accountSecurity'),
                  children: [
                    _SettingsTile(
                      icon: Icons.alternate_email_rounded,
                      title: context.tr('settings.changeEmail'),
                      subtitle: user['email']?.toString() ??
                          context.tr('settings.changeEmailSubtitle'),
                      onTap: () => Navigator.pushNamed(
                        context,
                        KanafRoutes.changeEmail,
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: context.tr('settings.changePassword'),
                      subtitle: context.tr('settings.changePasswordSubtitle'),
                      onTap: () => Navigator.pushNamed(
                        context,
                        KanafRoutes.changePassword,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KanafSpacing.lg),
              KanafStaggeredEntrance(
                index: 2,
                child: _buildSection(
                  title: context.tr('settings.appearanceLanguage'),
                  children: [
                    // ط§ظ„ظ…ظپطھط§ط­ ظ…ط±ط¨ظˆط· ط¨ظ…طھط­ظƒظ… ط­ظ‚ظٹظ‚ظٹ ظٹط­ظپط¸ ط§ظ„ط§ط®طھظٹط§ط±.
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: KanafThemeController.instance,
                      builder: (context, mode, _) => SwitchListTile(
                        value: mode == ThemeMode.dark,
                        onChanged: KanafThemeController.instance.setDark,
                        secondary: const Icon(Icons.dark_mode_outlined),
                        title: Text(context.tr('settings.darkMode')),
                        subtitle: Text(context.tr('settings.darkModeSubtitle')),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: KanafSpacing.lg,
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: KanafSpacing.lg),
                    ValueListenableBuilder<Locale>(
                      valueListenable: KanafLocaleController.instance,
                      builder: (context, locale, _) {
                        return _SettingsTile(
                          icon: Icons.language_rounded,
                          title: context.tr('settings.language'),
                          subtitle: locale.languageCode == 'en'
                              ? context.tr('settings.english')
                              : context.tr('settings.arabic'),
                          onTap: _showLanguageDialog,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KanafSpacing.lg),
              KanafStaggeredEntrance(
                index: 3,
                child: _MonthlyDonationsSection(
                  donations: user.isEmpty ? const [] : provider.myDonations,
                  cancelRequested: _cancelRequested,
                  onCancel: _requestMonthlyCancel,
                ),
              ),
              const SizedBox(height: KanafSpacing.lg),
              KanafStaggeredEntrance(
                index: 4,
                child: _buildSection(
                  title: context.tr('settings.aboutSection'),
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: context.tr('settings.aboutTitle'),
                      subtitle: context.tr('settings.aboutSubtitle'),
                      onTap: () => Navigator.pushNamed(
                        context,
                        KanafRoutes.aboutApp,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KanafSpacing.xxxl),
              KanafStaggeredEntrance(index: 5, child: _buildLogout()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KanafSectionHeader(title: title),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(padding: EdgeInsets.zero, child: Column(children: children)),
      ],
    );
  }

  Widget _buildLogout() {
    final scheme = context.colors;
    return OutlinedButton.icon(
      onPressed: _isLoggingOut ? null : _confirmLogout,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.error,
        side: BorderSide(color: scheme.error.withOpacity(0.5)),
      ),
      icon: _isLoggingOut
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout_rounded),
      label: Text(_isLoggingOut
          ? context.tr('settings.loggingOut')
          : context.tr('settings.logout')),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('settings.logoutConfirmTitle')),
        content: Text(context.tr('settings.logoutConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('settings.logoutAction')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _logout();
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    final provider = AppProviderScope.of(context);

    // ظ…ط³ط­ ط§ظ„طھظˆظƒظ† ط£ظˆظ„ط§ظ‹: ظ„ظˆ ط§ظ†طھظ‚ظ„ظ†ط§ ظ‚ط¨ظ„ ط§ظ„ظ…ط³ط­ ظ„ط¨ظ‚ظٹطھ ط§ظ„ط¬ظ„ط³ط© طµط§ظ„ط­ط©طŒ
    // ظˆظ„ط£ط¹ط§ط¯طھ ط´ط§ط´ط© ط§ظ„ط¨ط¯ط§ظٹط© ط§ظ„ظ…ط³طھط®ط¯ظ… ط¥ظ„ظ‰ ط­ط³ط§ط¨ظ‡ ط¹ظ†ط¯ ط¥ط¹ط§ط¯ط© ط§ظ„طھط´ط؛ظٹظ„.
    await _apiService.logout();
    // ظˆطھظپط±ظٹط؛ ط§ظ„ط°ط§ظƒط±ط© ط­طھظ‰ ظ„ط§ ظٹط±ظ‰ ط§ظ„ظ…ط³طھط®ط¯ظ… ط§ظ„طھط§ظ„ظٹ ط¨ظٹط§ظ†ط§طھ ط§ظ„ط³ط§ط¨ظ‚.
    provider.clearAll();

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      KanafRoutes.login,
      (route) => false,
    );
  }

  Future<void> _showLanguageDialog() async {
    final current = KanafLocaleController.instance.value.languageCode;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('settings.languageDialog')),
        contentPadding: const EdgeInsets.only(top: KanafSpacing.sm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'ar',
              groupValue: current,
              onChanged: (value) => Navigator.pop(dialogContext, value),
              secondary: const Icon(Icons.translate_rounded),
              title: Text(context.tr('settings.arabic')),
              subtitle: Text(context.tr('settings.arabicSubtitle')),
            ),
            RadioListTile<String>(
              value: 'en',
              groupValue: current,
              onChanged: (value) => Navigator.pop(dialogContext, value),
              secondary: const Icon(Icons.language_rounded),
              title: Text(context.tr('settings.english')),
              subtitle: Text(context.tr('settings.englishSubtitle')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('common.cancel')),
          ),
        ],
      ),
    );

    if (selected == null || !mounted) return;
    await KanafLocaleController.instance.setLocale(Locale(selected));
  }

  Future<void> _requestMonthlyCancel(DonationModel donation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('settings.cancelMonthlyTitle')),
        content: Text(context.tr(
          'settings.cancelMonthlyMessage',
          args: {'id': donation.id},
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('common.back')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('settings.cancelMonthlyRequest')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelRequested.add(donation.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr('settings.cancelMonthlyQueued'),
        ),
      ),
    );
  }
}

class _MonthlyDonationsSection extends StatelessWidget {
  const _MonthlyDonationsSection({
    required this.donations,
    required this.cancelRequested,
    required this.onCancel,
  });

  final List<DonationModel> donations;
  final Set<int> cancelRequested;
  final ValueChanged<DonationModel> onCancel;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final amountFormat = NumberFormat.decimalPattern(localeCode);
    final dateFormat = DateFormat('d MMMM y', localeCode);
    final monthly = donations.where(_isRecurring).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KanafSectionHeader(
          title: context.tr('settings.monthlyDonations'),
          subtitle: context.tr('settings.monthlyDonationsSubtitle'),
        ),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(
          padding: EdgeInsets.zero,
          child: monthly.isEmpty
              ? ListTile(
                  leading: const Icon(Icons.event_repeat_rounded),
                  title: Text(context.tr('settings.noMonthlyDonations')),
                  subtitle:
                      Text(context.tr('settings.noMonthlyDonationsSubtitle')),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: KanafSpacing.lg,
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < monthly.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: KanafSpacing.lg),
                      _MonthlyDonationTile(
                        donation: monthly[i],
                        amountFormat: amountFormat,
                        dateFormat: dateFormat,
                        cancelRequested:
                            cancelRequested.contains(monthly[i].id),
                        onCancel: () => onCancel(monthly[i]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  static bool _isRecurring(DonationModel donation) {
    final mode = donation.donationMode?.toLowerCase() ?? '';
    return mode.contains('month') || mode.contains('ط´ظ‡ط±ظٹ');
  }
}

class _MonthlyDonationTile extends StatelessWidget {
  const _MonthlyDonationTile({
    required this.donation,
    required this.amountFormat,
    required this.dateFormat,
    required this.cancelRequested,
    required this.onCancel,
  });

  final DonationModel donation;
  final NumberFormat amountFormat;
  final DateFormat dateFormat;
  final bool cancelRequested;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final amount = donation.amount;
    final nextDate = _nextDeductionDate(donation);
    final description = donation.needTitle ??
        donation.description ??
        context.tr('settings.monthlyDefaultDescription');

    return ListTile(
      leading: const Icon(Icons.event_repeat_rounded),
      title: Text(
        amount == null
            ? context.tr('settings.monthlyDonation')
            : context.tr('settings.monthlyAmount', args: {
                'amount': amountFormat.format(amount),
              }),
      ),
      subtitle: Text(
        context.tr('settings.nextDeductionLine', args: {
          'description': description,
          'date': dateFormat.format(nextDate),
        }),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: cancelRequested
          ? const Icon(Icons.pending_actions_rounded)
          : TextButton(
              onPressed: onCancel,
              child: Text(context.tr('settings.cancelMonthly')),
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: KanafSpacing.lg),
    );
  }

  static DateTime _nextDeductionDate(DonationModel donation) {
    final base = donation.donationDate ?? donation.createdAt ?? DateTime.now();
    var next = DateTime(base.year, base.month + 1, base.day);
    final now = DateTime.now();
    while (!next.isAfter(now)) {
      next = DateTime(next.year, next.month + 1, next.day);
    }
    return next;
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final name = (user['first_name']?.toString().trim().isNotEmpty ?? false)
        ? user['first_name'].toString()
        : (user['username']?.toString() ?? 'ط­ط³ط§ط¨ظٹ');
    final email = user['email']?.toString() ?? '';

    return KanafCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              // ط£ظˆظ„ ط­ط±ظپ ظ…ظ† ط§ظ„ط§ط³ظ… ظƒط¨ط¯ظٹظ„ ط¹ظ† طµظˆط±ط© ط؛ظٹط± ظ…ظˆط¬ظˆط¯ط©.
              name.isEmpty ? 'طں' : name.characters.first,
              style: context.texts.titleLarge?.copyWith(
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
                  style: context.texts.titleMedium,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: KanafSpacing.xxs),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_left_rounded, size: 22),
      onTap: onTap,
      enabled: onTap != null,
      contentPadding: const EdgeInsets.symmetric(horizontal: KanafSpacing.lg),
    );
  }
}
