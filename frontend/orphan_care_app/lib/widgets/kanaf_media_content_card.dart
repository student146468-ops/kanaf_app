import 'package:flutter/material.dart';

import '../l10n/kanaf_localizations.dart';
import '../models/need_model.dart';
import '../models/volunteer_opportunity_model.dart';
import '../services/api_config.dart';
import '../theme/kanaf_tokens.dart';
import 'kanaf_states.dart';

class KanafMediaContentCard extends StatelessWidget {
  const KanafMediaContentCard({
    super.key,
    required this.title,
    required this.icon,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    this.imageUrl,
    this.subtitle,
    this.location,
    this.description,
    this.status,
    this.isUrgent = false,
    this.progress,
    this.progressLabel,
    this.percentLabel,
    this.onTap,
    this.onPrimaryAction,
    this.secondaryActionIcon,
    this.secondaryActionTooltip,
    this.onSecondaryAction,
    this.compact = false,
  });

  factory KanafMediaContentCard.need({
    Key? key,
    required BuildContext context,
    required NeedModel need,
    VoidCallback? onTap,
    VoidCallback? onDonate,
    VoidCallback? onInkindDonate,
    bool compact = false,
  }) {
    final progress = need.progress;
    final percentLabel = progress == null
        ? null
        : '${(progress.clamp(0.0, 1.0) * 100).round()}%';
    return KanafMediaContentCard(
      key: key,
      title: need.title,
      icon: need.icon,
      imageUrl: need.imageUrl,
      subtitle: need.careHomeName ?? need.categoryLabelFor(context),
      location: need.careHomeLocation,
      description: need.description,
      status: need.priority == 'urgent' ? 'urgent' : need.status,
      isUrgent: need.priority == 'urgent',
      progress: progress,
      progressLabel: context.tr(
        'home.collectedOf',
        args: {
          'collected': _formatNumber(need.fulfilledQuantity),
          'target': need.requiredQuantity.isEmpty
              ? context.tr('need.unspecified')
              : need.requiredQuantity,
        },
      ),
      percentLabel: percentLabel,
      primaryActionLabel: context.tr('home.donateNow'),
      primaryActionIcon: Icons.volunteer_activism_rounded,
      onTap: onTap,
      onPrimaryAction: need.status == 'open' ? onDonate : null,
      secondaryActionIcon: Icons.inventory_2_outlined,
      secondaryActionTooltip: context.tr('need.inkindDonate'),
      onSecondaryAction: need.status == 'open' ? onInkindDonate : null,
      compact: compact,
    );
  }

  factory KanafMediaContentCard.opportunity({
    Key? key,
    required BuildContext context,
    required VolunteerOpportunityModel opportunity,
    VoidCallback? onTap,
    VoidCallback? onApply,
    bool compact = false,
  }) {
    final title = opportunity.title.isEmpty
        ? context.tr('volunteer.defaultOpportunity')
        : opportunity.title;
    final progress =
        opportunity.requiredVolunteers > 0 ? opportunity.capacityRatio : null;
    final percentLabel = progress == null
        ? null
        : '${(progress.clamp(0.0, 1.0) * 100).round()}%';
    return KanafMediaContentCard(
      key: key,
      title: title,
      icon: opportunity.icon,
      imageUrl: opportunity.imageUrl,
      subtitle:
          opportunity.careHomeName ?? opportunity.categoryLabelFor(context),
      location: opportunity.location.isNotEmpty
          ? opportunity.location
          : opportunity.careHomeLocation,
      description: opportunity.description,
      status: opportunity.myApplicationStatus ?? opportunity.status,
      progress: progress,
      progressLabel: opportunity.requiredVolunteers > 0
          ? context.tr(
              'volunteer.capacityCount',
              args: {
                'current': opportunity.currentVolunteers,
                'required': opportunity.requiredVolunteers,
              },
            )
          : null,
      percentLabel: percentLabel,
      primaryActionLabel: switch ((
        opportunity.myApplicationStatus,
        opportunity.isOpen,
        opportunity.isFull
      )) {
        (final applicationStatus?, _, _) =>
          _applicationStatusLabel(context, applicationStatus),
        (_, false, _) => context.tr('volunteer.filterClosed'),
        (_, true, true) => context.tr('volunteer.capacityFull'),
        _ => context.tr('volunteer.applyButton'),
      },
      primaryActionIcon: Icons.volunteer_activism_outlined,
      onTap: onTap,
      onPrimaryAction: opportunity.canApply ? onApply : null,
      compact: compact,
    );
  }

