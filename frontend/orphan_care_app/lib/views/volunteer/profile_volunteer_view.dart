import 'package:flutter/material.dart';

import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_nav_shell.dart';

/// حساب المتطوع.
///
/// النسخة السابقة كانت تعرض ثلاثة أرقام **مكتوبة في الكود**:
/// «٢٤ ساعة تطوع» و«٨ أنشطة» و«٣ فرص». أرقام ثابتة لا تتغيّر مهما فعل
/// المتطوع، معروضة بثقة كأنها سجلّه الحقيقي. استُبدلت بعدّادات محسوبة
/// من طلباته الفعلية.
///
/// كما حُذف زرّا «تعديل البيانات» و«تغيير الصورة» اللذان كانا يعرضان
/// «قريبًا»: الأول له وجهة حقيقية الآن (الإعدادات)، والثاني لا يسنده
/// أي حقل صورة في الخادم فلا معنى لعرضه.
class ProfileVolunteerView extends StatefulWidget {
  const ProfileVolunteerView({super.key});

  @override
  State<ProfileVolunteerView> createState() => _ProfileVolunteerViewState();
}

class _ProfileVolunteerViewState extends State<ProfileVolunteerView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.currentUser.isEmpty) {
        provider.fetchCurrentUser(notifyLoading: false);
      }
      if (provider.volunteerApplications.isEmpty) {
        provider.fetchVolunteerApplications(notifyLoading: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final user = provider.currentUser;
    final applications = provider.volunteerApplications;

    final name = _displayName(user);
    final email = user['email']?.toString() ?? '';

    int countWhere(bool Function(String) test) => applications
        .where((item) => test(item['status']?.toString() ?? ''))
        .length;

    final accepted =
        countWhere((s) => s == 'accepted' || s == 'approved');
    final completed = countWhere((s) => s == 'completed');

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: () =>
                Navigator.pushNamed(context, KanafRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: KanafSpacing.xs),
        ],
      ),
      bottomNavigationBar: const KanafNavBar(
        destinations: KanafNavDestinations.volunteer,
        currentIndex: 3,
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () async {
              await provider.fetchCurrentUser(notifyLoading: false);
              await provider.fetchVolunteerApplications(notifyLoading: false);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                KanafSpacing.pageInset,
                KanafSpacing.lg,
                KanafSpacing.pageInset,
                KanafSpacing.bottomSafeGutter,
              ),
              children: [
                KanafStaggeredEntrance(
                  index: 0,
                  child: _IdentityCard(name: name, email: email),
                ),
                const SizedBox(height: KanafSpacing.lg),
                KanafStaggeredEntrance(
                  index: 1,
                  child: _StatsRow(
                    total: applications.length,
                    accepted: accepted,
                    completed: completed,
                  ),
                ),
                const SizedBox(height: KanafSpacing.xxl),
                const KanafStaggeredEntrance(
                  index: 2,
                  child: KanafSectionHeader(title: 'سجلّي'),
                ),
                const SizedBox(height: KanafSpacing.md),
                const KanafStaggeredEntrance(index: 3, child: _MenuCard()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// الاسم الكامل إن وُجد، وإلا اسم المستخدم — لا «غير محدد» فارغة.
  String _displayName(Map<String, dynamic> user) {
    final first = user['first_name']?.toString().trim() ?? '';
    final last = user['last_name']?.toString().trim() ?? '';
    final full = [first, last].where((p) => p.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    final username = user['username']?.toString().trim() ?? '';
    return username.isNotEmpty ? username : 'متطوع';
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return KanafCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  KanafPalette.seed.withValues(alpha: 0.22),
                  KanafPalette.ember.withValues(alpha: 0.14),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              size: 34,
              color: scheme.primary,
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

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.accepted,
    required this.completed,
  });

  final int total;
  final int accepted;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: KanafStatTile(
            icon: Icons.send_outlined,
            value: '$total',
            label: 'طلباتي',
          ),
        ),
        const SizedBox(width: KanafSpacing.md),
        Expanded(
          child: KanafStatTile(
            icon: Icons.check_circle_outline_rounded,
            value: '$accepted',
            label: 'مقبولة',
          ),
        ),
        const SizedBox(width: KanafSpacing.md),
        Expanded(
          child: KanafStatTile(
            icon: Icons.workspace_premium_outlined,
            value: '$completed',
            label: 'مكتملة',
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard();

  static const List<(String, IconData, String)> _items = [
    ('سجل التطوع', Icons.history_edu_outlined, KanafRoutes.myVolunteerHistory),
    ('شهاداتي', Icons.workspace_premium_outlined, KanafRoutes.myCertificates),
    ('جدولي', Icons.event_note_outlined, KanafRoutes.mySchedule),
    ('الإعدادات', Icons.settings_outlined, KanafRoutes.settings),
  ];

  @override
  Widget build(BuildContext context) {
    return KanafCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            ListTile(
              leading: Icon(_items[i].$2, color: context.colors.primary),
              title: Text(_items[i].$1, style: context.texts.titleSmall),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.pushNamed(context, _items[i].$3),
            ),
            if (i != _items.length - 1)
              const Divider(height: 1, indent: KanafSpacing.xxxl),
          ],
        ],
      ),
    );
  }
}
