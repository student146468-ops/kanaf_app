import 'package:flutter/material.dart';

import '../../models/need_model.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

/// ملف دار الرعاية كما يراه المتبرع.
///
/// أُصلحت فيها أربعة عيوب:
///
/// 1. كانت تقرأ `provider.careHomes.first` — **أول دار في القائمة**
///    متجاهلةً تماماً الدار التي نقر عليها المتبرع. فأي دار يفتحها
///    تعرض نفس الدار.
/// 2. كانت تعرض «٤٥ طفل» و«١٢ احتياج» و«٨٨٪ تغطية» — أرقام مكتوبة
///    في الكود، وثلاث سمات ثابتة «رعاية/تعليمي/صحي» لا تصف شيئاً.
/// 3. كانت تعرض **كل احتياجات النظام** تحت اسم هذه الدار. صار الربط
///    حقيقياً بعد إضافة `Need.care_home` في الخادم.
/// 4. وسم «دار موثقة في كنف» كان يُلصق بكل دار بلا أي حقل توثيق.
class OrphanageProfileScreen extends StatefulWidget {
  const OrphanageProfileScreen({super.key});

  @override
  State<OrphanageProfileScreen> createState() => _OrphanageProfileScreenState();
}

class _OrphanageProfileScreenState extends State<OrphanageProfileScreen> {
  int? _careHomeId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final home = _argumentHome();
    final id = int.tryParse(home['id']?.toString() ?? '');
    if (id == null || id == _careHomeId) return;

