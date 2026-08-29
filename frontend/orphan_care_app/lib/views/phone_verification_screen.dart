import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme/kanaf_tokens.dart';
import '../utils/auth_navigation.dart';
import '../widgets/kanaf_layout.dart';
import '../l10n/kanaf_localizations.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;

  int? _userId;
  String _email = '';
  String _phoneNumber = '';
  String? _role;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _userId = int.tryParse('${args['user_id'] ?? ''}');
      _email = (args['email'] ?? '').toString();
      _phoneNumber = (args['phone_number'] ?? '').toString();
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
        title: Text(context.tr('phone.appBar')),
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
                        title: context.tr('phone.title'),
                        subtitle: _phoneNumber.isEmpty
                            ? context.tr('phone.subtitle')
                            : context.tr(
                                'phone.subtitleWithNumber',
                                args: {'phone': _phoneNumber},
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
                          prefixIcon: const Icon(Icons.sms_outlined),
                        ),
                        validator: (value) {
                          final code = value?.trim() ?? '';
                          if (code.isEmpty)
                            return context.tr('validation.codeRequired');
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
                        label: Text(_isVerifying
                            ? context.tr('phone.verifying')
                            : context.tr('phone.verify')),
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
                        label: Text(_isResending
                            ? context.tr('phone.resending')
                            : context.tr('phone.resend')),
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
    if (_phoneNumber.isEmpty) {
      _showMessage(context.tr('phone.missingPhone'));
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final response = await _apiService.verifyPhoneOtp(
        userId: _userId,
        email: _email,
        phoneNumber: _phoneNumber,
        code: _codeController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isVerifying = false);
      AuthNavigation.navigateByRole(
        context,
        AuthNavigation.roleFromAuthResponse(response) ?? _role,
      );
    } catch (error) {
      debugPrint('Phone OTP verify failed: $error');
      if (!mounted) return;
      setState(() => _isVerifying = false);
      _showMessage(
        error is ApiServiceException
            ? error.message
            : context.tr('phone.verifyFailed'),
      );
    }
  }

  Future<void> _resend() async {
    if (_phoneNumber.isEmpty) {
      _showMessage(context.tr('phone.missingPhone'));
      return;
    }

    setState(() => _isResending = true);
    try {
      await _apiService.resendPhoneOtp(
        email: _email,
        phoneNumber: _phoneNumber,
      );
      if (!mounted) return;
      setState(() => _isResending = false);
      _showMessage(context.tr('phone.resendSuccess'));
    } catch (error) {
      debugPrint('Phone OTP resend failed: $error');
      if (!mounted) return;
      setState(() => _isResending = false);
      _showMessage(
        error is ApiServiceException
            ? error.message
            : context.tr('phone.resendFailed'),
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
