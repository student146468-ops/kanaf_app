import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../l10n/kanaf_localizations.dart';

/// تغيير كلمة المرور من داخل الحساب.
///
/// كانت هذه الشاشة تحمل التعليق `TODO: Connect password update to
/// backend` ثم تعرض «تم حفظ كلمة المرور بنجاح» مباشرة — بلا أي
/// استدعاء شبكة، ولا وجود لنقطة نهاية في الخادم. الآن تستدعي
/// `POST /api/auth/change-password/` ولا تُعلن النجاح إلا بتأكيده.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _isSaving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings.changePassword')),
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
                  KanafSpacing.pageInset,
                  KanafSpacing.xl,
                  KanafSpacing.pageInset,
                  KanafSpacing.xxxl,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KanafStaggeredEntrance(index: 0, child: _buildNotice()),
                      const SizedBox(height: KanafSpacing.xl),
                      KanafStaggeredEntrance(index: 1, child: _buildFields()),
                      const SizedBox(height: KanafSpacing.xxl),
                      KanafStaggeredEntrance(
                        index: 2,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _submit,
                          icon: _isSaving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.shield_outlined),
                          label: Text(
                            _isSaving
                                ? context.tr('settings.saving')
                                : context.tr('settings.savePassword'),
                          ),
                        ),
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

  Widget _buildNotice() {
    final semantic = context.semantic;
    return Container(
      padding: const EdgeInsets.all(KanafSpacing.md),
      decoration: BoxDecoration(
        color: semantic.warningContainer,
        borderRadius: KanafRadii.md,
      ),
      child: Row(
        children: [
          Icon(Icons.devices_outlined, size: 20, color: semantic.warning),
          const SizedBox(width: KanafSpacing.md),
          Expanded(
            child: Text(
              context.tr('settings.passwordChangeNotice'),
              style: context.texts.bodySmall?.copyWith(
                color: semantic.onWarningContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        TextFormField(
          controller: _currentController,
          obscureText: _obscureCurrent,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.password],
          enabled: !_isSaving,
          decoration: InputDecoration(
            labelText: context.tr('settings.currentPassword'),
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
              icon: Icon(
                _obscureCurrent
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return context.tr('settings.currentPasswordRequired');
            }
            return null;
          },
          onFieldSubmitted: (_) => _newFocus.requestFocus(),
        ),
        const SizedBox(height: KanafSpacing.lg),
        TextFormField(
          controller: _newController,
          focusNode: _newFocus,
          obscureText: _obscureNew,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          enabled: !_isSaving,
          decoration: InputDecoration(
            labelText: context.tr('reset.newPassword'),
            prefixIcon: const Icon(Icons.key_outlined),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
              icon: Icon(
                _obscureNew
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          // نفس قواعد الخادم في `_is_valid_registration_password`.
          validator: (value) {
            final password = value ?? '';
            if (password.isEmpty) {
              return context.tr('settings.newPasswordRequired');
            }
            if (password.length < 8) {
              return context.tr('validation.passwordTooShort');
            }
            if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
                !RegExp(r'[0-9]').hasMatch(password)) {
              return context.tr('validation.passwordWeak');
            }
            if (password == _currentController.text) {
              return context.tr('settings.newPasswordSameAsCurrent');
            }
            return null;
          },
          onChanged: (_) {
            setState(() {});
            if (_confirmController.text.isNotEmpty) {
              _formKey.currentState?.validate();
            }
          },
          onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
        ),
        const SizedBox(height: KanafSpacing.md),
        _PasswordStrengthBar(password: _newController.text),
        const SizedBox(height: KanafSpacing.lg),
        TextFormField(
          controller: _confirmController,
          focusNode: _confirmFocus,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          enabled: !_isSaving,
          decoration: InputDecoration(
            labelText: context.tr('settings.confirmNewPassword'),
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
            if (value == null || value.isEmpty) {
              return context.tr('settings.confirmNewPasswordRequired');
            }
            if (value != _newController.text) {
              return context.tr('settings.confirmNewPasswordMismatch');
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

    setState(() => _isSaving = true);
    try {
      await _apiService.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
        newPasswordConfirm: _confirmController.text,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);

      // الوصول إلى هنا يعني أن الخادم أكد التغيير وأعاد رموزاً جديدة.
      _showMessage(context.tr('settings.passwordChanged'));
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Change password failed: $error');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(
        error is ApiServiceException
            ? error.message
            : context.tr('settings.passwordChangeFailed'),
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: context.tr('common.ok'),
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }
}

/// مؤشر قوة كلمة المرور.
///
/// يقيس التنوع (أحرف صغيرة/كبيرة/أرقام/رموز) مع الطول. الغرض إرشادي:
/// القبول أو الرفض يقرره التحقق والخادم، وهذا يوجّه المستخدم نحو
/// كلمة أقوى بدل أن يكتفي بالحد الأدنى.
class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final scheme = context.colors;
    final semantic = context.semantic;
    final score = _score(password);

    final (String label, Color color) = switch (score) {
      <= 2 => (context.tr('settings.passwordWeak'), scheme.error),
      3 => (context.tr('settings.passwordMedium'), semantic.warning),
      _ => (context.tr('settings.passwordStrong'), semantic.success),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KanafSpacing.xxs,
                  ),
                  child: AnimatedContainer(
                    duration: KanafDuration.quick,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < score ? color : scheme.surfaceContainerHighest,
                      borderRadius: KanafRadii.pill,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: KanafSpacing.sm),
        Text(
          context.tr('settings.passwordStrength', args: {'label': label}),
          style: context.texts.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }

  static int _score(String password) {
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return score.clamp(0, 5);
  }
}