  final String title;
  final IconData icon;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final String? imageUrl;
  final String? subtitle;
  final String? location;
  final String? description;
  final String? status;
  final bool isUrgent;
  final double? progress;
  final String? progressLabel;
  final String? percentLabel;
  final VoidCallback? onTap;
  final VoidCallback? onPrimaryAction;
  final IconData? secondaryActionIcon;
  final String? secondaryActionTooltip;
  final VoidCallback? onSecondaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? KanafPalette.ember.withValues(alpha: 0.24)
        : KanafPalette.brandInk.withValues(alpha: 0.14);
    final background = isDark
        ? const Color(0xFF100B08)
        : scheme.surfaceContainerLow.withValues(alpha: 0.96);

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: KanafRadii.xl,
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: KanafPalette.seed.withValues(alpha: 0.08),
        highlightColor: KanafPalette.seed.withValues(alpha: 0.04),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: KanafRadii.xl,
            boxShadow: [
              BoxShadow(
                color: KanafPalette.seed.withValues(alpha: isDark ? 0.16 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding:
                EdgeInsets.all(compact ? KanafSpacing.sm : KanafSpacing.md),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useHorizontal = !compact && constraints.maxWidth >= 330;
                if (!useHorizontal) {
                  return _VerticalLayout(card: this);
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 184),
                  child: Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      Expanded(
                        flex: 9,
                        child: _CardDetails(card: this),
                      ),
                      const SizedBox(width: KanafSpacing.md),
                      Expanded(
                        flex: 8,
                        child: _CardImage(
                          imageUrl: imageUrl,
                          icon: icon,
                          aspectRatio: 0.92,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalLayout extends StatelessWidget {
  const _VerticalLayout({required this.card});

  final KanafMediaContentCard card;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardImage(
          imageUrl: card.imageUrl,
          icon: card.icon,
          aspectRatio: 4 / 3,
        ),
        const SizedBox(height: KanafSpacing.md),
        _CardDetails(card: card),
      ],
    );
  }
}

class _CardDetails extends StatelessWidget {
  const _CardDetails({required this.card});

  final KanafMediaContentCard card;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = scheme.onSurfaceVariant;
    final compact = card.compact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconTile(icon: card.icon, compact: compact),
            const SizedBox(width: KanafSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    card.title,
                    maxLines: compact ? 2 : 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: (compact
                            ? context.texts.titleSmall
                            : context.texts.headlineSmall)
                        ?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: KanafSpacing.xs),
                  _MetaLine(
                    icon: Icons.location_on_rounded,
                    text: _joinMeta(card.subtitle, card.location),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (card.status != null || card.isUrgent) ...[
          const SizedBox(height: KanafSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: KanafStatusChip(
              status: card.isUrgent ? 'urgent' : card.status!,
              compact: true,
            ),
          ),
        ],
        if ((card.description ?? '').trim().isNotEmpty) ...[
          SizedBox(height: compact ? KanafSpacing.sm : KanafSpacing.lg),
          Text(
            card.description!.trim(),
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: (compact ? context.texts.bodySmall : context.texts.bodyLarge)
                ?.copyWith(
              color: muted,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (card.progress != null || card.progressLabel != null) ...[
          SizedBox(height: compact ? KanafSpacing.sm : KanafSpacing.lg),
          _ProgressBlock(
            value: card.progress,
            label: card.progressLabel,
            percentLabel: card.percentLabel,
            compact: compact,
          ),
        ],
        SizedBox(height: compact ? KanafSpacing.md : KanafSpacing.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: KanafPalette.ember,
                  foregroundColor: const Color(0xFF241006),
                  minimumSize: Size.fromHeight(compact ? 40 : 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KanafSpacing.md,
                  ),
                  textStyle: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 13 : 16,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: KanafRadii.pill,
                  ),
                ),
                onPressed: card.onPrimaryAction,
                icon: Icon(card.primaryActionIcon, size: compact ? 17 : 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(card.primaryActionLabel),
                ),
              ),
            ),
            if (card.secondaryActionIcon != null &&
                card.onSecondaryAction != null) ...[
              const SizedBox(width: KanafSpacing.sm),
              IconButton.filledTonal(
                tooltip: card.secondaryActionTooltip,
                onPressed: card.onSecondaryAction,
                icon: Icon(card.secondaryActionIcon),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String? _joinMeta(String? first, String? second) {
    final values = [
      first?.trim(),
      second?.trim(),
    ].where((value) => value != null && value.isNotEmpty).cast<String>();
    if (values.isEmpty) return null;
    return values.join(' - ');
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.compact});

  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 42 : 54,
      height: compact ? 42 : 54,
      decoration: BoxDecoration(
        color: KanafPalette.seed.withValues(alpha: 0.12),
        borderRadius: KanafRadii.md,
        border: Border.all(color: KanafPalette.ember.withValues(alpha: 0.32)),
      ),
      child: Icon(icon, color: KanafPalette.ember, size: compact ? 21 : 27),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final value = text?.trim();
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, size: 17, color: KanafPalette.seed),
        const SizedBox(width: KanafSpacing.xs),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({
    required this.value,
    required this.label,
    required this.percentLabel,
    required this.compact,
  });

  final double? value;
  final String? label;
  final String? percentLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = value?.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          textDirection: TextDirection.rtl,
          children: [
            if ((label ?? '').trim().isNotEmpty)
              Expanded(
                child: Text(
                  label!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: context.texts.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if ((percentLabel ?? '').trim().isNotEmpty) ...[
              const SizedBox(width: KanafSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KanafSpacing.md,
                  vertical: KanafSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: KanafPalette.seed.withValues(alpha: 0.10),
                  borderRadius: KanafRadii.pill,
                  border: Border.all(
                    color: KanafPalette.ember.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  percentLabel!,
                  style: context.texts.labelLarge?.copyWith(
                    color: KanafPalette.ember,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: KanafSpacing.sm),
          ClipRRect(
            borderRadius: KanafRadii.pill,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: compact ? 6 : 8,
              backgroundColor:
                  context.colors.surfaceContainerHighest.withValues(alpha: 0.64),
              color: KanafPalette.ember,
            ),
          ),
        ],
      ],
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({
    required this.imageUrl,
    required this.icon,
    required this.aspectRatio,
  });

  final String? imageUrl;
  final IconData icon;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final rawImageUrl = imageUrl?.trim();
    final resolvedUrl = ApiConfig.buildImageUrl(rawImageUrl);
    return ClipRRect(
      borderRadius: KanafRadii.xl,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: resolvedUrl == null
            ? _ImagePlaceholder(icon: icon)
            : Image.network(
                resolvedUrl,
                headers: ApiConfig.imageRequestHeaders,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _ImagePlaceholder(icon: icon);
                },
                errorBuilder: (context, error, stackTrace) {
                  ApiConfig.logImageLoadError(
                    source: rawImageUrl ?? '',
                    resolved: resolvedUrl,
                    error: error,
                  );
                  return _ImagePlaceholder(icon: icon);
                },
              ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : KanafPalette.seed.withValues(alpha: 0.08),
      ),
      child: Center(
        child: Icon(
          icon,
          color: KanafPalette.ember.withValues(alpha: isDark ? 0.90 : 0.82),
          size: 42,
        ),
      ),
    );
  }
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
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
