import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/card_crop_helper.dart';
import '../../core/utils/document_scanner_helper.dart';
import 'crop_screen.dart';
import 'ocr_processing_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  int _selectedCameraIndex = 0;
  bool _isTwoSidedMode = false;
  int _scanStep = 1; // 1 = Front side, 2 = Back side
  File? _capturedFrontFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Camera permission is required to scan business cards.',
          isError: true,
        );
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          Helpers.showSnackBar(context, 'No available cameras found on device.', isError: true);
        }
        return;
      }

      // Automatically select the primary rear/back camera
      final backIdx = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (backIdx != -1) {
        _selectedCameraIndex = backIdx;
      }

      final controller = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('[Camera Init Error]: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        setState(() {
          _isFlashOn = false;
        });
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        setState(() {
          _isFlashOn = true;
        });
      }
    } catch (e) {
      debugPrint('[Flash Toggle Error]: $e');
      try {
        await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.off : FlashMode.always);
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
      } catch (_) {
        setState(() {
          _isFlashOn = false;
        });
        if (mounted) {
          Helpers.showSnackBar(context, 'Flashlight not supported on this camera lens', isError: true);
        }
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length <= 1) return;

    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });

    await _cameraController?.dispose();

    final controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller.initialize();
    if (mounted) {
      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
      });
    }
  }

  Future<void> _captureCard() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile photo = await _cameraController!.takePicture();
      final File rawImageFile = File(photo.path);

      // Automatically crop card removing background desk/table
      final File imageFile = await CardCropHelper.autoCropToCard(rawImageFile);

      if (!mounted) return;

      if (_isTwoSidedMode) {
        if (_scanStep == 1) {
          setState(() {
            _capturedFrontFile = imageFile;
            _scanStep = 2;
            _isCapturing = false;
          });
          Helpers.showSnackBar(
            context,
            'Front side captured! Now align and capture the Back Side.',
            isSuccess: true,
          );
        } else {
          final front = _capturedFrontFile!;
          setState(() {
            _scanStep = 1;
            _capturedFrontFile = null;
            _isCapturing = false;
          });
          _proceedToOcr(front, backImageFile: imageFile);
        }
      } else {
        setState(() {
          _isCapturing = false;
        });
        _proceedToOcr(imageFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
        Helpers.showSnackBar(context, 'Failed to capture card: $e', isError: true);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null && mounted) {
        final rawFile = File(image.path);
        final file = await CardCropHelper.autoCropToCard(rawFile);
        if (_isTwoSidedMode) {
          if (_scanStep == 1) {
            setState(() {
              _capturedFrontFile = file;
              _scanStep = 2;
            });
            Helpers.showSnackBar(
              context,
              'Front side selected! Now select the Back Side from gallery.',
              isSuccess: true,
            );
          } else {
            final front = _capturedFrontFile!;
            setState(() {
              _scanStep = 1;
              _capturedFrontFile = null;
            });
            _proceedToOcr(front, backImageFile: file);
          }
        } else {
          _proceedToOcr(file);
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to pick image from gallery: $e', isError: true);
      }
    }
  }

  void _proceedToOcr(File imageFile, {File? backImageFile}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CropScreen(
          imageFile: imageFile,
          backImageFile: backImageFile,
        ),
      ),
    );
  }

  Future<void> _launchNativeDocumentScanner() async {
    try {
      final images = await DocumentScannerHelper.scanCards(isBatch: false, pageLimit: 1);
      if (images.isNotEmpty && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OcrProcessingScreen(cardImageFile: images.first),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Native Scanner from Single Error]: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-screen natural camera preview (no split screen, no letterboxing)
          _buildCameraPreview(context),

          // 2. Clean scanner interface overlay
          SafeArea(
            child: Column(
              children: [
                // Top Action Bar
                _buildTopBar(),

                const SizedBox(height: 8),

                // 1-Sided vs 2-Sided Mode Selector Toggle
                _buildModeSelector(),

                if (_isTwoSidedMode && _scanStep == 2 && _capturedFrontFile != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade900.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.greenAccent),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Front captured! Now align & capture the Back Side.',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // Center Rectangular Business Card Guide Frame (No dark inside overlay)
                _buildCardGuideFrame(context),

                const SizedBox(height: 14),

                // Helper positioning tip badge
                _buildGuideTip(),

                const Spacer(),

                // Bottom Controls Bar (Gallery, Shutter Button, Skip)
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white70),
              const SizedBox(height: 16),
              const Text(
                'Starting camera...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Pick from Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Seamless full-screen camera preview scaling without distortion or letterboxing
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final camera = _cameraController!.value;

        // Camera aspect ratio is width / height in landscape; inverted in portrait
        double scale = size.aspectRatio * camera.aspectRatio;
        if (scale < 1) scale = 1 / scale;

        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(_cameraController!),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          Text(
            _isTwoSidedMode
                ? (_scanStep == 1 ? 'Scan Front Side' : 'Scan Back Side')
                : 'Scan Business Card',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(color: Colors.black54, blurRadius: 4),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Google Document Scanner (Edge Snapping)',
                onPressed: _launchNativeDocumentScanner,
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.document_scanner, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _toggleFlash,
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: _isFlashOn ? Colors.amber : Colors.white,
                    size: 20,
                  ),
                ),
                tooltip: 'Flash',
              ),
              if (_cameras.length > 1) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _switchCamera,
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 20),
                  ),
                  tooltip: 'Switch Camera',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isTwoSidedMode = false;
                _scanStep = 1;
                _capturedFrontFile = null;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: !_isTwoSidedMode ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '1-Sided Scan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _isTwoSidedMode = true;
                _scanStep = 1;
                _capturedFrontFile = null;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _isTwoSidedMode ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '2-Sided (Front + Back)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGuideFrame(BuildContext context) {
    // Clean, modern rectangular card frame without dark overlay or tint
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AspectRatio(
        aspectRatio: 1.58, // Standard business card ratio (3.5" x 2.2")
        child: Stack(
          children: [
            // Clean subtle white border outline
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),

            // Prominent 4-corner alignment brackets
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white, width: 3.5),
                    left: BorderSide(color: Colors.white, width: 3.5),
                  ),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(16)),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white, width: 3.5),
                    right: BorderSide(color: Colors.white, width: 3.5),
                  ),
                  borderRadius: BorderRadius.only(topRight: Radius.circular(16)),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white, width: 3.5),
                    left: BorderSide(color: Colors.white, width: 3.5),
                  ),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16)),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white, width: 3.5),
                    right: BorderSide(color: Colors.white, width: 3.5),
                  ),
                  borderRadius: BorderRadius.only(bottomRight: Radius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideTip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.credit_card, size: 14, color: Colors.white70),
          SizedBox(width: 6),
          Text(
            'Position card within frame for best clarity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Gallery upload button
          IconButton(
            onPressed: _isCapturing ? null : _pickFromGallery,
            icon: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30, width: 1.5),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            tooltip: 'Select from Gallery',
          ),

          // Main Shutter Button
          GestureDetector(
            onTap: _isCapturing ? null : _captureCard,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: _isCapturing
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),

          // Right action: Skip Back button in 2-sided mode, or symmetric spacer
          if (_isTwoSidedMode && _scanStep == 2 && _capturedFrontFile != null)
            TextButton(
              onPressed: () {
                final front = _capturedFrontFile!;
                setState(() {
                  _scanStep = 1;
                  _capturedFrontFile = null;
                });
                _proceedToOcr(front);
              },
              child: const Text(
                'Skip Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            )
          else
            const SizedBox(width: 50),
        ],
      ),
    );
  }
}
