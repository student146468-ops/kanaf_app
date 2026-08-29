import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider_scope.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';
import '../../l10n/kanaf_localizations.dart';

/// إشعارات المتبرع.
///
/// أُصلح فيها نمط النجاح الكاذب المألوف: «تعليم الكل كمقروء» كان يعرض
/// «تم تحديد جميع الإشعارات كمقروءة» **دون انتظار نتيجة الخادم** —
/// فتظهر الرسالة حتى لو فشل الطلب.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.notifications.isEmpty && !provider.isLoading) {
        provider.fetchNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final notifications = provider.notifications;
    final unread = notifications.where((n) => n['is_read'] != true).length;
    final dateFormat = DateFormat(
      'd MMM y • h:mm a',
      Localizations.localeOf(context).languageCode,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('common.notifications')),
        actions: [
          if (unread > 0)
            TextButton.icon(
              onPressed: provider.isSaving ? null : _markAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text(
                context.tr(
                  'notifications.markAllCount',
                  args: {'count': unread},
                ),
              ),
            ),
          const SizedBox(width: KanafSpacing.xs),
        ],
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: provider.fetchNotifications,
            child: KanafAsyncView(
              isLoading: provider.isLoading,
              isEmpty: notifications.isEmpty,
              errorMessage: provider.errorMessage,
              errorKind: provider.errorKind,
              onRetry: provider.fetchNotifications,
              emptyIcon: Icons.notifications_none_rounded,
              emptyTitle: context.tr('notifications.emptyTitle'),
              emptyMessage: context.tr('notifications.emptyMessage'),
              builder: (context) => ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  KanafSpacing.pageInset,
                  KanafSpacing.lg,
                  KanafSpacing.pageInset,
                  KanafSpacing.xxxl,
                ),
                itemCount: notifications.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: KanafSpacing.md),
                itemBuilder: (context, index) => KanafStaggeredEntrance(
                  index: index,
                  child: _NotificationCard(
                    data: notifications[index],
                    dateFormat: dateFormat,
                    onOpen: () => _open(notifications[index]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markAllRead() async {
    final provider = AppProviderScope.of(context);
    final done = await provider.markAllNotificationsRead();
    if (!mounted) return;

    // لا رسالة نجاح إلا بتأكيد الخادم؛ الفشل يُعلَن صراحةً.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          done
              ? context.tr('notifications.markAllSuccess')
              : provider.errorMessage ??
                  context.tr('notifications.updateFailed'),
        ),
      ),
    );
  }

  Future<void> _open(Map<String, dynamic> notification) async {
    final raw = notification['id'];
    final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '');

    // نعلّمه مقروءاً فقط إن لم يكن كذلك — لا طلب شبكة بلا داعٍ.
    if (id != null && notification['is_read'] != true) {
      await AppProviderScope.of(context).markNotificationRead(id);
    }
    if (!mounted) return;
    _showDetail(notification);
  }

  void _showDetail(Map<String, dynamic> notification) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KanafSpacing.pageInset,
            0,
            KanafSpacing.pageInset,
            KanafSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification['title']?.toString() ??
                    sheetContext.tr('notifications.defaultTitle'),
                style: sheetContext.texts.titleLarge,
              ),
              const SizedBox(height: KanafSpacing.md),
              Text(
                notification['message']?.toString() ?? '',
                style: sheetContext.texts.bodyMedium,
              ),
              const SizedBox(height: KanafSpacing.xxl),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(context.tr('common.ok')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.data,
    required this.dateFormat,
    required this.onOpen,
  });

  final Map<String, dynamic> data;
  final DateFormat dateFormat;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isRead = data['is_read'] == true;
    final title = data['title']?.toString() ?? 'إشعار';
    final message = data['message']?.toString() ?? '';
    final created = DateTime.tryParse(
      data['created_at']?.toString() ?? data['timestamp']?.toString() ?? '',
    );
    final (icon, tone) = _styleFor(
      data['notification_type']?.toString(),
      context,
    );

    return KanafCard(
      onTap: onOpen,
      // غير المقروء يحمل خلفية دافئة خفيفة — إشارة إضافية إلى جانب
      // النقطة، فلا يعتمد التمييز على عنصر واحد صغير.
      color: isRead
          ? scheme.surfaceContainerLow
          : scheme.primary.withOpacity(0.06),
      borderColor: isRead ? null : scheme.primary.withOpacity(0.28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.14),
              borderRadius: KanafRadii.sm,
            ),
            child: Icon(icon, size: 21, color: tone),
          ),
          const SizedBox(width: KanafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleSmall?.copyWith(
                          fontWeight:
                              isRead ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsetsDirectional.only(
                          start: KanafSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: KanafSpacing.xs),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall,
                  ),
                ],
                if (created != null) ...[
                  const SizedBox(height: KanafSpacing.sm),
                  Text(
                    dateFormat.format(created),
                    style: context.texts.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// أيقونة ولون حسب نوع الإشعار القادم من الخادم.
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
