import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app_provider.dart';

class AppProviderScope extends StatelessWidget {
  const AppProviderScope({
    super.key,
    required AppProvider provider,
    required this.child,
  }) : _provider = provider;

  final AppProvider _provider;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppProvider>.value(
      value: _provider,
      child: _AppProviderInherited(
        provider: _provider,
        child: child,
      ),
    );
  }

  static AppProvider of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_AppProviderInherited>();
    assert(scope != null, 'AppProviderScope was not found in the widget tree.');
    return scope!.notifier!;
  }

  static AppProvider read(BuildContext context) {
    return context.read<AppProvider>();
  }

  static AppProvider watch(BuildContext context) {
    return context.watch<AppProvider>();
  }
}

class _AppProviderInherited extends InheritedNotifier<AppProvider> {
  const _AppProviderInherited({
    required AppProvider provider,
    required super.child,
  }) : super(notifier: provider);
}
