import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../theme/kanaf_tokens.dart';
import '../utils/auth_navigation.dart';
import '../widgets/kanaf_layout.dart';
import '../l10n/kanaf_localizations.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;

  int? _userId;
  String _email = '';
  String? _role;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _userId = int.tryParse('${args['user_id'] ?? ''}');
      _email = (args['email'] ?? '').toString();
      _role = AuthNavigation.normalizeRole((args['role'] ?? '').toString());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('emailVerification.appBar')),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KanafHeroBand(
                        title: context.tr('emailVerification.title'),
                        subtitle: _email.isEmpty
                            ? context.tr('emailVerification.subtitle')
                            : context.tr(
                                'emailVerification.subtitleWithEmail',
                                args: {'email': _email},
                              ),
                      ),
                      const SizedBox(height: KanafSpacing.xxl),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        enabled: !_isVerifying && !_isResending,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        style: context.texts.headlineSmall,
                        decoration: InputDecoration(
                          labelText: context.tr('common.verificationCode'),
                          hintText: context.tr('auth.codeHint'),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final code = value?.trim() ?? '';
                          if (code.isEmpty) {
                            return context.tr('validation.codeRequired');
                          }
                          if (code.length != 6) {
                            return context.tr('validation.codeLength');
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _verify(),
                      ),
                      const SizedBox(height: KanafSpacing.xxl),
                      FilledButton.icon(
                        onPressed:
                            _isVerifying || _isResending ? null : _verify,
                        icon: _isVerifying
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                ),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: Text(
                          _isVerifying
                              ? context.tr('emailVerification.verifying')
                              : context.tr('emailVerification.verify'),
                        ),
                      ),
                      const SizedBox(height: KanafSpacing.md),
                      TextButton.icon(
                        onPressed:
                            _isVerifying || _isResending ? null : _resend,
                        icon: _isResending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(
                          _isResending
                              ? context.tr('emailVerification.resending')
                              : context.tr('emailVerification.resend'),
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

  Future<void> _verify() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_email.isEmpty) {
      _showMessage(context.tr('emailVerification.missingEmail'));
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final response = await _apiService.verifyEmailOtp(
        userId: _userId,
        email: _email,
        code: _codeController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isVerifying = false);
      unawaited(PushNotificationService.instance.registerCurrentDevice());
      if (_role != null) {
        await _apiService.saveActiveRole(_role!);
        if (!mounted) return;
      }
      AuthNavigation.navigateByRole(
        context,
        _role ?? AuthNavigation.roleFromAuthResponse(response),
      );
    } catch (error) {
      debugPrint('Email OTP verify failed: $error');
      if (!mounted) return;
      setState(() => _isVerifying = false);
      _showMessage(
        error is ApiServiceException
            ? error.message
            : context.tr('emailVerification.verifyFailed'),
      );
    }
  }

  Future<void> _resend() async {
    if (_email.isEmpty) {
      _showMessage(context.tr('emailVerification.missingEmail'));
      return;
    }

    setState(() => _isResending = true);
    try {
      await _apiService.resendEmailOtp(
        email: _email,
      );
      if (!mounted) return;
      setState(() => _isResending = false);
      _showMessage(context.tr('emailVerification.resendSuccess'));
    } catch (error) {
      debugPrint('Email OTP resend failed: $error');
      if (!mounted) return;
      setState(() => _isResending = false);
      _showMessage(
        error is ApiServiceException
            ? error.message
            : context.tr('emailVerification.resendFailed'),
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
