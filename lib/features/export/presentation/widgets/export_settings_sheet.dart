import 'package:flutter/material.dart';
import '../../../../core/models/export_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Bottom sheet for configuring export settings before saving.
class ExportSettingsSheet extends StatefulWidget {
  final bool hasEdits;
  final void Function(ExportSettings settings, bool saveCopy) onExport;

  const ExportSettingsSheet({
    super.key,
    required this.hasEdits,
    required this.onExport,
  });

  @override
  State<ExportSettingsSheet> createState() => _ExportSettingsSheetState();
}

class _ExportSettingsSheetState extends State<ExportSettingsSheet> {
  ExportResolution _resolution = ExportResolution.p720;
  int _fps = 30;
  ExportQuality _quality = ExportQuality.medium;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg,
        AppTheme.spacingSm,
        AppTheme.spacingLg,
        AppTheme.spacingXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppTheme.spacingLg),
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Text(
            'Export Settings',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXl),

          // Resolution
          _buildOptionRow(
            label: 'Resolution',
            child: _buildSegmentedControl<ExportResolution>(
              values: ExportResolution.values,
              selected: _resolution,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _resolution = v),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // FPS
          _buildOptionRow(
            label: 'FPS',
            child: _buildSegmentedControl<int>(
              values: const [24, 30],
              selected: _fps,
              labelOf: (v) => '$v',
              onChanged: (v) => setState(() => _fps = v),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Quality
          _buildOptionRow(
            label: 'Quality',
            child: _buildSegmentedControl<ExportQuality>(
              values: ExportQuality.values,
              selected: _quality,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _quality = v),
            ),
          ),
          const SizedBox(height: AppTheme.spacingXl),

          // Export buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onExport(_buildSettings(), true);
                  },
                  icon: const Icon(Icons.file_copy_outlined, size: 18),
                  label: const Text('Save Copy'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.hasEdits
                      ? () {
                          Navigator.pop(context);
                          widget.onExport(_buildSettings(), false);
                        }
                      : null,
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: const Text('Export'),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  ExportSettings _buildSettings() {
    return ExportSettings(
      resolution: _resolution,
      fps: _fps,
      quality: _quality,
      format: 'mp4',
    );
  }

  Widget _buildOptionRow({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        child,
      ],
    );
  }

  Widget _buildSegmentedControl<T>({
    required List<T> values,
    required T selected,
    required String Function(T) labelOf,
    required void Function(T) onChanged,
  }) {
    return Row(
      children: values.map((v) {
        final isSelected = v == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(v),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : AppColors.cardDarkAlt,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.divider,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                labelOf(v),
                style: TextStyle(
                  color: isSelected
                      ? AppColors.scaffoldDark
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
