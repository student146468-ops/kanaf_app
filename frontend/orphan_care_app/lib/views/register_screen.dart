import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../router/kanaf_router.dart';
import '../services/api_service.dart';
import '../theme/kanaf_motion.dart';
import '../theme/kanaf_tokens.dart';
import '../utils/auth_navigation.dart';
import '../widgets/kanaf_layout.dart';
import '../l10n/kanaf_localizations.dart';

/// شاشة إنشاء الحساب.
///
/// أهم تحسين وظيفي: التحقق صار **داخل الحقول** عبر `TextFormField`
/// بدل سلسلة `if` ترسل رسائل SnackBar متتالية. الفارق للمستخدم كبير:
/// الخطأ يظهر أسفل الحقل المعني ويبقى معروضاً حتى يُصلح، بدل رسالة
/// عابرة لا تدل على الحقل الخاطئ.
///
/// كما يعرض الدور المختار بوضوح — سابقاً كان مخفياً تماماً، فالمستخدم
/// لا يعرف أنه ينشئ حساب متطوع مثلاً حتى يدخل التطبيق.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.selectedRole});

  final String? selectedRole;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// الدور يأتي إما كوسيط بنّاء أو كوسيط مسار (عند القدوم من الدخول).
  String? get _role {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final routeRole = arguments is String ? arguments : null;
    return AuthNavigation.normalizeRole(widget.selectedRole ?? routeRole);
  }

  @override
  Widget build(BuildContext context) {
    final role = _role;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('auth.registerTitle')),
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
                  KanafSpacing.lg,
                  KanafSpacing.xxl,
                  KanafSpacing.xxxl,
                ),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (role != null)
                          KanafStaggeredEntrance(
                            index: 0,
                            child: _RoleBanner(role: role),
                          ),
                        const SizedBox(height: KanafSpacing.xl),
                        KanafStaggeredEntrance(
                          index: 1,
                          child: _buildFields(),
                        ),
                        const SizedBox(height: KanafSpacing.xxl),
                        KanafStaggeredEntrance(
                          index: 2,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            child: _isLoading
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(context.tr('auth.registerButton')),
                          ),
                        ),
                        const SizedBox(height: KanafSpacing.md),
                        TextButton(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          child: Text(context.tr('auth.haveAccount')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          enabled: !_isLoading,
          decoration: InputDecoration(
            labelText: context.tr('common.name'),
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ),
          validator: (value) {
            final name = value?.trim() ?? '';
            if (name.isEmpty) return context.tr('validation.nameRequired');
            if (name.length < 3) return context.tr('validation.nameShort');
            return null;
          },
          onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
        ),
        const SizedBox(height: KanafSpacing.lg),
        TextFormField(
          controller: _phoneController,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          enabled: !_isLoading,
          // 10 أرقام فقط، والحروف ممنوعة من الأساس.
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            labelText: context.tr('common.phone'),
            hintText: context.tr('auth.phoneHint'),
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
          validator: (value) {
            final phone = value?.trim() ?? '';
            if (phone.isEmpty) return context.tr('validation.phoneRequired');
            if (!RegExp(r'^(091|092|093|094)[0-9]{7}$').hasMatch(phone)) {
              return context.tr('validation.phoneInvalid');
            }
            return null;
          },
          onFieldSubmitted: (_) => _emailFocus.requestFocus(),
        ),
        const SizedBox(height: KanafSpacing.lg),
        TextFormField(
          controller: _emailController,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newUsername],
          autocorrect: false,
          enabled: !_isLoading,
          decoration: InputDecoration(
            labelText: context.tr('common.email'),
            hintText: context.tr('auth.emailHint'),
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
            labelText: context.tr('common.password'),
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
          validator: (value) {
            final password = value ?? '';
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
          // إعادة التحقق من حقل التأكيد عند تغيير كلمة المرور، وإلا
          // بقي خطأ «غير متطابقين» معروضاً بعد تصحيح المشكلة.
          onChanged: (_) {
            if (_confirmPasswordController.text.isNotEmpty) {
              _formKey.currentState?.validate();
            }
          },
          onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
        ),
        const SizedBox(height: KanafSpacing.lg),
        TextFormField(
          controller: _confirmPasswordController,
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
            if (value == null || value.isEmpty)
              return context.tr('validation.confirmPasswordRequired');
            if (value != _passwordController.text) {
              return context.tr('validation.passwordMismatch');
            }
            return null;
          },
          onFieldSubmitted: (_) => _handleRegister(),
        ),
      ],
    );
  }

  Future<void> _handleRegister() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final role = _role;
    if (role == null) {
      _showMessage(context.tr('auth.roleRequired'));
      Navigator.of(context).pushNamedAndRemoveUntil(
        KanafRoutes.roleSelection,
        (route) => false,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final response = await _apiService.register({
        'username': email,
        'email': email,
        'password': _passwordController.text,
        'password_confirm': _confirmPasswordController.text,
        'first_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'role': role,
      });

      if (!mounted) return;
      setState(() => _isLoading = false);
      TextInput.finishAutofillContext();

      if (response['requires_phone_verification'] == true) {
        Navigator.of(context).pushReplacementNamed(
          KanafRoutes.phoneVerification,
          arguments: response,
        );
        return;
      }

      AuthNavigation.navigateByRole(
        context,
        AuthNavigation.roleFromAuthResponse(response),
      );
    } catch (error) {
      debugPrint('Register failed: $error');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        error is ApiServiceException
            ? error.message
            : context.tr('auth.registerFailed'),
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

/// يعرض الدور المختار بوضوح مع إمكانية تغييره.
class _RoleBanner extends StatelessWidget {
  const _RoleBanner({required this.role});

  final String role;

  static const Map<String, (String, IconData)> _labels = {
    AuthNavigation.donorRole: ('role.donor', Icons.favorite_outline_rounded),
    AuthNavigation.volunteerRole: ('role.volunteer', Icons.handshake_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final (labelKey, icon) =
        _labels[role] ?? ('role.account', Icons.person_outline);

    return KanafCard(
      color: scheme.primaryContainer,
      borderColor: scheme.primary.withOpacity(0.35),
      child: Row(
        children: [
          Icon(icon, color: scheme.onPrimaryContainer),
          const SizedBox(width: KanafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    'auth.accountType',
                    args: {'role': context.tr(labelKey)},
                  ),
                  style: context.texts.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: KanafSpacing.xxs),
                Text(
                  context.tr('auth.accountTypeSubtitle'),
                  style: context.texts.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              KanafRoutes.roleSelection,
              (route) => false,
            ),
            child: Text(context.tr('common.update')),
          ),
        ],
      ),
    );
  }
}
