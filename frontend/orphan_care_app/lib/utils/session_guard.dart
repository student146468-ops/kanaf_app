import 'package:flutter/material.dart';

import '../providers/app_provider.dart';
import '../router/kanaf_router.dart';
import '../services/api_service.dart';

/// حارس الجلسة على مستوى التطبيق.
///
/// كان انتهاء الجلسة يُعالَج بمسح الرمز **بصمت** داخل معترض Dio. النتيجة
/// أن المستخدم يبقى أمام شاشته وقد فقد صلاحيته: كل ضغطة بعدها تفشل
/// برسالة غامضة، وهو لا يعرف أن عليه تسجيل الدخول من جديد.
///
/// هذا المكوّن يستمع لإشارة واحدة من `ApiService`، فيمسح حالة التطبيق
/// ويعيد المستخدم إلى تسجيل الدخول مع سبب واضح — مرة واحدة مهما بلغ
/// عدد الطلبات التي فشلت معاً.
class KanafSessionGuard extends StatefulWidget {
  const KanafSessionGuard({
    super.key,
    required this.navigatorKey,
    required this.provider,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final AppProvider provider;
  final Widget child;

  @override
  State<KanafSessionGuard> createState() => _KanafSessionGuardState();
}

class _KanafSessionGuardState extends State<KanafSessionGuard> {
  late int _lastHandled = ApiService.sessionExpiredSignal.value;

  @override
  void initState() {
    super.initState();
    ApiService.sessionExpiredSignal.addListener(_onSessionExpired);
  }

  @override
  void dispose() {
    ApiService.sessionExpiredSignal.removeListener(_onSessionExpired);
    super.dispose();
  }

  void _onSessionExpired() {
    final signal = ApiService.sessionExpiredSignal.value;
    // عدة طلبات تفشل معاً عند انتهاء الجلسة؛ نتعامل مع الحدث مرة واحدة.
    if (signal == _lastHandled) return;
    _lastHandled = signal;

    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;

    widget.provider.clearAll();

    navigator.pushNamedAndRemoveUntil(KanafRoutes.login, (route) => false);

    final messengerContext = navigator.context;
    ScaffoldMessenger.maybeOf(messengerContext)?.showSnackBar(
      const SnackBar(
        content: Text('انتهت صلاحية جلستك. سجّل الدخول من جديد.'),
        duration: Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
