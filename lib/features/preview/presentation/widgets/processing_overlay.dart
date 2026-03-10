import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Full-screen processing overlay with determinate progress bar.
class ProcessingOverlay extends StatelessWidget {
  final String label;
  final double progress; // 0.0 to 1.0, or -1 for indeterminate

  const ProcessingOverlay({super.key, required this.label, this.progress = -1});

  @override
  Widget build(BuildContext context) {
    final isIndeterminate = progress < 0;
    final percent = isIndeterminate ? 0 : (progress * 100).clamp(0, 100);

    return Container(
      color: AppColors.scaffoldDark.withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.movie_creation_rounded,
                  color: AppColors.accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXl),

              // Label
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: SizedBox(
                  height: 6,
                  child: isIndeterminate
                      ? const LinearProgressIndicator(
                          color: AppColors.accent,
                          backgroundColor: AppColors.divider,
                        )
                      : LinearProgressIndicator(
                          value: progress,
                          color: AppColors.accent,
                          backgroundColor: AppColors.divider,
                        ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),

              // Percentage text
              if (!isIndeterminate)
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
