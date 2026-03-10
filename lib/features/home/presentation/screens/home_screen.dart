import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/io/media_io_service.dart';
import '../../../preview/presentation/screens/editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MediaIoService _ioService = MediaIoService();
  bool _isLoading = false;

  Future<void> _importVideo() async {
    setState(() => _isLoading = true);

    try {
      final String? pickedPath = await _ioService.pickVideoFromGallery();

      if (pickedPath != null && mounted) {
        final localPath = await _ioService.copyToLocalWorkingDir(pickedPath);

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditorScreen(videoPath: localPath),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXl,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo area — canonical brand mark
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/branding/logo_mark_master_1024.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.accentGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.movie_edit,
                            color: AppColors.scaffoldDark,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXl),

                  // Title
                  const Text(
                    'LumaCraft',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  const Text(
                    'Video Studio',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXxl * 2),

                  // Import card
                  Card(
                    child: InkWell(
                      onTap: _isLoading ? null : _importVideo,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingXl,
                          vertical: AppTheme.spacingXl,
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  SizedBox(width: AppTheme.spacingMd),
                                  Text(
                                    'Importing...',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.video_library_rounded,
                                    color: AppColors.accent,
                                    size: 28,
                                  ),
                                  SizedBox(width: AppTheme.spacingMd),
                                  Text(
                                    'Import Video',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: AppColors.textMuted,
                                    size: 16,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingLg),

                  // Version badge
                  Text(
                    'v2.0 • Video Studio',
                    style: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
