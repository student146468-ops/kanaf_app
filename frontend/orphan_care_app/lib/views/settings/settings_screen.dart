import 'package:flutter/material.dart';

import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../services/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.currentUser.isEmpty && !provider.isLoading) {
        provider.fetchCurrentUser(notifyLoading: false);
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
              KanafStaggeredEntrance(index: 0, child: _AccountHeader(user: user)),
              const SizedBox(height: KanafSpacing.xxl),
              KanafStaggeredEntrance(
                index: 1,
                child: _buildSection(
                  title: 'الحساب والأمان',
                  children: [
                    _SettingsTile(
                      icon: Icons.alternate_email_rounded,
                      title: 'تغيير البريد الإلكتروني',
                      subtitle: user['email']?.toString() ?? 'إدارة بريد الحساب',
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
                    const _SettingsTile(
                      icon: Icons.language_rounded,
                      title: 'اللغة',
                      subtitle: 'العربية',
                      // لا لغة أخرى مدعومة بعد، فالمدخل معطّل بصدق
                      // بدل عرض رسالة «قريباً» عند كل نقرة.
                      onTap: null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KanafSpacing.lg),
              KanafStaggeredEntrance(
                index: 3,
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
              KanafStaggeredEntrance(index: 4, child: _buildLogout()),
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
