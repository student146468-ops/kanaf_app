import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../widgets/kanaf_states.dart';

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

  static final DateFormat _dateFormat = DateFormat('d MMM y • h:mm a', 'ar');

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز الإشعارات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'الكل (${all.length})'),
            Tab(text: 'غير المقروء (${unread.length})'),
          ],
        ),
        actions: [
          if (unread.isNotEmpty)
            IconButton(
              tooltip: 'تعليم الكل كمقروء',
              onPressed: provider.isSaving ? null : _markAllRead,
              icon: const Icon(Icons.done_all_rounded),
            ),
        ],
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList(all, isUnreadTab: false),
              _buildList(unread, isUnreadTab: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> items, {
    required bool isUnreadTab,
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
        emptyTitle: isUnreadTab ? 'لا شيء غير مقروء' : 'لا توجد إشعارات',
        emptyMessage: isUnreadTab
            ? 'أنت على اطلاع بكل التحديثات.'
            : 'ستصلك هنا تحديثات تبرعاتك وطلبات التطوع.',
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
              dateFormat: _dateFormat,
              onOpen: () => _open(items[index]),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          done
              ? 'تم تعليم جميع الإشعارات كمقروءة'
              : provider.errorMessage ?? 'تعذر تحديث حالة الإشعارات.',
        ),
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
  });

  final Map<String, dynamic> data;
  final DateFormat dateFormat;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isRead = data['is_read'] == true;
    final created = DateTime.tryParse(
      data['created_at']?.toString() ?? data['timestamp']?.toString() ?? '',
    );

    return KanafCard(
      onTap: onOpen,
      color: isRead
          ? scheme.surfaceContainerLow
          : scheme.primary.withValues(alpha: 0.06),
      borderColor: isRead ? null : scheme.primary.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data['title']?.toString() ?? 'إشعار',
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
