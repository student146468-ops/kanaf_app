import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../router/kanaf_router.dart';
import '../services/api_service.dart';
import '../theme/kanaf_motion.dart';
import '../theme/kanaf_tokens.dart';
import '../widgets/kanaf_layout.dart';
import '../l10n/kanaf_localizations.dart';

/// شاشة تأكيد الرمز وتعيين كلمة المرور الجديدة.
///
/// كانت وهمية بالكامل: تأخير 1.5 ثانية ثم «تم تحديث كلمة المرور بنجاح»
/// وإرسال المستخدم لتسجيل الدخول — حيث يجد كلمته القديمة تعمل والجديدة
/// لا. الآن تستدعي `POST /api/auth/password-reset/confirm/` ولا تُعلن
/// النجاح إلا بتأكيد الخادم.
///
/// كما أضيف حقل **رمز التحقق** الذي لم يكن موجوداً أصلاً — الشاشة كانت
/// تغيّر كلمة المرور (نظرياً) بلا أي إثبات ملكية للبريد.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _codeFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _emailPrefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // البريد يأتي من الشاشة السابقة، فلا نطلبه من المستخدم مرتين.
    if (_emailPrefilled) return;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is String && arguments.trim().isNotEmpty) {
      _emailController.text = arguments.trim();
    }
    _emailPrefilled = true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _codeFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('reset.appBar')),
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
                      const SizedBox(height: KanafSpacing.xxl),
                      KanafStaggeredEntrance(index: 1, child: _buildFields()),
                      const SizedBox(height: KanafSpacing.xxl),
                      KanafStaggeredEntrance(
                        index: 2,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          icon: _isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            _isLoading
                                ? context.tr('common.loading')
                                : context.tr('reset.submit'),
                          ),
                        ),
                      ),
                      const SizedBox(height: KanafSpacing.md),
                      TextButton(
                        onPressed: _isLoading ? null : _goToLogin,
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
      title: context.tr('reset.title'),
      subtitle: context.tr('reset.subtitle'),
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enabled: !_isLoading,
          decoration: InputDecoration(
            labelText: context.tr('common.email'),
            prefixIcon: const Icon(Icons.mail_outline_rounded),
          ),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return context.tr('validation.emailRequired');
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
              return context.tr('validation.emailInvalid');
            }
            return null;
          },
          onFieldSubmitted: (_) => _codeFocus.requestFocus(),
        ),
        const SizedBox(height: KanafSpacing.lg),
        TextFormField(
          controller: _codeController,
          focusNode: _codeFocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          textAlign: TextAlign.center,
          enabled: !_isLoading,
          // ٦ أرقام بالضبط: نمنع الحروف والزيادة من لوحة المفاتيح.
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: context.texts.headlineSmall?.copyWith(
            letterSpacing: 10,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            labelText: context.tr('common.verificationCode'),
            hintText: context.tr('auth.codeHint'),
            counterText: '',
          ),
          validator: (value) {
            final code = value?.trim() ?? '';
            if (code.isEmpty) return context.tr('validation.codeRequired');
            if (code.length != 6) return context.tr('validation.codeLength');
            return null;
          },
          onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
        ),
        const SizedBox(height: KanafSpacing.lg),
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          enabled: !_isLoading,
          decoration: InputDecoration(
            labelText: context.tr('reset.newPassword'),
            helperText: context.tr('auth.passwordHelper'),
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          // نفس قواعد الخادم في `_is_valid_registration_password`.
          validator: (value) {
            final password = value?.trim() ?? '';
            if (password.isEmpty)
              return context.tr('validation.passwordRequired');
            if (password.length < 8)
              return context.tr('validation.passwordTooShort');
            if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
                !RegExp(r'[0-9]').hasMatch(password)) {
              return context.tr('validation.passwordWeak');
            }
            return null;
          },
          onChanged: (_) {
            if (_confirmController.text.isNotEmpty) {
              _formKey.currentState?.validate();
            }
          },
          onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
        ),
        const SizedBox(height: KanafSpacing.lg),
        TextFormField(
          controller: _confirmController,
          focusNode: _confirmFocus,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          enabled: !_isLoading,
          decoration: InputDecoration(
            labelText: context.tr('common.confirmPassword'),
            prefixIcon: const Icon(Icons.lock_reset_outlined),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          validator: (value) {
            final confirmation = value?.trim() ?? '';
            if (confirmation.isEmpty)
              return context.tr('validation.confirmPasswordRequired');
            if (confirmation != _passwordController.text.trim()) {
              return context.tr('validation.passwordMismatch');
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.confirmPasswordReset(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        password: _passwordController.text.trim(),
        passwordConfirm: _confirmController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      // الوصول إلى هنا يعني أن الخادم أكد التحديث فعلاً.
      _showMessage(context.tr('reset.success'));
      _goToLogin();
    } catch (error) {
      debugPrint('Password reset confirm failed: $error');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        error is ApiServiceException
            ? error.message
            : context.tr('reset.failed'),
      );
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      KanafRoutes.login,
      (route) => false,
    );
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
