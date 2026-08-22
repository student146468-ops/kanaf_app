import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../router/kanaf_router.dart';
import '../services/api_service.dart';
import '../theme/kanaf_motion.dart';
import '../theme/kanaf_tokens.dart';
import '../utils/auth_navigation.dart';
import '../widgets/kanaf_layout.dart';

/// شاشة تسجيل الدخول.
///
/// ما أُصلح هنا بجانب المظهر:
/// * **تحقق حقيقي** بـ `Form` + `TextFormField` بدل فحص «غير فارغ» فقط.
/// * **دعم مدير كلمات المرور** عبر `AutofillGroup` و `autofillHints` —
///   غيابه كان يعني أن المستخدم يكتب بياناته يدوياً كل مرة.
/// * **تسلسل لوحة المفاتيح**: زر «التالي» ينقل للحقل التالي، و«تم» يُرسل.
/// * إزالة `setState` على كل تغيّر تركيز — كان يعيد بناء الشاشة كاملة
///   عند كل نقرة على حقل؛ الثيم يتولى حدود التركيز الآن.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KanafBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              // حد أقصى للعرض: على الأجهزة اللوحية يبقى النموذج
              // بعرض مقروء بدل أن يتمدد على كامل الشاشة.
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: KanafSpacing.xxl,
                  vertical: KanafSpacing.xxxl,
                ),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KanafStaggeredEntrance(index: 0, child: _buildHeader()),
                        const SizedBox(height: KanafSpacing.xxxl),
                        KanafStaggeredEntrance(
                          index: 1,
                          child: _buildEmailField(),
                        ),
                        const SizedBox(height: KanafSpacing.lg),
                        KanafStaggeredEntrance(
                          index: 2,
                          child: _buildPasswordField(),
                        ),
                        const SizedBox(height: KanafSpacing.sm),
                        KanafStaggeredEntrance(
                          index: 3,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pushNamed(
                                        context,
                                        KanafRoutes.forgotPassword,
                                      ),
                              child: const Text('نسيت كلمة المرور؟'),
                            ),
                          ),
                        ),
                        const SizedBox(height: KanafSpacing.lg),
                        KanafStaggeredEntrance(
                          index: 4,
                          child: _buildActions(),
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

  Widget _buildHeader() {
    // شريط متدرّج يحمل الشعار: يعطي الشاشة حضوراً بصرياً فورياً بدل
    // سطح محايد بالكامل، ويجعل هوية كَنَفْ أول ما تقع عليه العين.
    return const KanafHeroBand(
      title: 'مرحبًا بك في كَنَفْ',
      subtitle: 'سجّل الدخول لمتابعة كفالاتك وتبرعاتك',
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      autocorrect: false,
      enabled: !_isLoading,
      decoration: const InputDecoration(
        labelText: 'البريد الإلكتروني',
        hintText: 'name@example.com',
        prefixIcon: Icon(Icons.mail_outline_rounded),
      ),
      validator: _validateEmail,
      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: _obscurePassword,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: 'كلمة المرور',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscurePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'أدخل كلمة المرور';
        return null;
      },
      onFieldSubmitted: (_) => _handleLogin(),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        FilledButton(
          onPressed: _isLoading ? null : _handleLogin,
          child: _isLoading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('تسجيل الدخول'),
        ),
        const SizedBox(height: KanafSpacing.xl),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KanafSpacing.lg,
              ),
              child: Text('أو', style: context.texts.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: KanafSpacing.xl),
        OutlinedButton(
          onPressed: _isLoading
              ? null
              : () => Navigator.pushNamed(
                    context,
                    KanafRoutes.register,
                    // نمرّر الدور المختار مسبقاً حتى لا يُسأل عنه مرتين.
                    arguments: ModalRoute.of(context)?.settings.arguments,
                  ),
          child: const Text('إنشاء حساب جديد'),
        ),
      ],
    );
  }

  static String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'أدخل البريد الإلكتروني';
    // تحقق بنيوي بسيط: الصحة النهائية مسؤولية الخادم، لكن هذا يمنع
    // رحلة شبكة مؤكدة الفشل بسبب خطأ مطبعي واضح.
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(email)) return 'صيغة البريد الإلكتروني غير صحيحة';
    return null;
  }

  Future<void> _handleLogin() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      // إبلاغ النظام أن الدخول نجح ليحفظ مدير كلمات المرور البيانات.
      TextInput.finishAutofillContext();

      AuthNavigation.navigateByRole(
        context,
        AuthNavigation.roleFromAuthResponse(response),
      );
    } catch (error) {
      debugPrint('Login failed: $error');
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (error is PhoneVerificationRequiredException) {
        Navigator.of(context).pushNamed(
          KanafRoutes.phoneVerification,
          arguments: error.toRouteArguments(),
        );
        return;
      }
      _showError(
        error is ApiServiceException
            ? error.message
            : 'تعذر إكمال تسجيل الدخول حالياً. حاول مرة أخرى.',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'حسناً',
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }
}