    _careHomeId = id;
    final provider = AppProviderScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.fetchNeeds(notifyLoading: false);
      provider.fetchVisitHours(id, notifyLoading: false);
    });
  }

  /// الدار تصل عبر وسيطات المسار — لا نخمّنها من القائمة.
  Map<String, dynamic> _argumentHome() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) return Map<String, dynamic>.from(args);
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final home = _argumentHome();

    if (home.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ملف الدار'),
          leading: const BackButton(),
        ),
        body: KanafBackdrop(
          child: KanafMessageState(
            icon: Icons.apartment_outlined,
            title: 'لم تُحدَّد الدار',
            message: 'عد إلى قائمة الدور واختر داراً لعرض ملفها.',
            actionLabel: 'تصفّح الدور',
            onAction: () => Navigator.pushReplacementNamed(
              context,
              KanafRoutes.exploreOrphanages,
            ),
          ),
        ),
      );
    }

    final name = home['name']?.toString() ?? 'دار رعاية';
    final address = home['address']?.toString() ?? '';
    final phone = home['phone']?.toString() ?? '';
    final email = home['email']?.toString() ?? '';
    final description = home['description']?.toString().trim() ?? '';
    final orphanCount = int.tryParse(home['orphan_count']?.toString() ?? '');

    // احتياجات هذه الدار وحدها.
    final needs = provider.needs
        .where((need) => need.careHomeId == _careHomeId)
        .where((need) => need.status != 'archived')
        .toList();
    final openNeeds = needs.where((n) => n.status == 'open').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملف الدار'),
        leading: const BackButton(),
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              KanafSpacing.pageInset,
              KanafSpacing.lg,
              KanafSpacing.pageInset,
              KanafSpacing.xxl,
            ),
            children: [
              KanafStaggeredEntrance(
                index: 0,
                child: _HeaderCard(name: name, address: address),
              ),
              const SizedBox(height: KanafSpacing.lg),
              KanafStaggeredEntrance(
                index: 1,
                child: _StatsRow(
                  orphanCount: orphanCount,
                  openNeeds: openNeeds.length,
                  visitSlots: provider.visitHours.length,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: KanafSpacing.xxl),
                KanafStaggeredEntrance(
                  index: 2,
                  child: _AboutSection(text: description),
                ),
              ],
              const SizedBox(height: KanafSpacing.xxl),
              KanafStaggeredEntrance(
                index: 3,
                child: _ContactSection(
                  address: address,
                  phone: phone,
                  email: email,
                ),
              ),
              if (provider.visitHours.isNotEmpty) ...[
                const SizedBox(height: KanafSpacing.xxl),
                KanafStaggeredEntrance(
                  index: 4,
                  child: _VisitHoursSection(slots: provider.visitHours),
                ),
              ],
              const SizedBox(height: KanafSpacing.xxl),
              KanafStaggeredEntrance(
                index: 5,
                child: _NeedsSection(needs: openNeeds),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.name, required this.address});

  final String name;
  final String address;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return KanafCard(
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  KanafPalette.seed.withOpacity(0.22),
                  KanafPalette.ember.withOpacity(0.12),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.apartment_rounded,
              size: 40,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: KanafSpacing.lg),
          Text(
            name,
            textAlign: TextAlign.center,
            style: context.texts.titleLarge,
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: KanafSpacing.xs),
            Text(
              address,
              textAlign: TextAlign.center,
              style: context.texts.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.orphanCount,
    required this.openNeeds,
    required this.visitSlots,
  });

  final int? orphanCount;
  final int openNeeds;
  final int visitSlots;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: KanafStatTile(
            icon: Icons.child_care_outlined,
            // لا نعرض صفراً مخترعاً حين لا يرسل الخادم العدد.
            value: orphanCount == null ? '—' : '$orphanCount',
            label: 'الأيتام',
          ),
        ),
        const SizedBox(width: KanafSpacing.md),
        Expanded(
          child: KanafStatTile(
            icon: Icons.list_alt_outlined,
            value: '$openNeeds',
            label: 'احتياج مفتوح',
          ),
        ),
        const SizedBox(width: KanafSpacing.md),
        Expanded(
          child: KanafStatTile(
            icon: Icons.calendar_month_outlined,
            value: '$visitSlots',
            label: 'موعد زيارة',
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KanafSectionHeader(title: 'نبذة عن الدار'),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(child: Text(text, style: context.texts.bodyMedium)),
      ],
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.address,
    required this.phone,
    required this.email,
  });

  final String address;
  final String phone;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KanafSectionHeader(title: 'التواصل'),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(
          child: Column(
            children: [
              if (address.isNotEmpty)
                KanafDetailRow(label: 'العنوان', value: address),
              if (phone.isNotEmpty)
                KanafDetailRow(label: 'الهاتف', value: phone),
              if (email.isNotEmpty)
                KanafDetailRow(label: 'البريد', value: email),
              if (address.isEmpty && phone.isEmpty && email.isEmpty)
                Text(
                  'لم تُسجَّل بيانات تواصل لهذه الدار بعد.',
                  style: context.texts.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisitHoursSection extends StatelessWidget {
  const _VisitHoursSection({required this.slots});

  final List<Map<String, dynamic>> slots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KanafSectionHeader(
          title: 'مواعيد الزيارة',
          subtitle: 'الأوقات التي تستقبل فيها الدار الزوار',
        ),
        const SizedBox(height: KanafSpacing.md),
        KanafCard(
          child: Column(
            children: [
              for (final slot in slots)
                KanafDetailRow(
                  label: slot['weekday_label']?.toString() ?? 'يوم',
                  value: '${_time(slot['start_time'])} - '
                      '${_time(slot['end_time'])}',
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// الخادم يرسل `HH:mm:ss`؛ نعرض الساعة والدقيقة فقط.
  String _time(Object? raw) {
    final value = raw?.toString() ?? '';
    final parts = value.split(':');
    if (parts.length < 2) return value.isEmpty ? '--:--' : value;
    return '${parts[0]}:${parts[1]}';
  }
}

class _NeedsSection extends StatelessWidget {
  const _NeedsSection({required this.needs});

  final List<NeedModel> needs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KanafSectionHeader(title: 'احتياجات الدار'),
        const SizedBox(height: KanafSpacing.md),
        if (needs.isEmpty)
          KanafCard(
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: context.semantic.success,
                ),
                const SizedBox(width: KanafSpacing.md),
                Expanded(
                  child: Text(
                    'لا توجد احتياجات مفتوحة لهذه الدار حالياً.',
                    style: context.texts.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          for (final need in needs)
            Padding(
              padding: const EdgeInsets.only(bottom: KanafSpacing.md),
              child: _NeedTile(need: need),
            ),
      ],
    );
  }
}

class _NeedTile extends StatelessWidget {
  const _NeedTile({required this.need});

  final NeedModel need;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final progress = need.progress;

    return KanafCard(
      onTap: () => Navigator.pushNamed(
        context,
        KanafRoutes.needDetails,
        arguments: {'id': need.id},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: KanafRadii.sm,
                ),
                child: Icon(need.icon, size: 22, color: scheme.primary),
              ),
              const SizedBox(width: KanafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      need.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall,
                    ),
                    const SizedBox(height: KanafSpacing.xxs),
                    Text(
                      need.categoryLabel,
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              if (need.priority == 'urgent')
                const KanafStatusChip(status: 'urgent', compact: true),
            ],
          ),
          // شريط التقدّم يظهر فقط حين تكون الكمية المطلوبة رقمية.
          if (progress != null) ...[
            const SizedBox(height: KanafSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: KanafRadii.pill,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: KanafSpacing.md),
                Text(
                  '${(progress * 100).round()}%',
                  style: context.texts.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ] else if (need.requiredQuantity.isNotEmpty) ...[
            const SizedBox(height: KanafSpacing.md),
            Text(
              'المطلوب: ${need.requiredQuantity}',
              style: context.texts.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
