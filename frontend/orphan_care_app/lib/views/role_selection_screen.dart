import 'package:flutter/material.dart';

import '../router/kanaf_router.dart';
import '../theme/kanaf_motion.dart';
import '../theme/kanaf_tokens.dart';
import '../utils/auth_navigation.dart';
import '../widgets/kanaf_layout.dart';

/// شاشة اختيار الدور.
///
/// التطبيق موجَّه للجمهور: **متبرع** أو **متطوع**. أما دور الرعاية
/// فتُدار حساباتها ومحتواها من لوحة التحكم لا من التطبيق — وهذا ما
/// يفرضه الخادم أصلاً، إذ يرفض `RegisterView` التسجيل بدور `care_home`.
///
/// حُذف كذلك `Future.delayed(350ms)` الذي كان يحاكي تحميلاً وهمياً —
/// تأخير مصطنع بلا عمل خلفه هو ضرر خالص.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  static const List<_RoleOption> _roles = [
    _RoleOption(
      key: AuthNavigation.donorRole,
      title: 'متبرع',
      subtitle: 'ابحث عن الاحتياجات الحقيقية وادعم بما تستطيع.',
      icon: Icons.favorite_outline_rounded,
    ),
    _RoleOption(
      key: AuthNavigation.volunteerRole,
      title: 'متطوع',
      subtitle: 'ساهم بوقتك ومهاراتك، وتابع ساعاتك وشهاداتك.',
      icon: Icons.handshake_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KanafBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KanafSpacing.xxl,
                      KanafSpacing.xxxl,
                      KanafSpacing.xxl,
                      KanafSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        const KanafLogo(size: 76),
                        const SizedBox(height: KanafSpacing.xl),
                        Text(
                          'اختر دورك لنبدأ',
                          textAlign: TextAlign.center,
                          style: context.texts.headlineMedium,
                        ),
                        const SizedBox(height: KanafSpacing.sm),
                        Text(
                          'يحدد الدور ما تراه في التطبيق. يمكنك تغييره لاحقاً '
                          'بتسجيل الدخول بحساب آخر.',
                          textAlign: TextAlign.center,
                          style: context.texts.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // البطاقتان تتوسّطان المساحة المتبقية بدل أن تُدفعا
                  // إلى الأعلى تاركتين فراغاً كبيراً تحتهما. القيد على
                  // `minHeight` يُبقي التمرير متاحاً على الشاشات القصيرة
                  // بدل أن ينكمش العمود فتفقد المركزة أثرها.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KanafSpacing.xxl,
                          vertical: KanafSpacing.sm,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - KanafSpacing.xl,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < _roles.length; i++)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: i == _roles.length - 1
                                        ? 0
                                        : KanafSpacing.md,
                                  ),
                                  child: KanafStaggeredEntrance(
                                    index: i,
                                    child: _RoleCard(
                                      role: _roles[i],
                                      selected: _selectedRole == _roles[i].key,
                                      onTap: () => setState(
                                        () => _selectedRole = _roles[i].key,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  KanafActionBar(
                    child: FilledButton.icon(
                      onPressed: _selectedRole == null ? null : _proceed,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('متابعة'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _proceed() {
    final role = _selectedRole;
    if (role == null) return;
    Navigator.of(context).pushReplacementNamed(
      KanafRoutes.login,
      arguments: role,
    );
  }
}

class _RoleOption {
  const _RoleOption({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final _RoleOption role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return AnimatedContainer(
      duration: KanafDuration.quick,
      curve: KanafCurves.standard,
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: KanafRadii.lg,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KanafSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.16)
                      : scheme.surfaceContainerHighest,
                  borderRadius: KanafRadii.md,
                ),
                child: Icon(
                  role.icon,
                  size: 27,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: KanafSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.title,
                      style: context.texts.titleMedium?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.xxs),
                    Text(role.subtitle, style: context.texts.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              AnimatedScale(
                duration: KanafDuration.quick,
                scale: selected ? 1 : 0.7,
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? scheme.primary : scheme.outline,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
