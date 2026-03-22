import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/crop_selection.dart';

class CropToolPanel extends StatelessWidget {
  final CropSelection currentCrop;
  final ValueChanged<CropSelection> onCropChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final bool isProcessing;

  const CropToolPanel({
    super.key,
    required this.currentCrop,
    required this.onCropChanged,
    required this.onApply,
    required this.onReset,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.crop_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                const Text(
                  'Crop',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (!currentCrop.isFull)
                  TextButton(
                    onPressed: onReset,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.error,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Reset Crop'),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _buildAspectRatios(),
            const SizedBox(height: AppTheme.spacingLg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isProcessing ? null : onApply,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Apply Crop'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.scaffoldDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAspectRatios() {
    final presets = [
      ('Free', null),
      ('1:1', 1.0),
      ('9:16', 9 / 16),
      ('16:9', 16 / 9),
      ('4:5', 4 / 5),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final (label, ratio) = presets[index];
          final isSelected = currentCrop.appliedAspectRatio == ratio;

          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                onCropChanged(currentCrop.withAspectRatio(ratio));
              }
            },
            backgroundColor: AppColors.cardDarkAlt,
            selectedColor: AppColors.accent,
            side: BorderSide(
              color: isSelected ? AppColors.accent : Colors.transparent,
              width: 1,
            ),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.scaffoldDark : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}
