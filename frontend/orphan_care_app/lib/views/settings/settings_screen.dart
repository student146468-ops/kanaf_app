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

/// شاشة الإعدادات.
///
/// أُصلح فيها عيبان حقيقيان بجانب المظهر:
/// * **تسجيل الخروج كان لا يمسح التوكن** — كان ينتقل إلى شاشة الدخول
///   فقط، فيبقى المستخدم مصادَقاً فعلياً وأي طلب لاحق ينجح باسمه.
/// * **مفتاح الوضع الداكن كان زخرفياً** — يقلب `bool` محلياً بلا أثر.
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
      appBar: AppBar(title: const Text('الإعدادات')),
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
                  title: 'الحساب والأمان',
                  children: [
                    _SettingsTile(
                      icon: Icons.alternate_email_rounded,
                      title: 'تغيير البريد الإلكتروني',
                      subtitle:
                          user['email']?.toString() ?? 'إدارة بريد الحساب',
                      onTap: () => Navigator.pushNamed(
                        context,
                        KanafRoutes.changeEmail,
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'تغيير كلمة المرور',
                      subtitle: 'حماية الحساب وإنهاء الجلسات الأخرى',
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
                  title: 'المظهر واللغة',
                  children: [
                    // المفتاح مربوط بمتحكم حقيقي يحفظ الاختيار.
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: KanafThemeController.instance,
                      builder: (context, mode, _) => SwitchListTile(
                        value: mode == ThemeMode.dark,
                        onChanged: KanafThemeController.instance.setDark,
                        secondary: const Icon(Icons.dark_mode_outlined),
                        title: const Text('الوضع الداكن'),
                        subtitle: const Text('يُحفظ اختيارك للمرات القادمة'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: KanafSpacing.lg,
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: KanafSpacing.lg),
                    ValueListenableBuilder<Locale>(
                      valueListenable: KanafLocaleController.instance,
                      builder: (context, locale, _) {
                        final isArabic = locale.languageCode == 'ar';
                        return _SettingsTile(
                          icon: Icons.language_rounded,
                          title: isArabic ? 'اللغة' : 'Language',
                          subtitle:
                              KanafLocaleController.instance.languageLabel,
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
                  title: 'عن التطبيق',
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'عن كَنَفْ',
                      subtitle: 'الرؤية والفريق والإصدار',
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
      label: Text(_isLoggingOut ? 'جاري الخروج...' : 'تسجيل الخروج'),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد الخروج من حسابك على هذا الجهاز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('خروج'),
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

    // مسح التوكن أولاً: لو انتقلنا قبل المسح لبقيت الجلسة صالحة،
    // ولأعادت شاشة البداية المستخدم إلى حسابه عند إعادة التشغيل.
    await _apiService.logout();
    // وتفريغ الذاكرة حتى لا يرى المستخدم التالي بيانات السابق.
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
        title: const Text('اللغة / Language'),
        contentPadding: const EdgeInsets.only(top: KanafSpacing.sm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'ar',
              groupValue: current,
              onChanged: (value) => Navigator.pop(dialogContext, value),
              secondary: const Icon(Icons.translate_rounded),
              title: const Text('العربية'),
              subtitle: const Text('واجهة عربية واتجاه من اليمين إلى اليسار'),
            ),
            RadioListTile<String>(
              value: 'en',
              groupValue: current,
              onChanged: (value) => Navigator.pop(dialogContext, value),
              secondary: const Icon(Icons.language_rounded),
              title: const Text('English'),
              subtitle: const Text('English locale and left-to-right layout'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
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
        title: const Text('إلغاء التبرع الشهري'),
        content: Text(
          'سيتم تسجيل طلب إلغاء التبرع الشهري رقم KNF-${donation.id}. '
          'لن تُحذف التبرعات السابقة من السجل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('طلب الإلغاء'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelRequested.add(donation.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم تسجيل طلب الإلغاء محلياً. يحتاج الخادم إلى API مخصص لإيقاف الخصم تلقائياً.',
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

  static final NumberFormat _amountFormat = NumberFormat.decimalPattern('ar');
  static final DateFormat _dateFormat = DateFormat('d MMMM y', 'ar');

  @override
  Widget build(BuildContext context) {
    final monthly = donations.where(_isRecurring).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KanafSectionHeader(
          title: 'التبرعات الشهرية',
          subtitle: 'إدارة المساهمات المتكررة',
        ),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(
          padding: EdgeInsets.zero,
          child: monthly.isEmpty
              ? const ListTile(
                  leading: Icon(Icons.event_repeat_rounded),
                  title: Text('لا توجد تبرعات شهرية نشطة'),
                  subtitle: Text('ستظهر هنا مساهماتك المتكررة عند إنشائها'),
                  contentPadding: EdgeInsets.symmetric(
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
                        amountFormat: _amountFormat,
                        dateFormat: _dateFormat,
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
    return mode.contains('month') || mode.contains('شهري');
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
        'مساهمة شهرية لدعم احتياجات كنف العامة';

    return ListTile(
      leading: const Icon(Icons.event_repeat_rounded),
      title: Text(
        amount == null
            ? 'تبرع شهري'
            : '${amountFormat.format(amount)} دينار ليبي شهرياً',
      ),
      subtitle: Text(
        '$description\nالخصم القادم: ${dateFormat.format(nextDate)}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: cancelRequested
          ? const Icon(Icons.pending_actions_rounded)
          : TextButton(
              onPressed: onCancel,
              child: const Text('إلغاء'),
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
        : (user['username']?.toString() ?? 'حسابي');
    final email = user['email']?.toString() ?? '';

    return KanafCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              // أول حرف من الاسم كبديل عن صورة غير موجودة.
              name.isEmpty ? '؟' : name.characters.first,
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
