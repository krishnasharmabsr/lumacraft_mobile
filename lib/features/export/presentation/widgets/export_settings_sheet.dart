import 'package:flutter/material.dart';
import '../../../../core/models/export_settings.dart';
import '../../../../core/services/pro_gate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Bottom sheet for configuring export settings before saving.
class ExportSettingsSheet extends StatefulWidget {
  final ExportSettings initialSettings;
  final void Function(ExportSettings settings) onSettingsChanged;
  final void Function(ExportSettings settings) onExport;
  final VoidCallback onOrientationChangeRequested;

  const ExportSettingsSheet({
    super.key,
    required this.initialSettings,
    required this.onSettingsChanged,
    required this.onExport,
    required this.onOrientationChangeRequested,
  });

  @override
  State<ExportSettingsSheet> createState() => _ExportSettingsSheetState();
}

class _ExportSettingsSheetState extends State<ExportSettingsSheet> {
  late ExportResolution _resolution;
  int? _fps;
  late ExportQualityPreset _qualityPreset;
  late ExportFormat _format;
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    _resolution = widget.initialSettings.resolution;
    _fps = widget.initialSettings.fps;
    _qualityPreset = widget.initialSettings.qualityPreset;
    _format = widget.initialSettings.format;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newOrientation = MediaQuery.of(context).orientation;
    if (_lastOrientation != null && _lastOrientation != newOrientation) {
      // Small delay to let the orientation change settle before triggering re-open
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onOrientationChangeRequested();
      });
    }
    _lastOrientation = newOrientation;
  }

  void _notifyChange() {
    widget.onSettingsChanged(_buildSettings());
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      return _buildLandscapeLayout();
    }
    return _buildPortraitLayout();
  }

  Widget _buildPortraitLayout() {
    return Material(
      color: Colors.transparent,
      child: Container(
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
            _buildHeader(),
            const SizedBox(height: AppTheme.spacingXl),
            Flexible(child: _buildSettingsList()),
            const SizedBox(height: AppTheme.spacingXl),
            _buildExportButton(),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    // Landscape uses a centered constrained panel/dialog style
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        margin: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: AppTheme.spacingLg),
                Flexible(
                  child: SingleChildScrollView(
                    child: _buildSettingsList(),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                _buildExportButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Text(
      'Export Studio',
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildSettingsList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        _buildOptionRow(
          label: 'QUALITY',
          child: _buildSegmentedControl<ExportQualityPreset>(
            values: ExportQualityPreset.values,
            selected: _qualityPreset,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _qualityPreset = v),
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
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
    );
  }

  ExportSettings _buildSettings() {
    return ExportSettings(
      resolution: _resolution,
      fps: _fps,
      qualityPreset: _qualityPreset,
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
                _notifyChange();

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
                _notifyChange();

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
