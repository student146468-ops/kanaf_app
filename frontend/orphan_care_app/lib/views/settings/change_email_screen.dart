import 'package:flutter/material.dart';

import '../../providers/app_provider_scope.dart';
import '../../services/api_service.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';

/// تغيير البريد الإلكتروني للحساب.
///
/// شاشة جديدة كلياً: لم يكن للمستخدم أي طريقة لتغيير بريده رغم أن
/// البريد هو معرّف الدخول ووسيلة استعادة الحساب.
///
/// تشترط كلمة المرور الحالية لأن من يغيّر البريد يملك الحساب فعلياً —
/// جهاز مفتوح بلا هذا الشرط يعني استيلاءً كاملاً.
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _isSaving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // الجلب في initState لا في build — الجلب داخل build يُنتج حلقة
    // طلبات عند الفشل لأن notifyListeners يعيد البناء.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = AppProviderScope.of(context);
      if (provider.currentUser.isEmpty && !provider.isLoading) {
        provider.fetchCurrentUser(notifyLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppProviderScope.of(context);
    final currentEmail = provider.currentUser['email']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تغيير البريد الإلكتروني'),
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
                      KanafStaggeredEntrance(
                        index: 0,
                        child: _buildCurrentEmail(currentEmail),
                      ),
                      const SizedBox(height: KanafSpacing.xl),
                      KanafStaggeredEntrance(
                        index: 1,
                        child: _buildFields(currentEmail),
                      ),
                      const SizedBox(height: KanafSpacing.lg),
                      KanafStaggeredEntrance(index: 2, child: _buildNotice()),
                      const SizedBox(height: KanafSpacing.xxl),
                      KanafStaggeredEntrance(
                        index: 3,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _submit,
                          icon: _isSaving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.mark_email_read_outlined),
                          label: Text(
                            _isSaving ? 'جاري الحفظ...' : 'حفظ البريد الجديد',
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

  Widget _buildCurrentEmail(String currentEmail) {
    final scheme = context.colors;
    return KanafCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: KanafRadii.sm,
            ),
            child: Icon(Icons.alternate_email_rounded, color: scheme.primary),
          ),
          const SizedBox(width: KanafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('البريد الحالي', style: context.texts.bodySmall),
                const SizedBox(height: KanafSpacing.xxs),
                Text(
                  currentEmail.isEmpty ? 'جاري التحميل...' : currentEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFields(String currentEmail) {
    return Column(
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enabled: !_isSaving,
          decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني الجديد',
            hintText: 'name@example.com',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return 'أدخل البريد الإلكتروني الجديد';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
              return 'صيغة البريد الإلكتروني غير صحيحة';
            }
            if (currentEmail.isNotEmpty &&
                email.toLowerCase() == currentEmail.toLowerCase()) {
              return 'هذا هو بريدك الحالي بالفعل';
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
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          enabled: !_isSaving,
          decoration: InputDecoration(
            labelText: 'كلمة المرور الحالية',
            helperText: 'للتأكد من أنك صاحب الحساب',
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
            if (value == null || value.isEmpty) {
              return 'أدخل كلمة المرور الحالية';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ],
    );
  }

  Widget _buildNotice() {
    final semantic = context.semantic;
    return Container(
      padding: const EdgeInsets.all(KanafSpacing.md),
      decoration: BoxDecoration(
        color: semantic.infoContainer,
        borderRadius: KanafRadii.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: semantic.info),
          const SizedBox(width: KanafSpacing.md),
          Expanded(
            child: Text(
              'ستسجّل الدخول بالبريد الجديد بعد التغيير، وسيصل إشعار إلى '
              'بريدك القديم، ويُسجَّل خروج الأجهزة الأخرى.',
              style: context.texts.bodySmall?.copyWith(
                color: semantic.onInfoContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _isSaving = true);
    final provider = AppProviderScope.of(context);
    try {
      await _apiService.changeEmail(
        newEmail: _emailController.text.trim(),
        currentPassword: _passwordController.text,
      );
      if (!mounted) return;

      // نعيد جلب المستخدم حتى تعرض بقية الشاشات البريد الجديد فوراً.
      await provider.fetchCurrentUser(notifyLoading: false);
      if (!mounted) return;
      setState(() => _isSaving = false);

      _showMessage('تم تحديث البريد الإلكتروني بنجاح.');
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Change email failed: $error');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(
        error is ApiServiceException
            ? error.message
            : 'تعذر تغيير البريد الإلكتروني حالياً. حاول مرة أخرى.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'حسناً',
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }
}
