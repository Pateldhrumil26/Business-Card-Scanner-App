import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import 'batch_review_screen.dart';

class BatchScannerScreen extends StatefulWidget {
  const BatchScannerScreen({super.key});

  @override
  State<BatchScannerScreen> createState() => _BatchScannerScreenState();
}

class _BatchScannerScreenState extends State<BatchScannerScreen> with WidgetsBindingObserver {
  final GlobalKey _guideFrameKey = GlobalKey();
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  int _selectedCameraIndex = 0;
  final List<File> _capturedPhotos = [];
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
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
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
      debugPrint('[Batch Camera Init Error]: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        setState(() => _isFlashOn = false);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        setState(() => _isFlashOn = true);
      }
    } catch (_) {
      try {
        await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.off : FlashMode.always);
        setState(() => _isFlashOn = !_isFlashOn);
      } catch (_) {
        setState(() => _isFlashOn = false);
      }
    }
  }

  Future<File> _cropToCardGuide(File originalFile) async {
    try {
      final bytes = await originalFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return originalFile;

      // Ensure orientation is applied so pixels match screen visual
      image = img.bakeOrientation(image);

      final imgW = image.width;
      final imgH = image.height;

      // Default safe fractions (upper center of portrait)
      double fractionX = 0.04;
      double fractionY = 0.22;
      double fractionW = 0.92;
      double fractionH = 0.44;

      try {
        final guideBox = _guideFrameKey.currentContext?.findRenderObject() as RenderBox?;
        if (guideBox != null && mounted) {
          final guidePos = guideBox.localToGlobal(Offset.zero);
          final guideSize = guideBox.size;
          final screenSize = MediaQuery.of(context).size;

          if (screenSize.height > 0 && screenSize.width > 0) {
            // Camera preview fills screen using BoxFit.cover
            // Determine camera portrait aspect ratio (sensor width / height in portrait)
            final cameraAspect = imgW < imgH ? (imgW / imgH) : (imgH / imgW);
            final screenAspect = screenSize.width / screenSize.height;

            double renderedW, renderedH;
            double offsetX = 0.0;
            double offsetY = 0.0;

            if (screenAspect < cameraAspect) {
              // Screen is narrower than camera: preview height matches screen height;
              // preview width is wider and overflows horizontally
              renderedH = screenSize.height;
              renderedW = renderedH * cameraAspect;
              offsetX = (renderedW - screenSize.width) / 2.0;
              offsetY = 0.0;
            } else {
              // Screen is wider than camera: preview width matches screen width;
              // preview height is taller and overflows vertically
              renderedW = screenSize.width;
              renderedH = renderedW / cameraAspect;
              offsetX = 0.0;
              offsetY = (renderedH - screenSize.height) / 2.0;
            }

            // Guide frame bounding box on screen
            final boxLeft = guidePos.dx;
            final boxTop = guidePos.dy;
            final boxRight = boxLeft + guideSize.width;
            final boxBottom = boxTop + guideSize.height;

            // 12% safety margin around guide frame so borders & top phone/name are NEVER cut off
            final padX = guideSize.width * 0.12;
            final padY = guideSize.height * 0.12;

            final targetLeft = boxLeft - padX;
            final targetTop = boxTop - padY;
            final targetRight = boxRight + padX;
            final targetBottom = boxBottom + padY;

            // Map into normalized preview frame (0.0 to 1.0)
            final normLeft = ((targetLeft + offsetX) / renderedW).clamp(0.0, 1.0);
            final normTop = ((targetTop + offsetY) / renderedH).clamp(0.0, 1.0);
            final normRight = ((targetRight + offsetX) / renderedW).clamp(0.0, 1.0);
            final normBottom = ((targetBottom + offsetY) / renderedH).clamp(0.0, 1.0);

            fractionX = normLeft;
            fractionY = normTop;
            fractionW = (normRight - normLeft).clamp(0.10, 1.0);
            fractionH = (normBottom - normTop).clamp(0.10, 1.0);
          }
        }
      } catch (geomErr) {
        debugPrint('[Guide Frame Geometry Check]: $geomErr');
      }

      int cropX, cropY, cropW, cropH;

      if (imgH > imgW) {
        // Vertical / Portrait photo
        cropX = (imgW * fractionX).round();
        cropY = (imgH * fractionY).round();
        cropW = (imgW * fractionW).round();
        cropH = (imgH * fractionH).round();
      } else {
        // Horizontal / Landscape photo
        cropH = (imgH * 0.88).round();
        cropW = (cropH * 1.58).round();
        if (cropW > imgW) {
          cropW = imgW;
          cropH = (cropW / 1.58).round();
        }
        cropX = ((imgW - cropW) / 2).round();
        cropY = ((imgH - cropH) / 2).round();
      }

      // Safe bounds clamping
      cropX = cropX.clamp(0, imgW - 1);
      cropY = cropY.clamp(0, imgH - 1);
      cropW = cropW.clamp(1, imgW - cropX);
      cropH = cropH.clamp(1, imgH - cropY);

      final cropped = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      final tempDir = await getTemporaryDirectory();
      final croppedPath = '${tempDir.path}/batch_card_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(img.encodeJpg(cropped, quality: 95), flush: true);

      return croppedFile;
    } catch (e) {
      debugPrint('[Crop to Card Guide Error]: $e');
      return originalFile;
    }
  }

  Future<void> _captureCard() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final XFile photo = await _cameraController!.takePicture();
      final File imageFile = File(photo.path);

      // Automatically crop image to the card guide frame area
      final File finalCardFile = await _cropToCardGuide(imageFile);

      if (!mounted) return;

      setState(() {
        _capturedPhotos.add(finalCardFile);
        _isCapturing = false;
      });

      // Show brief feedback
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Card #${_capturedPhotos.length} captured! Total: ${_capturedPhotos.length} cards'),
          duration: const Duration(milliseconds: 1200),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        Helpers.showSnackBar(context, 'Capture failed: $e', isError: true);
      }
    }
  }

  Future<void> _pickMultiFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 100);
      if (images.isNotEmpty && mounted) {
        setState(() {
          _capturedPhotos.addAll(images.map((img) => File(img.path)));
        });
        Helpers.showSnackBar(
          context,
          'Added ${images.length} photos! Total: ${_capturedPhotos.length} cards',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to pick images: $e', isError: true);
      }
    }
  }

  void _proceedToReview() {
    if (_capturedPhotos.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BatchReviewScreen(photos: List.from(_capturedPhotos)),
      ),
    );
  }

  void _removePhoto(int index) {
    if (index >= 0 && index < _capturedPhotos.length) {
      setState(() {
        _capturedPhotos.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Preview
          _buildCameraPreview(context),

          // 2. Overlay UI
          SafeArea(
            child: Column(
              children: [
                // Top Action Bar
                _buildTopBar(),

                const SizedBox(height: 8),

                // Batch Mode Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.collections_bookmark_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Batch Scan Mode (${_capturedPhotos.length} captured)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Center Rectangular Guide Frame
                _buildCardGuideFrame(context),

                const SizedBox(height: 12),

                // Helper Tip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Point at each card and tap capture. Repeat for all cards.',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),

                const Spacer(),

                // Horizontal Captured Thumbnails Carousel
                if (_capturedPhotos.isNotEmpty) _buildThumbnailCarousel(),

                // Bottom Controls Bar
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
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final camera = _cameraController!.value;
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
          const Text(
            'Batch Card Scanner',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildCardGuideFrame(BuildContext context) {
    return Container(
      key: _guideFrameKey,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AspectRatio(
        aspectRatio: 1.58,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            // Corners
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

  Widget _buildThumbnailCarousel() {
    return Container(
      height: 70,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _capturedPhotos.length,
        itemBuilder: (context, index) {
          final file = _capturedPhotos[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5),
                  image: DecorationImage(
                    image: FileImage(file),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removePhoto(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomControls() {
    final count = _capturedPhotos.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Multi-Gallery Picker Button
          IconButton(
            onPressed: _isCapturing ? null : _pickMultiFromGallery,
            icon: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30, width: 1.5),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            tooltip: 'Add from Gallery',
          ),

          // Main Continuous Shutter Button
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
                        child: count > 0
                            ? Center(
                                child: Text(
                                  '+',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
              ),
            ),
          ),

          // Review / Done Button (with counter badge)
          GestureDetector(
            onTap: count > 0 ? _proceedToReview : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: count > 0 ? AppColors.accent : Colors.white24,
                borderRadius: BorderRadius.circular(24),
                boxShadow: count > 0
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count > 0 ? 'Review ($count)' : 'Done',
                    style: TextStyle(
                      color: count > 0 ? Colors.white : Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: count > 0 ? Colors.white : Colors.white54,
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
