import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

/// إشعارات المتطوع.
///
/// أُصلح فيها ثلاثة عيوب:
///
/// 1. النقر على الإشعار كان ينفّذ `setState(() => item['read'] = true)`
///    على **نسخة محلية** من القاموس. الخادم لا يعلم شيئاً، فتعود
///    النقطة البرتقالية عند أول تحديث — «نجاح» بلا أثر.
/// 2. الأيقونة كانت تُختار بـ `switch (index)`: الإشعار الأول مدرسة
///    والثاني فرشاة والثالث احتفال… حسب **ترتيبه في القائمة** لا حسب
///    نوعه. أصبحت تتبع `notification_type` الذي يرسله الخادم.
/// 3. تصنيف باسم «التسويق» كان يصفّي `type == 'volunteer'` — عنوان
///    لا علاقة له بما يعرضه.
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  _NotificationFilter _filter = _NotificationFilter.all;

  static final DateFormat _dateFormat = DateFormat('d MMMM y • h:mm a', 'ar');

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
    final all = provider.notifications;
    final visible = _filter.apply(all);
    final unread = all.where((n) => n['is_read'] != true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        leading: const BackButton(),
        actions: [
          if (unread > 0)
            TextButton.icon(
              onPressed: () => _markAll(provider),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('تحديد الكل'),
            ),
          const SizedBox(width: KanafSpacing.xs),
        ],
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildFilters(all),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.fetchNotifications,
                  child: KanafAsyncView(
                    isLoading: provider.isLoading,
                    isEmpty: visible.isEmpty,
                    errorMessage: all.isEmpty ? provider.errorMessage : null,
                    errorKind: provider.errorKind,
                    onRetry: provider.fetchNotifications,
                    emptyIcon: all.isEmpty
                        ? Icons.notifications_none_rounded
                        : Icons.filter_alt_off_outlined,
                    emptyTitle: all.isEmpty
                        ? 'لا توجد إشعارات الآن'
                        : 'لا نتائج لهذا التصنيف',
                    emptyMessage: all.isEmpty
                        ? 'سنخبرك هنا عند البتّ في طلباتك أو نشر فرص جديدة.'
                        : 'جرّب تصنيفاً آخر لعرض بقية الإشعارات.',
                    builder: (context) => ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        KanafSpacing.pageInset,
                        0,
                        KanafSpacing.pageInset,
                        KanafSpacing.xxl,
                      ),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: KanafSpacing.md),
                      itemBuilder: (context, index) => KanafStaggeredEntrance(
                        index: index,
                        child: _NotificationCard(
                          data: visible[index],
                          dateFormat: _dateFormat,
                          onTap: () => _open(provider, visible[index]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(List<Map<String, dynamic>> all) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        KanafSpacing.pageInset,
        KanafSpacing.md,
        KanafSpacing.pageInset,
        KanafSpacing.md,
      ),
      child: Row(
        children: [
          for (final option in _NotificationFilter.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: KanafSpacing.sm),
              child: FilterChip(
                label: Text('${option.label} (${option.apply(all).length})'),
                selected: _filter == option,
                onSelected: (_) => setState(() => _filter = option),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(dynamic provider, Map<String, dynamic> item) async {
    final id = int.tryParse(item['id']?.toString() ?? '');
    // نُعلم الخادم أولاً؛ الحالة المحلية تتبع نتيجته لا العكس.
    if (id != null && item['is_read'] != true) {
      await provider.markNotificationRead(id);
    }
    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      KanafRoutes.notificationDetail,
      arguments: item,
    );
  }

  Future<void> _markAll(dynamic provider) async {
    final done = await provider.markAllNotificationsRead();
    if (!mounted) return;
    if (!done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'تعذر تحديث حالة الإشعارات.',
          ),
        ),
      );
    }
  }
}

enum _NotificationFilter {
  all('الكل'),
  unread('غير مقروء'),
  volunteer('التطوع');

  const _NotificationFilter(this.label);

  final String label;

  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> items) {
    return switch (this) {
      _NotificationFilter.all => items,
      _NotificationFilter.unread =>
        items.where((i) => i['is_read'] != true).toList(),
      _NotificationFilter.volunteer => items
          .where((i) => i['notification_type']?.toString() == 'volunteer')
          .toList(),
    };
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.data,
    required this.dateFormat,
    required this.onTap,
  });

  final Map<String, dynamic> data;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  /// الأيقونة تتبع نوع الإشعار كما يعرّفه `Notification.TYPE_CHOICES`.
  static IconData _iconFor(String type) => switch (type) {
        'donation' => Icons.volunteer_activism_outlined,
        'volunteer' => Icons.handshake_outlined,
        'status_update' => Icons.published_with_changes_rounded,
        _ => Icons.notifications_active_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isRead = data['is_read'] == true;
    final title = data['title']?.toString() ?? 'إشعار';
    final message = data['message']?.toString() ?? '';
    final created = DateTime.tryParse(data['created_at']?.toString() ?? '');
    final type = data['notification_type']?.toString() ?? 'message';

    return KanafCard(
      onTap: onTap,
      color: isRead ? null : scheme.primaryContainer.withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: isRead ? 0.09 : 0.16),
              borderRadius: KanafRadii.sm,
            ),
            child: Icon(_iconFor(type), size: 22, color: scheme.primary),
          ),
          const SizedBox(width: KanafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleSmall?.copyWith(
                          fontWeight:
                              isRead ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!isRead) ...[
                      const SizedBox(width: KanafSpacing.sm),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
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
