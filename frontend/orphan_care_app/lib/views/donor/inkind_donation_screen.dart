import 'package:flutter/material.dart';

import '../../models/donation_request.dart';
import '../../providers/app_provider_scope.dart';
import '../../router/kanaf_router.dart';
import '../../theme/kanaf_motion.dart';
import '../../theme/kanaf_tokens.dart';
import '../../widgets/kanaf_layout.dart';
import '../../l10n/kanaf_localizations.dart';

/// شاشة التبرع العيني.
///
/// أُعيد بناؤها على Material 3. الفرق الوظيفي المهم: اختيار النوع صار
/// شبكة بطاقات قابلة للنقر بمساحة لمس مريحة (≥ 48dp)، والنموذج يمرر
/// الحقول إلى الخادم فعلياً بعد أن كانت تُجمع وتُهمل.
class InkindDonationScreen extends StatefulWidget {
  const InkindDonationScreen({super.key});

  @override
  State<InkindDonationScreen> createState() => _InkindDonationScreenState();
}

class _InkindDonationScreenState extends State<InkindDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = '';
  bool _isProcessing = false;

  static const List<_DonationCategory> _categories = [
    _DonationCategory(
      id: 'food',
      titleKey: 'inkind.food',
      descriptionKey: 'inkind.foodDescription',
      icon: Icons.restaurant_outlined,
    ),
    _DonationCategory(
      id: 'clothes',
      titleKey: 'inkind.clothing',
      descriptionKey: 'inkind.clothingDescription',
      icon: Icons.checkroom_outlined,
    ),
    _DonationCategory(
      id: 'school',
      titleKey: 'inkind.education',
      descriptionKey: 'inkind.educationDescription',
      icon: Icons.school_outlined,
    ),
    _DonationCategory(
      id: 'health',
      titleKey: 'inkind.health',
      descriptionKey: 'inkind.healthDescription',
      icon: Icons.health_and_safety_outlined,
    ),
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('inkind.title')),
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
                        child: _buildCategorySection(),
                      ),
                      const SizedBox(height: KanafSpacing.xxl),
                      KanafStaggeredEntrance(
                        index: 1,
                        child: _buildDetailsSection(),
                      ),
                    ],
                  ),
                ),
              ),
              KanafActionBar(
                child: FilledButton.icon(
                  onPressed: _selectedType.isNotEmpty && !_isProcessing
                      ? _submitDonation
                      : null,
                  icon: _isProcessing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_isProcessing
                      ? context.tr('inkind.sending')
                      : context.tr('inkind.submit')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KanafSectionHeader(
          title: context.tr('inkind.typeTitle'),
          subtitle: context.tr('inkind.typeSubtitle'),
        ),
        const SizedBox(height: KanafSpacing.md),
        for (final category in _categories)
          Padding(
            padding: const EdgeInsets.only(bottom: KanafSpacing.sm),
            child: _CategoryTile(
              category: category,
              selected: _selectedType == category.id,
              onTap: () => setState(() => _selectedType = category.id),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KanafSectionHeader(title: context.tr('inkind.detailsTitle')),
        const SizedBox(height: KanafSpacing.md),
        TextFormField(
          controller: _quantityController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: context.tr('common.quantity'),
            hintText: context.tr('inkind.quantityHint'),
            prefixIcon: const Icon(Icons.numbers_rounded),
          ),
          validator: (value) =>
              _requireText(value, context.tr('inkind.quantityRequired')),
        ),
        const SizedBox(height: KanafSpacing.md),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: context.tr('common.description'),
            hintText: context.tr('inkind.descriptionHint'),
            prefixIcon: const Icon(Icons.description_outlined),
            alignLabelWithHint: true,
          ),
          validator: (value) =>
              _requireText(value, context.tr('inkind.descriptionRequired')),
        ),
        const SizedBox(height: KanafSpacing.md),
        TextFormField(
          controller: _contactController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: context.tr('inkind.contact'),
            hintText: context.tr('inkind.contactHint'),
            prefixIcon: const Icon(Icons.call_outlined),
          ),
          validator: (value) =>
              _requireText(value, context.tr('inkind.contactRequired')),
        ),
        const SizedBox(height: KanafSpacing.md),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: context.tr('common.notes'),
            hintText: context.tr('inkind.notesHint'),
            prefixIcon: const Icon(Icons.edit_note_outlined),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  static String? _requireText(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  Future<void> _submitDonation() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final category = _categories.firstWhere((c) => c.id == _selectedType);
    final quantity = _quantityController.text.trim();

    final request = DonationRequest.inKind(
      itemType: context.tr(category.titleKey),
      quantity: quantity,
      description: _descriptionController.text.trim(),
      contact: _contactController.text.trim(),
      notes: _notesController.text.trim(),
    );
    final validationError = request.validationError();
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    setState(() => _isProcessing = true);
    final provider = AppProviderScope.of(context);
    final created = await provider.submitDonation(request);
    if (!mounted) return;
    setState(() => _isProcessing = false);

    // `created == null` تعني أن الخادم لم يؤكد الحفظ — لا شاشة نجاح إطلاقاً.
    if (created == null) {
      Navigator.pushNamed(
        context,
        KanafRoutes.donationSuccess,
        arguments: {
          'type': context.tr('inkind.title'),
          'status': 'failed',
          'summary': '${context.tr(category.titleKey)} — $quantity',
          'error': provider.errorMessage ?? context.tr('inkind.saveFailed'),
          'retryRoute': KanafRoutes.inkindDonation,
        },
      );
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      KanafRoutes.donationSuccess,
      arguments: {
        'type': context.tr('inkind.title'),
        // الرقم المرجعي هو المعرّف الحقيقي في قاعدة البيانات.
        'reference': 'KNF-${created.id}',
        'status': created.status,
        'date': DateTime.now().toIso8601String(),
        'summary': '${context.tr(category.titleKey)} — $quantity',
      },
    );
  }

  void _showError(String message) {
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

class _DonationCategory {
  const _DonationCategory({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
  });

  final String id;
  final String titleKey;
  final String descriptionKey;
  final IconData icon;
}

/// بطاقة فئة قابلة للاختيار.
///
/// الحالة النشطة تُعلَن بثلاث إشارات مجتمعة: حدّ بلون الهوية، خلفية
/// حاوية، وأيقونة تحقّق. الاعتماد على اللون وحده يفشل مع عمى الألوان.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _DonationCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return AnimatedContainer(
      duration: KanafDuration.quick,
      curve: KanafCurves.standard,
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: KanafRadii.lg,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KanafSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary.withOpacity(0.16)
                      : scheme.surfaceContainerHighest,
                  borderRadius: KanafRadii.sm,
                ),
                child: Icon(
                  category.icon,
                  size: 24,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: KanafSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(category.titleKey),
                      style: context.texts.titleSmall?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: KanafSpacing.xxs),
                    Text(
                      context.tr(category.descriptionKey),
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KanafSpacing.sm),
              AnimatedScale(
                duration: KanafDuration.quick,
                scale: selected ? 1 : 0.7,
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? scheme.primary : scheme.outline,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
