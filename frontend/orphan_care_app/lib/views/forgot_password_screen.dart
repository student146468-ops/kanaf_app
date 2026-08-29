import 'package:flutter/material.dart';

import '../router/kanaf_router.dart';
import '../services/api_service.dart';
import '../theme/kanaf_motion.dart';
import '../theme/kanaf_tokens.dart';
import '../widgets/kanaf_layout.dart';
import '../l10n/kanaf_localizations.dart';

/// شاشة طلب رمز استعادة كلمة المرور.
///
/// كانت هذه الشاشة وهمية بالكامل: `Future.delayed(1500ms)` ثم رسالة
/// «تم إرسال رمز التحقق» بلا أي استدعاء شبكة — ولا وجود لنقطة نهاية
/// في الخادم من الأساس. الآن تستدعي
/// `POST /api/auth/password-reset/` فعلاً، ولا تنتقل للخطوة التالية
/// إلا إذا قَبِل الخادم الطلب.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('forgot.appBar')),
        leading: const BackButton(),
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  KanafSpacing.xxl,
                  KanafSpacing.xxl,
                  KanafSpacing.xxl,
                  KanafSpacing.xxxl,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KanafStaggeredEntrance(index: 0, child: _buildHeader()),
                      const SizedBox(height: KanafSpacing.xxxl),
                      KanafStaggeredEntrance(
                        index: 1,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: context.tr('common.email'),
                            hintText: context.tr('auth.emailHint'),
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty)
                              return context.tr('validation.emailRequired');
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(email)) {
                              return context.tr('validation.emailInvalid');
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _requestCode(),
                        ),
                      ),
                      const SizedBox(height: KanafSpacing.xxl),
                      KanafStaggeredEntrance(
                        index: 2,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _requestCode,
                          icon: _isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            _isLoading
                                ? context.tr('phone.resending')
                                : context.tr('forgot.sendCode'),
                          ),
                        ),
                      ),
                      const SizedBox(height: KanafSpacing.md),
                      TextButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        child: Text(context.tr('forgot.backToLogin')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return KanafHeroBand(
      showLogo: false,
      title: context.tr('forgot.title'),
      subtitle: context.tr('forgot.subtitle'),
    );
  }

  Future<void> _requestCode() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final email = _emailController.text.trim();
    setState(() => _isLoading = true);
    try {
      await _apiService.requestPasswordReset(email);
      if (!mounted) return;
      setState(() => _isLoading = false);

      // الخادم يعيد 200 حتى لبريد غير مسجّل (منعاً لجرد الحسابات)،
      // فالرسالة صيغت لتكون صادقة في الحالتين.
      _showMessage(
        context.tr('forgot.sentIfExists'),
      );
      await Navigator.pushNamed(
        context,
        KanafRoutes.resetPassword,
        // البريد يُمرَّر للخطوة التالية: تأكيد الرمز يحتاجه.
        arguments: email,
      );
    } catch (error) {
      debugPrint('Password reset request failed: $error');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        error is ApiServiceException
            ? error.message
            : context.tr('forgot.sendFailed'),
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: context.tr('common.ok'),
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }
}
