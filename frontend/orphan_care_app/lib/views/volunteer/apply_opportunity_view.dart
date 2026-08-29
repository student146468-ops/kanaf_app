import 'package:flutter/material.dart';

import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../l10n/kanaf_localizations.dart';

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
    final title = opportunity['title']?.toString() ??
        context.tr('volunteer.defaultOpportunity');
    final applicationStatus =
        opportunity['my_application_status']?.toString().trim();
    final hasApplication =
        applicationStatus != null && applicationStatus.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('volunteer.applyTitle')),
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
                  onPressed: _isSubmitting || hasApplication ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    hasApplication
                        ? _applicationStatusLabel(context, applicationStatus)
                        : _isSubmitting
                            ? context.tr('volunteer.submitting')
                            : context.tr('volunteer.submitRequest'),
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
        KanafSectionHeader(
          title: context.tr('volunteer.myRequest'),
          subtitle: context.tr('volunteer.myRequestSubtitle'),
        ),
        const SizedBox(height: KanafSpacing.md),
        TextFormField(
          controller: _reasonController,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: context.tr('volunteer.whyJoin'),
            prefixIcon: const Icon(Icons.favorite_outline_rounded),
            alignLabelWithHint: true,
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return context.tr('volunteer.reasonRequired');
            if (text.length < 10) return context.tr('volunteer.reasonTooShort');
            return null;
          },
        ),
        const SizedBox(height: KanafSpacing.md),
        TextFormField(
          controller: _skillsController,
          focusNode: _skillsFocus,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.tr('volunteer.skillsExperience'),
            hintText: context.tr('volunteer.skillsHint'),
            prefixIcon: const Icon(Icons.workspace_premium_outlined),
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
    final opportunityId =
        raw is int ? raw : int.tryParse(raw?.toString() ?? '');

    if (opportunityId == null) {
      _showMessage(context.tr('volunteer.missingOpportunity'));
      return;
    }

    // الخادم يقبل `message` فقط من العميل؛ ندمج الحقلين في نص واحد
    // بدل إرسال مفاتيح يتجاهلها السيريالايزر.
    final skills = _skillsController.text.trim();
    final message = StringBuffer(_reasonController.text.trim());
    if (skills.isNotEmpty) {
      message.write('\n\n${context.tr('volunteer.skillsPrefix')}: $skills');
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
      _showMessage(
          provider.errorMessage ?? context.tr('volunteer.applyFailed'));
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
                sheetContext.tr('volunteer.applySuccessTitle'),
                style: sheetContext.texts.titleLarge,
              ),
              const SizedBox(height: KanafSpacing.sm),
              Text(
                sheetContext.tr('volunteer.applySuccessMessage'),
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
                child: Text(context.tr('volunteer.viewSchedule')),
              ),
              const SizedBox(height: KanafSpacing.sm),
              TextButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).pop();
                },
                child: Text(context.tr('volunteer.backToOpportunities')),
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
          label: context.tr('common.ok'),
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }
}

String _applicationStatusLabel(BuildContext context, String status) {
  return switch (status.trim().toLowerCase()) {
    'accepted' || 'approved' => context.tr('status.accepted'),
    'completed' => context.tr('status.completed'),
    'rejected' => context.tr('status.rejected'),
    'pending' => context.tr('status.pending'),
    _ => status,
  };
}
