import 'package:flutter/material.dart';

import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';

/// عن تطبيق كَنَفْ.
///
/// أُعيد بناؤها على نظام كَنَفْ، وحُذف منها بريد `support@kanaf.ly`
/// — عنوان غير مسجَّل يوحي بقناة دعم قائمة لا وجود لها.
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  static const String _version = '1.0.0';

  static const List<(IconData, String, String)> _features = [
    (
      Icons.fact_check_outlined,
      'احتياجات موثقة',
      'تنشر دور الرعاية احتياجاتها المالية والعينية، ويراها المتبرع كما '
          'سُجِّلت تماماً.',
    ),
    (
      Icons.volunteer_activism_outlined,
      'تبرّع مؤكَّد',
      'لا يُعلَن نجاح أي تبرع قبل أن يؤكد الخادم حفظه، ويصلك رقم مرجعي '
          'من السجل نفسه.',
    ),
    (
      Icons.handshake_outlined,
      'فرص تطوع',
      'تصفّح الفرص المتاحة، قدّم طلبك، وتابع حالته حتى صدور شهادتك.',
    ),
    (
      Icons.timeline_rounded,
      'متابعة الأثر',
      'تتبّع مسار الاحتياج من لحظة نشره حتى إغلاقه.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عن كَنَفْ'),
        leading: const BackButton(),
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              KanafSpacing.pageInset,
              KanafSpacing.xl,
              KanafSpacing.pageInset,
              KanafSpacing.xxl,
            ),
            children: [
              const KanafStaggeredEntrance(index: 0, child: _IntroCard()),
              const SizedBox(height: KanafSpacing.xxl),
              const KanafStaggeredEntrance(
                index: 1,
                child: KanafSectionHeader(title: 'فكرة المشروع'),
              ),
              const SizedBox(height: KanafSpacing.md),
              KanafStaggeredEntrance(
                index: 2,
                child: KanafCard(
                  child: Text(
                    'كَنَفْ منصة تنظّم دعم دور رعاية الأيتام: تربط الاحتياج '
                    'الحقيقي المُعلن من الدار بمن يستطيع تغطيته، وتُبقي أثر '
                    'كل مساهمة ظاهراً وقابلاً للمتابعة.',
                    style: context.texts.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: KanafSpacing.xxl),
              const KanafStaggeredEntrance(
                index: 3,
                child: KanafSectionHeader(title: 'ماذا يقدّم كَنَفْ؟'),
              ),
              const SizedBox(height: KanafSpacing.md),
              KanafStaggeredEntrance(
                index: 4,
                child: KanafCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < _features.length; i++) ...[
                        _FeatureRow(feature: _features[i]),
                        if (i != _features.length - 1)
                          const Divider(height: KanafSpacing.xxl),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KanafSpacing.xxl),
              const KanafStaggeredEntrance(
                index: 5,
                child: KanafSectionHeader(title: 'المشروع'),
              ),
              const SizedBox(height: KanafSpacing.md),
              const KanafStaggeredEntrance(
                index: 6,
                child: KanafCard(
                  child: Column(
                    children: [
                      KanafDetailRow(
                        label: 'النطاق الجغرافي',
                        value: 'ليبيا — مدينة غريان',
                      ),
                      KanafDetailRow(
                        label: 'الجهة',
                        value: 'جامعة غريان — كلية تقنية المعلومات',
                      ),
                      KanafDetailRow(label: 'الإصدار', value: _version),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return KanafCard(
      child: Column(
        children: [
          const KanafLogo(size: 84),
          const SizedBox(height: KanafSpacing.lg),
          Text('كَنَفْ', style: context.texts.headlineMedium),
          const SizedBox(height: KanafSpacing.xs),
          Text(
            'في كَنَفِ من يحتاجك',
            textAlign: TextAlign.center,
            style: context.texts.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final (IconData, String, String) feature;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final (icon, title, body) = feature;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: KanafRadii.sm,
          ),
          child: Icon(icon, size: 22, color: scheme.primary),
        ),
        const SizedBox(width: KanafSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.texts.titleSmall),
              const SizedBox(height: KanafSpacing.xxs),
              Text(body, style: context.texts.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
