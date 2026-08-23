import 'package:flutter/material.dart';

import '../providers/app_provider_scope.dart';
import '../theme/kanaf_tokens.dart';

/// وجهة في شريط التنقل السفلي.
class KanafDestination {
  const KanafDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

/// شريط التنقل السفلي الموحّد.
///
/// يستبدل نمط «زر الهامبرغر» الذي كان مستخدماً في التطبيق. الهامبرغر
/// نمط ويب: يخفي التنقل خلف نقرة إضافية ويصل بعيداً عن الإبهام.
/// `NavigationBar` من Material 3 يعرض الأقسام دائماً، ويعطي مؤشر
/// حالة نشط، وحركة انتقال مدمجة — وهو ما يجعل التطبيق يُحسّ أصلياً.
class KanafNavBar extends StatelessWidget {
  const KanafNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    this.onDestinationSelected,
  });

  final List<KanafDestination> destinations;
  final int currentIndex;
  final ValueChanged<int>? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex.clamp(0, destinations.length - 1),
      onDestinationSelected: (index) {
        if (index == currentIndex) return;
        if (onDestinationSelected != null) {
          onDestinationSelected!(index);
          return;
        }
        // الافتراضي: استبدال الجذر الحالي بجذر القسم الجديد، فلا
        // تتراكم الجذور في مكدّس التنقل ويبقى زر الرجوع منطقياً.
        Navigator.pushReplacementNamed(context, destinations[index].route);
      },
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
            tooltip: destination.label,
          ),
      ],
    );
  }
}

/// وجهات كل دور. مركزيتها هنا تمنع تعريف تنقل مختلف في كل شاشة.
abstract final class KanafNavDestinations {
  static const List<KanafDestination> donor = [
    KanafDestination(
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      route: '/supporter_home',
    ),
    KanafDestination(
      label: 'استكشاف',
      icon: Icons.travel_explore_outlined,
      selectedIcon: Icons.travel_explore_rounded,
      route: '/explore_orphanages',
    ),
    KanafDestination(
      label: 'تبرعاتي',
      icon: Icons.volunteer_activism_outlined,
      selectedIcon: Icons.volunteer_activism_rounded,
      route: '/donation_history',
    ),
    KanafDestination(
      label: 'حسابي',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      route: '/profile',
    ),
  ];

  static const List<KanafDestination> volunteer = [
    KanafDestination(
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      route: '/volunteer_home',
    ),
    KanafDestination(
      label: 'جدولي',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      route: '/my_schedule',
    ),
    KanafDestination(
      label: 'شهاداتي',
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium_rounded,
      route: '/my_certificates',
    ),
    KanafDestination(
      label: 'حسابي',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      route: '/volunteer_profile',
    ),
  ];
}

/// زر إشعارات مع شارة عدد غير المقروء.
class KanafNotificationButton extends StatelessWidget {
  const KanafNotificationButton({
    super.key,
    required this.unreadCount,
    required this.route,
  });

  final int unreadCount;
  final String route;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return IconButton(
      tooltip: 'الإشعارات',
      onPressed: () => _openNotifications(context),
      icon: Badge(
        // الشارة تظهر فقط عند وجود غير مقروء — لا نقطة دائمة بلا معنى.
        isLabelVisible: unreadCount > 0,
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }

  Future<void> _openNotifications(BuildContext context) async {
    final provider = AppProviderScope.read(context);
    await provider.fetchNotifications(notifyLoading: false);
    if (!context.mounted) return;
    await Navigator.pushNamed(context, route);
    if (!context.mounted) return;
    await provider.fetchNotifications(notifyLoading: false);
  }
}
