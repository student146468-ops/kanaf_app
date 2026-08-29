import 'package:flutter/material.dart';

import '../router/kanaf_router.dart';
import '../services/api_service.dart';
import '../theme/kanaf_tokens.dart';
import '../utils/auth_navigation.dart';
import '../widgets/kanaf_layout.dart';
import '../l10n/kanaf_localizations.dart';

/// ط´ط§ط´ط© ط§ظ„ط¨ط¯ط§ظٹط©.
///
/// ط§ظ„ط£ظ‡ظ… ظپظٹ ط¥ط¹ط§ط¯ط© ط§ظ„ط¨ظ†ط§ط،: ط§ظ„ط§ظ†طھط¸ط§ط± طµط§ط± **ظ…ط±طھط¨ط·ط§ظ‹ ط¨ط§ظ„ط¹ظ…ظ„ ط§ظ„ظپط¹ظ„ظٹ** ظ„ط§
/// ط¨ظ…ط¤ظ‚ظ‘طھ ط«ط§ط¨طھ. ط³ط§ط¨ظ‚ط§ظ‹ ظƒط§ظ† `Timer(4 seconds)` ظٹط­ط¨ط³ ط§ظ„ظ…ط³طھط®ط¯ظ… ط£ط±ط¨ط¹ ط«ظˆط§ظ†ظچ
/// ظƒط§ظ…ظ„ط© ط­طھظ‰ ظ„ظˆ ط§ظ†طھظ‡ظ‰ ظپط­طµ ط§ظ„ط¬ظ„ط³ط© ظپظٹ 50 ظ…ظ„ظ„ظٹ ط«ط§ظ†ظٹط©. ط§ظ„ط¢ظ† ظ†ظپط­طµ ط§ظ„ط¬ظ„ط³ط©
/// ظپظˆط±ط§ظ‹ ظˆظ†ظ†طھط¸ط± ط­ط¯ط§ظ‹ ط£ط¯ظ†ظ‰ ظ‚طµظٹط±ط§ظ‹ ظپظ‚ط· ظ„ظٹظƒطھظ…ظ„ ط¸ظ‡ظˆط± ط§ظ„ط´ط¹ط§ط± ط¨طµط±ظٹط§ظ‹.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// ط£ظ‚ظ„ ظ…ط¯ط© ط¹ط±ط¶. ط£ظ‚طµط± ظ…ظ†ظ‡ط§ ظٹط¬ط¹ظ„ ط§ظ„ط´ط§ط´ط© طھط¨ط¯ظˆ ظƒظˆظ…ظٹط¶ ط®ط§ط·ظپ.
  static const Duration _minimumDisplay = Duration(milliseconds: 1400);

  late final AnimationController _introController = AnimationController(
    duration: KanafDuration.slow,
    vsync: this,
  );

  late final AnimationController _breatheController = AnimationController(
    duration: const Duration(milliseconds: 2200),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _introController.forward();
    _breatheController.repeat(reverse: true);
    _resolveDestination();
  }

  @override
  void dispose() {
    _introController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  /// ظٹظپط­طµ ط§ظ„ط¬ظ„ط³ط© ظˆظٹظ†طھظ‚ظ„. ط§ظ„ط­ط¯ ط§ظ„ط£ط¯ظ†ظ‰ ظ„ظ„ط¹ط±ط¶ ظˆط§ظ„ظپط­طµ ظٹط¬ط±ظٹط§ظ† **ط¨ط§ظ„طھظˆط§ط²ظٹ**
  /// ط¹ط¨ط± `Future.wait`طŒ ظپط§ظ„ظ…ط³طھط®ط¯ظ… ظ„ط§ ظٹط¯ظپط¹ ط«ظ…ظ† ط§ظ„ط§ط«ظ†ظٹظ† ظ…طھطھط§ظ„ظٹظٹظ†.
  Future<void> _resolveDestination() async {
    final api = ApiService();

    final results = await Future.wait<Object?>([
      Future<void>.delayed(_minimumDisplay),
      _readSession(api),
    ]);

    if (!mounted) return;

    final session = results[1] as _Session?;
    if (session != null && session.isAuthenticated) {
      AuthNavigation.navigateByRole(
        context,
        session.role,
        showUnknownRoleMessage: false,
      );
      return;
    }

    Navigator.of(context).pushReplacementNamed(KanafRoutes.onboarding);
  }

  Future<_Session?> _readSession(ApiService api) async {
    try {
      final authenticated = await api.isAuthenticated();
      if (!authenticated) return const _Session(isAuthenticated: false);

      final role = await api.getSavedRole();

      // ظˆط¬ظˆط¯ ط±ظ…ط² ظ…ط­ظپظˆط¸ ظ„ط§ ظٹط¹ظ†ظٹ ط£ظ† ط§ظ„ط¬ظ„ط³ط© ظ…ط§ ط²ط§ظ„طھ طµط§ظ„ط­ط©: ظ‚ط¯ ظٹظƒظˆظ†
      // ط§ظ†طھظ‡ظ‰ ط£ظˆ ط£ظڈط¨ط·ظ„ ظ…ظ† ط§ظ„ط®ط§ط¯ظ… (طھط؛ظٹظٹط± ظƒظ„ظ…ط© ظ…ط±ظˆط±طŒ ط£ظˆ ط®ط±ظˆط¬ ظ…ظ† ط¬ظ‡ط§ط²
      // ط¢ط®ط±). ظƒظ†ط§ ظ†ط¯ط®ظ„ ط§ظ„ظ…ط³طھط®ط¯ظ… ط¥ظ„ظ‰ ظ‚ط³ظ…ظ‡ ط«ظ… طھظپط´ظ„ ط£ظˆظ„ ط¹ظ…ظ„ظٹط© ط£ظ…ط§ظ…ظ‡
      // ط¨ظ„ط§ طھظپط³ظٹط±. ظ†طھط­ظ‚ظ‚ ط§ظ„ط¢ظ† ط¨ظ†ط¯ط§ط، ظˆط§ط­ط¯ ط®ظپظٹظپ ظ‚ط¨ظ„ ط§ظ„ط¯ط®ظˆظ„.
      try {
        final me = await api.getMe();
        // ط§ظ„ط¯ظˆط± ط§ظ„ظ‚ط§ط¯ظ… ظ…ظ† ط§ظ„ط®ط§ط¯ظ… ط£ط­ط¯ط« ظ…ظ† ط§ظ„ظ…ط­ظپظˆط¸ ظ…ط­ظ„ظٹط§ظ‹.
        final freshRole = AuthNavigation.roleFromAuthResponse(me) ?? role;
        return _Session(isAuthenticated: true, role: freshRole);
      } on ApiServiceException catch (e) {
        // ط§ظ†ظ‚ط·ط§ط¹ ط§ظ„ط´ط¨ظƒط© ظ„ظٹط³ ط¯ظ„ظٹظ„ط§ظ‹ ط¹ظ„ظ‰ ط¨ط·ظ„ط§ظ† ط§ظ„ط¬ظ„ط³ط© â€” ظ†ط¯ط®ظ„ ط¨ط§ظ„ط¯ظˆط±
        // ط§ظ„ظ…ط­ظپظˆط¸ ط¨ط¯ظ„ ط·ط±ط¯ ظ…ط³طھط®ط¯ظ… طµط§ظ„ط­ ظ„ط£ظ†ظ‡ ط¨ظ„ط§ ط¥ظ†طھط±ظ†طھ ظ„ط­ط¸طھظ‡ط§.
        if (e.isConnectivity) {
          return _Session(isAuthenticated: true, role: role);
        }
        return const _Session(isAuthenticated: false);
      }
    } catch (_) {
      // طھط¹ط°ط± ظ‚ط±ط§ط،ط© ط§ظ„طھط®ط²ظٹظ† ط§ظ„ظ…ط­ظ„ظٹ: ظ†ط¹ط§ظ…ظ„ظ‡ ظƒط¹ط¯ظ… ظˆط¬ظˆط¯ ط¬ظ„ط³ط© ط¨ط¯ظ„
      // طھط¹ظ„ظٹظ‚ ط§ظ„ظ…ط³طھط®ط¯ظ… ط¹ظ„ظ‰ ط´ط§ط´ط© ط§ظ„ط¨ط¯ط§ظٹط© ط¥ظ„ظ‰ ط§ظ„ط£ط¨ط¯.
      return const _Session(isAuthenticated: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _introController,
                  curve: Curves.easeOut,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: KanafSpacing.xxl),
                    Text(
                      l10n.tr('app.name'),
                      style: context.texts.displaySmall?.copyWith(
                        color: KanafPalette.seed,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.xs),
                    Text(
                      l10n.tr('splash.tagline'),
                      style: context.texts.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.huge),
                    // ظ…ط¤ط´ط± ط®ط·ظٹ ط±ظ‚ظٹظ‚: ظٹظˆطµظ‘ظ„ آ«ط¬ط§ط±ظٹ ط§ظ„ط¹ظ…ظ„آ» ط¨ظ„ط§ ظ†ظ‚ط§ط·
                    // ظ…طµظ†ظˆط¹ط© ظٹط¯ظˆظٹط§ظ‹طŒ ظˆظٹطھط¨ط¹ ط§ظ„ط«ظٹظ… طھظ„ظ‚ط§ط¦ظٹط§ظ‹.
                    SizedBox(
                      width: 132,
                      child: ClipRRect(
                        borderRadius: KanafRadii.pill,
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(child: _SplashWaves()),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    // طھظ†ظپظ‘ط³ ظ‡ط§ط¯ط¦ (0.97 â†گ 1.03) ط¨ط¯ظ„ ظ†ط¨ط¶ ط­ط§ط¯ â€” ظٹظˆط­ظٹ ط¨ط§ظ„ط­ظٹط§ط© ظ„ط§ ط¨ط§ظ„ظ‚ظ„ظ‚.
    return ScaleTransition(
      scale: Tween<double>(begin: 0.97, end: 1.03).animate(
        CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
      ),
      child: const KanafLogo(size: 148),
    );
  }
}

class _Session {
  const _Session({required this.isAuthenticated, this.role});

  final bool isAuthenticated;
  final String? role;
}

/// ظ…ظˆط¬طھط§ظ† ط¨ط±طھظ‚ط§ظ„ظٹطھط§ظ† ط£ط³ظپظ„ ط§ظ„ط´ط§ط´ط© â€” ط£ط¨ط±ط² طھط¬ظ„ظچظ‘ ظ„ظ‡ظˆظٹط© ظƒظژظ†ظژظپظ’ ظپظٹ ط§ظ„طھط·ط¨ظٹظ‚طŒ
/// ظˆظ…ظ‚طµظˆط± ط¹ظ„ظ‰ ط´ط§ط´ط© ط§ظ„ط¨ط¯ط§ظٹط© ط­طھظ‰ ظٹط¨ظ‚ظ‰ ط§ط³طھط«ظ†ط§ط،ظ‹ ظ„ط§ ظ†ظ…ط·ط§ظ‹ ظ…طھظƒط±ط±ط§ظ‹.
class _SplashWaves extends StatelessWidget {
  const _SplashWaves();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final waveHeight = (screenHeight * 0.20).clamp(138.0, 178.0);

    return SizedBox(
      height: waveHeight,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: const _WaveClipper(layer: _WaveLayer.back),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      KanafPalette.ember.withOpacity(0.42),
                      KanafPalette.ember.withOpacity(0.66),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: waveHeight * 0.82,
            child: const ClipPath(
              clipper: _WaveClipper(layer: _WaveLayer.front),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [KanafPalette.ember, KanafPalette.seed],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _WaveLayer { back, front }

class _WaveClipper extends CustomClipper<Path> {
  const _WaveClipper({required this.layer});

  final _WaveLayer layer;

  @override
  Path getClip(Size size) {
    final isBack = layer == _WaveLayer.back;
    final startY = size.height * (isBack ? 0.28 : 0.24);

    return Path()
      ..moveTo(0, startY)
      ..cubicTo(
        size.width * 0.18,
        size.height * (isBack ? 0.08 : 0.44),
        size.width * 0.36,
        size.height * (isBack ? 0.14 : 0.02),
        size.width * 0.52,
        size.height * (isBack ? 0.27 : 0.19),
      )
      ..cubicTo(
        size.width * 0.68,
        size.height * (isBack ? 0.41 : 0.36),
        size.width * 0.82,
        size.height * 0.08,
        size.width,
        size.height * (isBack ? 0.22 : 0.18),
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _WaveClipper oldClipper) =>
      oldClipper.layer != layer;
}
