import 'package:flutter/material.dart';

import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';

/// التقديم على فرصة تطوع.
///
/// أُصلح فيها عيبان:
///
/// 1. كانت تتجاهل القيمة المعادة من `applyToVolunteerOpportunity`
///    وتقرأ `provider.errorMessage` بدلاً منها — وهي قيمة قد تكون
///    متبقية من عملية سابقة، فتظهر رسالة خطأ بعد نجاح أو العكس.
/// 2. كانت ترسل `has_attachment` و`points` و`hours_worked` وحقولاً
///    أخرى لا وجود لها في `VolunteerApplication` (الذي يقبل
///    `message` فقط من العميل) — بيانات تُرمى صامتة.
class ApplyOpportunityView extends StatefulWidget {
  const ApplyOpportunityView({super.key});

  @override
  State<ApplyOpportunityView> createState() => _ApplyOpportunityViewState();
}

class _ApplyOpportunityViewState extends State<ApplyOpportunityView> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _skillsController = TextEditingController();
  final _skillsFocus = FocusNode();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _skillsController.dispose();
    _skillsFocus.dispose();
    super.dispose();
  }

  /// الفرصة تُمرَّر إما مباشرة أو داخل مفتاح `opportunity`.
  Map<String, dynamic> get _opportunity {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['opportunity'] is Map) {
      return Map<String, dynamic>.from(args['opportunity'] as Map);
    }
    if (args is Map) return Map<String, dynamic>.from(args);
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final opportunity = _opportunity;
    final title = opportunity['title']?.toString() ?? 'فرصة تطوع';

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقديم على الفرصة'),
        leading: const BackButton(),
      ),
      body: KanafBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      KanafSpacing.pageInset,
                      KanafSpacing.lg,
                      KanafSpacing.pageInset,
                      KanafSpacing.xxl,
                    ),
                    children: [
                      KanafStaggeredEntrance(
                        index: 0,
                        child: _buildOpportunitySummary(title, opportunity),
                      ),
                      const SizedBox(height: KanafSpacing.xxl),
                      KanafStaggeredEntrance(index: 1, child: _buildFields()),
                    ],
                  ),
                ),
              ),
              KanafActionBar(
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    _isSubmitting ? 'جاري الإرسال...' : 'إرسال الطلب',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpportunitySummary(
    String title,
    Map<String, dynamic> opportunity,
  ) {
    final scheme = context.colors;
    final location = opportunity['location']?.toString() ?? '';

    return KanafCard(
      color: scheme.primaryContainer,
      borderColor: scheme.primary.withOpacity(0.3),
      child: Row(
        children: [
          Icon(Icons.handshake_outlined, color: scheme.onPrimaryContainer),
          const SizedBox(width: KanafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: KanafSpacing.xxs),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer.withOpacity(0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KanafSectionHeader(
          title: 'طلبك',
          subtitle: 'يصل نصك إلى دار الرعاية كما كتبته',
        ),
        const SizedBox(height: KanafSpacing.md),
        TextFormField(
          controller: _reasonController,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: 'لماذا تريد التطوع في هذه الفرصة؟',
            prefixIcon: Icon(Icons.favorite_outline_rounded),
            alignLabelWithHint: true,
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return 'اكتب سبب رغبتك في التطوع';
            if (text.length < 10) return 'أضف تفاصيل أكثر';
            return null;
          },
        ),
        const SizedBox(height: KanafSpacing.md),
        TextFormField(
          controller: _skillsController,
          focusNode: _skillsFocus,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'مهاراتك وخبراتك (اختياري)',
            hintText: 'مثال: تدريس رياضيات، إسعافات أولية',
            prefixIcon: Icon(Icons.workspace_premium_outlined),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _isSubmitting) return;

    final opportunity = _opportunity;
    final raw = opportunity['id'];
    final opportunityId = raw is int ? raw : int.tryParse(raw?.toString() ?? '');

    if (opportunityId == null) {
      _showMessage('تعذر تحديد الفرصة. عد إلى القائمة وحاول مرة أخرى.');
      return;
    }

    // الخادم يقبل `message` فقط من العميل؛ ندمج الحقلين في نص واحد
    // بدل إرسال مفاتيح يتجاهلها السيريالايزر.
    final skills = _skillsController.text.trim();
    final message = StringBuffer(_reasonController.text.trim());
    if (skills.isNotEmpty) {
      message.write('\n\nالمهارات: $skills');
    }

    setState(() => _isSubmitting = true);
    final provider = AppProviderScope.of(context);
    final submitted = await provider.applyToVolunteerOpportunity(
      opportunityId,
      {'message': message.toString()},
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // ننتظر النتيجة الفعلية لا `errorMessage` المتقادمة.
    if (!submitted) {
      _showMessage(provider.errorMessage ?? 'تعذر إرسال الطلب حالياً.');
      return;
    }

    await _showSuccessSheet();
  }

  Future<void> _showSuccessSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KanafSpacing.pageInset,
            0,
            KanafSpacing.pageInset,
            KanafSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: sheetContext.semantic.successContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 38,
                  color: sheetContext.semantic.success,
                ),
              ),
              const SizedBox(height: KanafSpacing.xl),
              Text(
                'تم إرسال طلبك',
                style: sheetContext.texts.titleLarge,
              ),
              const SizedBox(height: KanafSpacing.sm),
              Text(
                'ستراجعه دار الرعاية ويصلك إشعار بالنتيجة. '
                'يمكنك متابعة حالته من «جدولي».',
                textAlign: TextAlign.center,
                style: sheetContext.texts.bodyMedium?.copyWith(
                  color: sheetContext.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: KanafSpacing.xxl),
              FilledButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    KanafRoutes.mySchedule,
                    (route) => route.settings.name == KanafRoutes.volunteerHome,
                  );
                },
                child: const Text('عرض جدولي'),
              ),
              const SizedBox(height: KanafSpacing.sm),
              TextButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).pop();
                },
                child: const Text('العودة للفرص'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
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
