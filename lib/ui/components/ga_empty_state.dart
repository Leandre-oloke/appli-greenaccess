import 'package:flutter/material.dart';

import '../tokens/ga_spacing.dart';
import 'ga_lottie.dart';

/// État vide unifié : illustration + titre Sora + message + action.
/// Remplace `_EmptyHistory`, `_EmptyBadges`, `_EmptyContrats`… (8 doublons).
class GaEmptyState extends StatelessWidget {
  const GaEmptyState({
    super.key,
    required this.title,
    this.message,
    this.lottieAsset,
    this.icon = Icons.inbox_rounded,
    this.action,
    this.compact = false,
  });

  final String title;
  final String? message;
  final String? lottieAsset;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final art = lottieAsset != null
        ? GaLottie(lottieAsset!, size: compact ? 96 : 150, fallbackIcon: icon)
        : Container(
            height: compact ? 72 : 104,
            width: compact ? 72 : 104,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: compact ? 34 : 48, color: theme.colorScheme.primary),
          );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            art,
            const SizedBox(height: GaSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: compact
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.headlineSmall,
            ),
            if (message != null) ...[
              const SizedBox(height: GaSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: GaSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
