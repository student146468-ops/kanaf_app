import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider_scope.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_nav_shell.dart';
import '../../widgets/kanaf_states.dart';
import '../../l10n/kanaf_localizations.dart';

/// شهادات المتطوع.
///
/// أُصلح فيها ثلاثة عيوب:
///
/// 1. كانت تأخذ `certificates.first` فقط — فمتطوع أنهى خمس مشاركات
///    يرى شهادة واحدة ولا يعلم بوجود البقية.
/// 2. كان زرّا «تحميل» و«مشاركة» يعرضان «قريبًا»؛ لا يوجد في الخادم
///    أي حقل ملف شهادة، فالزرّان كانا يَعِدان بما لا وجود له.
/// 3. كانت تَعُدّ الطلب **المقبول** شهادةً. القبول يعني أن المشاركة
///    ستبدأ، لا أنها تمّت. الشهادة تُستحق عند `completed` فقط.
class MyCertificatesView extends StatefulWidget {
  const MyCertificatesView({super.key});

  @override
  State<MyCertificatesView> createState() => _MyCertificatesViewState();
}

class _MyCertificatesViewState extends State<MyCertificatesView> {
  static final DateFormat _dateFormat = DateFormat('d MMMM y', 'ar');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.volunteerApplications.isEmpty && !provider.isLoading) {
        provider.fetchVolunteerApplications();
      }
      if (provider.currentUser.isEmpty) {
        provider.fetchCurrentUser(notifyLoading: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final name = _displayName(provider.currentUser);

    final certificates = provider.volunteerApplications
        .where((item) => item['status']?.toString() == 'completed')
        .toList();

    return Scaffold(
      appBar: AppBar(
          title: Text(context.tr('common.myCertificates')), centerTitle: false),
      bottomNavigationBar: const KanafNavBar(
        destinations: KanafNavDestinations.volunteer,
        currentIndex: 2,
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: provider.fetchVolunteerApplications,
            child: KanafAsyncView(
              isLoading: provider.isLoading,
              isEmpty: certificates.isEmpty,
              errorMessage: provider.volunteerApplications.isEmpty
                  ? provider.errorMessage
                  : null,
              onRetry: provider.fetchVolunteerApplications,
              emptyIcon: Icons.workspace_premium_outlined,
              emptyTitle: 'لا توجد شهادات بعد',
              emptyMessage:
                  'تُصدر الشهادة عند اكتمال مشاركتك التطوعية وتأكيد الدار '
                  'لها. تابع حالة طلباتك من «جدولي».',
              builder: (context) => ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  KanafSpacing.pageInset,
                  KanafSpacing.lg,
                  KanafSpacing.pageInset,
                  KanafSpacing.xxl,
                ),
                itemCount: certificates.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: KanafSpacing.lg),
                itemBuilder: (context, index) => KanafStaggeredEntrance(
                  index: index,
                  child: _CertificateCard(
                    name: name,
                    data: certificates[index],
                    dateFormat: _dateFormat,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _displayName(Map<String, dynamic> user) {
    final first = user['first_name']?.toString().trim() ?? '';
    final last = user['last_name']?.toString().trim() ?? '';
    final full = [first, last].where((p) => p.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    final username = user['username']?.toString().trim() ?? '';
    return username.isNotEmpty ? username : 'متطوع';
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({
    required this.name,
    required this.data,
    required this.dateFormat,
  });

  final String name;
  final Map<String, dynamic> data;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final title = data['opportunity_title']?.toString() ?? 'مشاركة تطوعية';
    final location = data['opportunity_location']?.toString() ?? '';
    final issued = DateTime.tryParse(data['updated_at']?.toString() ?? '') ??
        DateTime.tryParse(data['created_at']?.toString() ?? '');
    final rating = data['rating'];

    return KanafCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // شريط الهوية العلوي — لمسة كَنَفْ البصرية على الشهادة.
          Container(
            height: 6,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [KanafPalette.seed, KanafPalette.ember],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(KanafSpacing.xl),
            child: Column(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: KanafPalette.seed.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: 34,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: KanafSpacing.lg),
                Text(
                  'شهادة تطوع',
                  textAlign: TextAlign.center,
                  style: context.texts.headlineSmall,
                ),
                const SizedBox(height: KanafSpacing.lg),
                Text(
                  'تشهد كَنَفْ بأن',
                  textAlign: TextAlign.center,
                  style: context.texts.bodySmall,
                ),
                const SizedBox(height: KanafSpacing.xs),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: context.texts.titleLarge?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: KanafSpacing.md),
                Container(
                  width: 64,
                  height: 2,
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.4),
                    borderRadius: KanafRadii.pill,
                  ),
                ),
                const SizedBox(height: KanafSpacing.md),
                Text(
                  'قد أتمّ مشاركته التطوعية في «$title»'
                  '${location.isEmpty ? '' : ' بـ$location'}.',
                  textAlign: TextAlign.center,
                  style: context.texts.bodyMedium,
                ),
                if (rating != null) ...[
                  const SizedBox(height: KanafSpacing.lg),
                  _RatingStars(rating: rating),
                ],
                if (issued != null) ...[
                  const SizedBox(height: KanafSpacing.lg),
                  Text(
                    'صدرت في ${dateFormat.format(issued)}',
                    style: context.texts.labelSmall,
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

/// تقييم الدار للمشاركة — يرسله الخادم في `rating`.
class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});

  final Object rating;

  @override
  Widget build(BuildContext context) {
    final value = int.tryParse(rating.toString()) ?? 0;
    if (value <= 0) return const SizedBox.shrink();

    return Column(
      children: [
        Text(context.tr('volunteer.careHomeRating'),
            style: context.texts.labelMedium),
        const SizedBox(height: KanafSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                i <= value ? Icons.star_rounded : Icons.star_border_rounded,
                size: 22,
                color: context.semantic.warning,
              ),
          ],
        ),
      ],
    );
  }
}
