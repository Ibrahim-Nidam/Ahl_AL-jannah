import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ahl_jannah/core/theme/app_colors.dart';
import 'package:ahl_jannah/core/theme/app_text_styles.dart';
import 'package:ahl_jannah/l10n/generated/app_localizations.dart';

/// Large tap-target counter for the one-dhikr reader.
///
/// Temporary only — parent owns reset-on-exit behavior.
class AdhkarRepetitionCounter extends StatelessWidget {
  final int current;
  final int target;
  final VoidCallback onIncrement;
  final VoidCallback onReset;

  const AdhkarRepetitionCounter({
    super.key,
    required this.current,
    required this.target,
    required this.onIncrement,
    required this.onReset,
  });

  bool get _completed => current >= target && target > 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Text(
          '$current / $target',
          style: AppTextStyles.numberDisplay.copyWith(
            fontSize: 36,
            color: _completed ? AppColors.success : scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 120,
          height: 120,
          child: Material(
            color: _completed
                ? AppColors.success.withValues(alpha: 0.15)
                : scheme.primary.withValues(alpha: 0.12),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _completed
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onIncrement();
                    },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      backgroundColor:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      color: _completed ? AppColors.success : scheme.primary,
                    ),
                  ),
                  Icon(
                    _completed
                        ? Icons.check_rounded
                        : Icons.touch_app_rounded,
                    size: 36,
                    color: _completed ? AppColors.success : scheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: current == 0 ? null : onReset,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(l10n.adhkarResetCounter),
        ),
      ],
    );
  }
}
