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

/// مركز الإشعارات — مشترك بين كل الأدوار.
///
/// كانت الشاشة تعرض ثلاثة إشعارات مخترعة مكتوبة في الكود مع تعليق
/// `TODO: Replace with AppProvider ... when available`، بينما
/// `fetchNotifications()` موجودة أصلاً. الآن تقرأ من الخادم،
/// والتبويبان يصنّفان البيانات الحقيقية لا نصوصاً ثابتة.
class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final all = provider.notifications;
    final unread = all.where((n) => n['is_read'] != true).toList();
    final dateFormat = DateFormat(
      'd MMM y • h:mm a',
      Localizations.localeOf(context).languageCode,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('notifications.center')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '${context.tr('common.all')} (${all.length})'),
            Tab(
                text:
                    '${context.tr('notifications.unreadTab')} (${unread.length})'),
          ],
        ),
        actions: [
          if (unread.isNotEmpty)
            IconButton(
              tooltip: context.tr('notifications.markAllRead'),
              onPressed:
                  provider.isSaving || _isDeletingAll ? null : _markAllRead,
              icon: const Icon(Icons.done_all_rounded),
            ),
          if (all.isNotEmpty)
            IconButton(
              tooltip: context.tr('notifications.deleteAll'),
              onPressed:
                  provider.isSaving || _isDeletingAll ? null : _deleteAll,
              icon: _isDeletingAll
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList(all, isUnreadTab: false, dateFormat: dateFormat),
              _buildList(unread, isUnreadTab: true, dateFormat: dateFormat),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> items, {
    required bool isUnreadTab,
    required DateFormat dateFormat,
  }) {
    final provider = AppProviderScope.of(context);

    return RefreshIndicator(
      onRefresh: provider.fetchNotifications,
      child: KanafAsyncView(
        isLoading: provider.isLoading,
        isEmpty: items.isEmpty,
        errorMessage:
            provider.notifications.isEmpty ? provider.errorMessage : null,
        onRetry: provider.fetchNotifications,
        emptyIcon: isUnreadTab
            ? Icons.mark_email_read_outlined
            : Icons.notifications_none_rounded,
        emptyTitle: isUnreadTab
            ? context.tr('notifications.noUnreadTitle')
            : context.tr('notifications.emptyTitle'),
        emptyMessage: isUnreadTab
            ? context.tr('notifications.noUnreadMessage')
            : context.tr('notifications.centerEmptyMessage'),
        builder: (context) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            KanafSpacing.pageInset,
            KanafSpacing.lg,
            KanafSpacing.pageInset,
            KanafSpacing.xxxl,
          ),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: KanafSpacing.md),
          itemBuilder: (context, index) => KanafStaggeredEntrance(
            index: index,
            child: _CenterCard(
              data: items[index],
              dateFormat: dateFormat,
              onOpen: () => _open(items[index]),
              onDelete: () => _deleteOne(items[index]),
              isDeleting: _isDeleting(items[index]['id']),
            ),
          ),
        ),
      ),
    );
  }

  bool _isDeleting(Object? rawId) {
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    return id != null && _deletingNotificationIds.contains(id);
  }

  Future<void> _markAllRead() async {
    final provider = AppProviderScope.of(context);
    final done = await provider.markAllNotificationsRead();
    if (!mounted) return;
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

  Future<void> _deleteOne(Map<String, dynamic> notification) async {
    final id = int.tryParse(notification['id']?.toString() ?? '');
    if (id == null) return;
    final confirmed = await _confirm(
      title: context.tr('notifications.deleteConfirmTitle'),
      message: context.tr('notifications.deleteConfirmMessage'),
      action: context.tr('notifications.delete'),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingNotificationIds.add(id));
    final provider = AppProviderScope.of(context);
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

  Future<void> _deleteAll() async {
    final confirmed = await _confirm(
      title: context.tr('notifications.deleteAllConfirmTitle'),
      message: context.tr('notifications.deleteAllConfirmMessage'),
      action: context.tr('notifications.deleteAll'),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAll = true);
    final provider = AppProviderScope.of(context);
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

  Future<void> _open(Map<String, dynamic> notification) async {
    final raw = notification['id'];
    final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (id != null && notification['is_read'] != true) {
      await AppProviderScope.of(context).markNotificationRead(id);
    }
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      KanafRoutes.notificationDetail,
      arguments: notification,
    );
  }
}

class _CenterCard extends StatelessWidget {
  const _CenterCard({
    required this.data,
    required this.dateFormat,
    required this.onOpen,
    required this.onDelete,
    required this.isDeleting,
  });

  final Map<String, dynamic> data;
  final DateFormat dateFormat;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isRead = data['is_read'] == true;
    final created = DateTime.tryParse(
      data['created_at']?.toString() ?? data['timestamp']?.toString() ?? '',
    );
    final imageUrl = (data['image_url'] ?? data['image'] ?? data['imageUrl'])
        ?.toString()
        .trim();

    return KanafCard(
      onTap: onOpen,
      color: isRead
          ? scheme.surfaceContainerLow
          : scheme.primary.withOpacity(0.06),
      borderColor: isRead ? null : scheme.primary.withOpacity(0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            _NotificationImage(imageUrl: imageUrl),
            const SizedBox(height: KanafSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  data['title']?.toString() ??
                      context.tr('notifications.defaultTitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall?.copyWith(
                    fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                  ),
                ),
              ),
              if (!isRead)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              IconButton(
                tooltip: context.tr('notifications.delete'),
                onPressed: isDeleting ? null : onDelete,
                icon: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: KanafSpacing.xs),
          Text(
            data['message']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodySmall,
          ),
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
