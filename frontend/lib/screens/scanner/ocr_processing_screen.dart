import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/scan_provider.dart';
import '../../widgets/custom_button.dart';
import '../contacts/extracted_details_screen.dart';

class OcrProcessingScreen extends StatefulWidget {
  final File cardImageFile;
  final File? backImageFile;

  const OcrProcessingScreen({
    super.key,
    required this.cardImageFile,
    this.backImageFile,
  });

  @override
  State<OcrProcessingScreen> createState() => _OcrProcessingScreenState();
}

class _OcrProcessingScreenState extends State<OcrProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startOcrProcess();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startOcrProcess() async {
    final scanProvider = Provider.of<ScanProvider>(context, listen: false);
    final success = await scanProvider.processBusinessCardImage(
      widget.cardImageFile,
      backImageFile: widget.backImageFile,
    );

    if (!mounted) return;

    if (success && scanProvider.extractedContact != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ExtractedDetailsScreen(
            cardImageFile: widget.cardImageFile,
            backImageFile: widget.backImageFile,
            initialContact: scanProvider.extractedContact!,
            missingFields: scanProvider.missingFields,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanProvider = Provider.of<ScanProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('OCR Card Scanning'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Card Scanning Preview
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Card Image
                      Image.file(
                        widget.cardImageFile,
                        fit: BoxFit.cover,
                      ),

                      // Dark tint overlay
                      Container(
                        color: Colors.black.withValues(alpha: 0.25),
                      ),

                      // Scanning Beam Line (animated up and down)
                      if (scanProvider.isProcessing)
                        AnimatedBuilder(
                          animation: _scanLineAnimation,
                          builder: (context, child) {
                            return Align(
                              alignment: Alignment(0, (_scanLineAnimation.value * 2) - 1),
                              child: Container(
                                height: 3,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.scannerGuide,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.scannerGuide.withValues(alpha: 0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),

              if (scanProvider.isProcessing) ...[
                // Loading Spinner
                const SpinKitFadingCircle(
                  color: AppColors.primary,
                  size: 38,
                ),
                const SizedBox(height: 20),

                // Processing status
                Text(
                  scanProvider.processingStatusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Powered by Google ML Kit & Intelligent Contact Parsing',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (scanProvider.errorMessage != null) ...[
                // Error State
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          scanProvider.errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Retry Button
                CustomButton(
                  text: 'Retry Scanning',
                  icon: Icons.refresh,
                  onPressed: _startOcrProcess,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Retake Photo',
                  isOutlined: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
