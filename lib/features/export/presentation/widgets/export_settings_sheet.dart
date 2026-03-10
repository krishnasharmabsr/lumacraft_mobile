import 'package:flutter/material.dart';
import '../../../../core/models/export_settings.dart';
import '../../../../core/services/pro_gate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Bottom sheet for configuring export settings before saving.
class ExportSettingsSheet extends StatefulWidget {
  final void Function(ExportSettings settings) onExport;

  const ExportSettingsSheet({super.key, required this.onExport});

  @override
  State<ExportSettingsSheet> createState() => _ExportSettingsSheetState();
}

class _ExportSettingsSheetState extends State<ExportSettingsSheet> {
  ExportResolution _resolution = ExportResolution.p720;
  int? _fps; // null = Source
  double _quality = 65;
  ExportFormat _format = ExportFormat.mp4;

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
            'Export Studio',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXl),

          // Resolution
          _buildOptionRow(label: 'RESOLUTION', child: _buildResolutionPicker()),
          const SizedBox(height: AppTheme.spacingLg),

          // Format
          _buildOptionRow(
            label: 'FORMAT',
            child: _buildSegmentedControl<ExportFormat>(
              values: ExportFormat.values,
              selected: _format,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _format = v),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // FPS
          _buildOptionRow(label: 'FPS', child: _buildFpsPicker()),
          const SizedBox(height: AppTheme.spacingLg),

          // Quality slider
          _buildOptionRow(label: 'QUALITY', child: _buildQualitySlider()),
          const SizedBox(height: AppTheme.spacingXl),

          // Single Export button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onExport(_buildSettings());
              },
              icon: const Icon(Icons.save_alt_rounded, size: 18),
              label: const Text('Export'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
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
      quality: _quality.round(),
      format: _format,
    );
  }

  // --- Resolution picker with Pro badges ---
  Widget _buildResolutionPicker() {
    return Row(
      children: ExportResolution.values.map((res) {
        final isSelected = res == _resolution;
        final isLocked = res.requiresPro && !ProGate.isPro;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (isLocked) {
                _showProDialog();
              } else {
                setState(() => _resolution = res);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isLocked
                    ? AppColors.cardDarkAlt.withValues(alpha: 0.5)
                    : isSelected
                    ? AppColors.accent
                    : AppColors.cardDarkAlt,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: isLocked
                      ? AppColors.divider.withValues(alpha: 0.5)
                      : isSelected
                      ? AppColors.accent
                      : AppColors.divider,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    res.label,
                    style: TextStyle(
                      color: isLocked
                          ? AppColors.textMuted
                          : isSelected
                          ? AppColors.scaffoldDark
                          : AppColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  if (isLocked) ...[
                    const SizedBox(width: 3),
                    const Icon(Icons.lock, size: 10, color: AppColors.warning),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- FPS picker with Pro badge for 60fps ---
  Widget _buildFpsPicker() {
    final fpsOptions = [null, 24, 30, 60];
    return Row(
      children: fpsOptions.map((fps) {
        final isSelected = fps == _fps;
        final isLocked = fps == 60 && !ProGate.isPro;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (isLocked) {
                _showProDialog();
              } else {
                setState(() => _fps = fps);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isLocked
                    ? AppColors.cardDarkAlt.withValues(alpha: 0.5)
                    : isSelected
                    ? AppColors.accent
                    : AppColors.cardDarkAlt,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: isLocked
                      ? AppColors.divider.withValues(alpha: 0.5)
                      : isSelected
                      ? AppColors.accent
                      : AppColors.divider,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fps == null ? 'Source' : '$fps',
                    style: TextStyle(
                      color: isLocked
                          ? AppColors.textMuted
                          : isSelected
                          ? AppColors.scaffoldDark
                          : AppColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  if (isLocked) ...[
                    const SizedBox(width: 3),
                    const Icon(Icons.lock, size: 10, color: AppColors.warning),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- Quality slider ---
  Widget _buildQualitySlider() {
    final label = _quality >= 75
        ? 'High'
        : _quality >= 40
        ? 'Standard'
        : 'Low';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_quality.round()}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        Slider(
          value: _quality,
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: (v) => setState(() => _quality = v),
        ),
      ],
    );
  }

  void _showProDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Pro feature — billing coming in an upcoming task.',
        ),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
      ),
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
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
