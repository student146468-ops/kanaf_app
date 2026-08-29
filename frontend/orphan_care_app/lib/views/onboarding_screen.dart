import 'package:flutter/material.dart';

import '../router/kanaf_router.dart';
import '../theme/kanaf_tokens.dart';
import '../widgets/kanaf_layout.dart';
import '../l10n/kanaf_localizations.dart';

/// شاشة الترحيب.
///
/// أُعيد بناؤها على الثيم مع تحسينين وظيفيين:
/// * الصور تحصل على `errorBuilder` — سابقاً كان غياب أصل صورة يكسر
///   الشاشة بمستطيل خطأ رمادي.
/// * زر «رجوع» يظهر بعد الشريحة الأولى، فالتنقل صار ذا اتجاهين.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_Slide> _slides = [
    _Slide(
      titleKey: 'onboarding.slide1Title',
      descriptionKey: 'onboarding.slide1Description',
      imagePath: 'assets/images/image12.png',
      fallbackIcon: Icons.volunteer_activism_rounded,
    ),
    _Slide(
      titleKey: 'onboarding.slide2Title',
      descriptionKey: 'onboarding.slide2Description',
      imagePath: 'assets/images/image11.png',
      fallbackIcon: Icons.handshake_rounded,
    ),
    _Slide(
      titleKey: 'onboarding.slide3Title',
      descriptionKey: 'onboarding.slide3Description',
      imagePath: 'assets/images/image14.png',
      fallbackIcon: Icons.favorite_rounded,
    ),
  ];

  bool get _isLastPage => _currentPage == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_isLastPage) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: KanafDuration.emphasized,
      curve: KanafCurves.emphasized,
    );
  }

  void _goBack() {
    _pageController.previousPage(
      duration: KanafDuration.emphasized,
      curve: KanafCurves.emphasized,
    );
  }

  void _finish() {
    Navigator.of(context).pushReplacementNamed(KanafRoutes.roleSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KanafBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KanafSpacing.md,
                        vertical: KanafSpacing.sm,
                      ),
                      child: TextButton(
                        onPressed: _finish,
                        child: Text(context.tr('onboarding.skip')),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) =>
                          setState(() => _currentPage = index),
                      itemCount: _slides.length,
                      itemBuilder: (context, index) =>
                          _SlideView(slide: _slides[index]),
                    ),
                  ),
                  _buildIndicator(),
                  const SizedBox(height: KanafSpacing.xl),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// مؤشر الصفحات: الشريحة النشطة تتمدد إلى كبسولة بلون الهوية.
  /// التمدد يوصّل الموضع أفضل من مجرد تغيير اللون.
  Widget _buildIndicator() {
    final scheme = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _slides.length; i++)
          AnimatedContainer(
            duration: KanafDuration.standard,
            curve: KanafCurves.emphasized,
            margin: const EdgeInsets.symmetric(horizontal: KanafSpacing.xs),
            width: i == _currentPage ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == _currentPage
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              borderRadius: KanafRadii.pill,
            ),
          ),
      ],
    );
  }

  Widget _buildActions() {
    // زر واحد بعرض كامل. النسخة السابقة كانت تحجز 56 بكسل لزر رجوع
    // يظهر ويختفي، فينشأ فراغ غير متماثل على حافة واحدة. الرجوع متاح
    // بالسحب وبإيماءة النظام، و«تخطي» أعلى الشاشة — فلا حاجة لزر ثالث.
    return KanafActionBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: _goNext,
            icon: Icon(
              _isLastPage ? Icons.login_rounded : Icons.arrow_back_rounded,
            ),
            label: Text(_isLastPage
                ? context.tr('onboarding.start')
                : context.tr('onboarding.next')),
          ),
          SizedBox(
            height: 44,
            child: _currentPage == 0
                ? null
                : TextButton.icon(
                    onPressed: _goBack,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(context.tr('onboarding.previous')),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.titleKey,
    required this.descriptionKey,
    required this.imagePath,
    required this.fallbackIcon,
  });

  final String titleKey;
  final String descriptionKey;
  final String imagePath;
  final IconData fallbackIcon;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KanafSpacing.xxl),
      child: Column(
        children: [
          // نسب ثابتة (٥ للصورة، ٤ للنص) بدل `Expanded` يبتلع كل
          // المساحة المتبقية — سابقاً كانت الصورة تسبح وسط فراغ واسع
          // والنص ملتصقاً بالأسفل، فيبدو الإيقاع الرأسي عشوائياً.
          const Spacer(flex: 1),
          Expanded(
            flex: 10,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: KanafRadii.xl,
                  boxShadow: [
                    BoxShadow(
                      color: KanafPalette.seed.withOpacity(0.16),
                      blurRadius: 34,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: KanafRadii.xl,
                  child: Image.asset(
                    slide.imagePath,
                    fit: BoxFit.contain,
                    // غياب أصل الصورة لا يجوز أن يكسر الشاشة.
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: KanafRadii.xl,
                      ),
                      child: Icon(
                        slide.fallbackIcon,
                        size: 88,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: KanafSpacing.xxxl),
          Text(
            context.tr(slide.titleKey),
            textAlign: TextAlign.center,
            style: context.texts.headlineMedium,
          ),
          const SizedBox(height: KanafSpacing.md),
          Text(
            context.tr(slide.descriptionKey),
            textAlign: TextAlign.center,
            style: context.texts.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
