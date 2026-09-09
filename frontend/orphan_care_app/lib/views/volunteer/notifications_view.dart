import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../services/api_config.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';
import '../../l10n/kanaf_localizations.dart';

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
  final Set<int> _deletingNotificationIds = {};
  bool _isDeletingAll = false;

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
    final dateFormat = DateFormat(
      'd MMMM y • h:mm a',
      Localizations.localeOf(context).languageCode,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('common.notifications')),
        leading: const BackButton(),
        actions: [
          if (unread > 0)
            TextButton.icon(
              onPressed: provider.isSaving || _isDeletingAll
                  ? null
                  : () => _markAll(provider),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text(context.tr('notifications.selectAll')),
            ),
          if (all.isNotEmpty)
            IconButton(
              tooltip: context.tr('notifications.deleteAll'),
              onPressed: provider.isSaving || _isDeletingAll
                  ? null
                  : () => _deleteAll(provider),
              icon: _isDeletingAll
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_sweep_outlined),
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
                        ? context.tr('notifications.emptyTitle')
                        : context.tr('volunteer.emptyCategoryTitle'),
                    emptyMessage: all.isEmpty
                        ? context.tr('notifications.emptyMessage')
                        : context.tr('notifications.emptyFilterMessage'),
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
                          dateFormat: dateFormat,
                          onTap: () => _open(provider, visible[index]),
                          onDelete: () => _deleteOne(provider, visible[index]),
                          isDeleting: _isDeleting(visible[index]['id']),
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

  bool _isDeleting(Object? rawId) {
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    return id != null && _deletingNotificationIds.contains(id);
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
                label: Text(
                  '${context.tr(option.labelKey)} (${option.apply(all).length})',
                ),
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
            provider.errorMessage ?? context.tr('notifications.updateFailed'),
          ),
        ),
      );
    }
  }

  Future<void> _deleteOne(dynamic provider, Map<String, dynamic> item) async {
    final id = int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return;
    final confirmed = await _confirm(
      title: context.tr('notifications.deleteConfirmTitle'),
      message: context.tr('notifications.deleteConfirmMessage'),
      action: context.tr('notifications.delete'),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingNotificationIds.add(id));
    final done = await provider.deleteNotification(id);
    if (!mounted) return;
    setState(() => _deletingNotificationIds.remove(id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          done
              ? context.tr('notifications.deleteSuccess')
              : provider.errorMessage ??
                  context.tr('notifications.deleteFailed'),
        ),
      ),
    );
  }

  Future<void> _deleteAll(dynamic provider) async {
    final confirmed = await _confirm(
      title: context.tr('notifications.deleteAllConfirmTitle'),
      message: context.tr('notifications.deleteAllConfirmMessage'),
      action: context.tr('notifications.deleteAll'),
    );
    if (confirmed != true || !mounted || _isDeletingAll) return;

    setState(() => _isDeletingAll = true);
    final done = await provider.deleteAllNotifications();
    if (!mounted) return;
    setState(() {
      _isDeletingAll = false;
      _deletingNotificationIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          done
              ? context.tr('notifications.deleteAllSuccess')
              : provider.errorMessage ??
                  context.tr('notifications.deleteAllFailed'),
        ),
      ),
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}

enum _NotificationFilter {
  all('common.all'),
  unread('volunteer.filterUnread'),
  volunteer('volunteer.filterVolunteering');

  const _NotificationFilter(this.labelKey);

  final String labelKey;

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
    required this.onDelete,
    required this.isDeleting,
  });

  final Map<String, dynamic> data;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDeleting;

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
    final title =
        data['title']?.toString() ?? context.tr('notifications.defaultTitle');
    final message = data['message']?.toString() ?? '';
    final created = DateTime.tryParse(data['created_at']?.toString() ?? '');
    final type = data['notification_type']?.toString() ?? 'message';
    final imageUrl = (data['image_url'] ?? data['image'] ?? data['imageUrl'])
        ?.toString()
        .trim();

    return KanafCard(
      onTap: onTap,
      color: isRead ? null : scheme.primaryContainer.withOpacity(0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(isRead ? 0.09 : 0.16),
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
                    IconButton(
                      tooltip: context.tr('notifications.delete'),
                      onPressed: isDeleting ? null : onDelete,
                      icon: isDeleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.delete_outline_rounded),
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
                    style: context.texts.labelSmall,
                  ),
                ],
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  const SizedBox(height: KanafSpacing.md),
                  _NotificationImage(imageUrl: imageUrl),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationImage extends StatelessWidget {
  const _NotificationImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return ClipRRect(
      borderRadius: KanafRadii.md,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          ApiConfig.resolveBackendUrl(imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
