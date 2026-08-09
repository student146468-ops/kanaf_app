import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

/// تفاصيل إشعار واحد.
///
/// أُعيد بناؤها على نظام كَنَفْ. كانت تعتمد على `shared_mobile_ui.dart`
/// الذي يعرّف صنفاً باسم `KanafCard` مختلفاً عن الصنف الذي يحمل الاسم
/// نفسه في نظام التصميم — تضارب تسمية يجعل سلوك الشاشة يعتمد على
/// أي ملف استُورد، وهو مصدر أخطاء صامتة.
class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final title = args?['title']?.toString() ?? 'تفاصيل الإشعار';
    final body = args?['message']?.toString() ??
        args?['body']?.toString() ??
        'لا توجد تفاصيل إضافية لهذا الإشعار.';
    final status = args?['status']?.toString();
    final type = args?['notification_type']?.toString() ??
        args?['type']?.toString();
    final created = DateTime.tryParse(
      args?['created_at']?.toString() ?? args?['timestamp']?.toString() ?? '',
    );

    final (icon, tone) = _styleFor(type, context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الإشعار'),
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
              KanafSpacing.xxxl,
            ),
            children: [
              KanafStaggeredEntrance(
                index: 0,
                child: KanafCard(
                  padding: const EdgeInsets.all(KanafSpacing.xxl),
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: tone.withValues(alpha: 0.14),
                          borderRadius: KanafRadii.lg,
                        ),
                        child: Icon(icon, size: 32, color: tone),
                      ),
                      const SizedBox(height: KanafSpacing.xl),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: context.texts.titleLarge,
                      ),
                      if (status != null) ...[
                        const SizedBox(height: KanafSpacing.md),
                        KanafStatusChip(status: status),
                      ],
                      const SizedBox(height: KanafSpacing.lg),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: context.texts.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (created != null) ...[
                const SizedBox(height: KanafSpacing.lg),
                KanafStaggeredEntrance(
                  index: 1,
                  child: KanafCard(
                    child: KanafDetailRow(
                      label: 'وصل في',
                      value: DateFormat('d MMMM y • h:mm a', 'ar')
                          .format(created),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: KanafSpacing.xxl),
              KanafStaggeredEntrance(
                index: 2,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('العودة للإشعارات'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _styleFor(String? type, BuildContext context) {
    final semantic = context.semantic;
    return switch (type) {
      'donation' => (Icons.volunteer_activism_outlined, semantic.success),
      'volunteer' => (Icons.handshake_outlined, semantic.info),
      'need' => (Icons.campaign_outlined, semantic.warning),
      _ => (Icons.notifications_outlined, context.colors.primary),
    };
  }
}
