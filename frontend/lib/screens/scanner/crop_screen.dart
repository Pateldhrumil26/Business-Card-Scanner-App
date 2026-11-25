import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import 'ocr_processing_screen.dart';

class CropScreen extends StatefulWidget {
  final File imageFile;
  final File? backImageFile;
  final bool isBackSide;
  final File? croppedFrontFile;

  const CropScreen({
    super.key,
    required this.imageFile,
    this.backImageFile,
    this.isBackSide = false,
    this.croppedFrontFile,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  Uint8List? _imageBytes;
  int _imageWidth = 0;
  int _imageHeight = 0;
  int _rotationAngle = 0; // 0, 90, 180, 270
  bool _isLoading = true;
  bool _isProcessing = false;

  // Normalized crop bounds [0.0 - 1.0]
  double _cropLeft = 0.05;
  double _cropTop = 0.20;
  double _cropRight = 0.95;
  double _cropBottom = 0.80;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    setState(() => _isLoading = true);
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null && mounted) {
        setState(() {
          _imageBytes = bytes;
          _imageWidth = decoded.width;
          _imageHeight = decoded.height;
          _isLoading = false;

          // The card is already auto-cropped, default to full card boundary
          _cropLeft = 0.01;
          _cropRight = 0.99;
          _cropTop = 0.01;
          _cropBottom = 0.99;
        });
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to load card image: $e', isError: true);
        Navigator.of(context).pop();
      }
    }
  }

  void _rotateClockwise() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
    });
  }

  Future<void> _cropAndProceed() async {
    if (_imageBytes == null) return;

    setState(() => _isProcessing = true);

    try {
      // Decode original image
      img.Image? image = img.decodeImage(_imageBytes!);
      if (image == null) throw Exception('Could not decode image');

      // Apply any user rotation first
      if (_rotationAngle != 0) {
        image = img.copyRotate(image, angle: _rotationAngle);
      }

      // Calculate pixel coordinates for crop
      final imgW = image.width;
      final imgH = image.height;

      int x = (_cropLeft * imgW).round().clamp(0, imgW - 10);
      int y = (_cropTop * imgH).round().clamp(0, imgH - 10);
      int w = ((_cropRight - _cropLeft) * imgW).round().clamp(10, imgW - x);
      int h = ((_cropBottom - _cropTop) * imgH).round().clamp(10, imgH - y);

      // Crop exclusively to card boundaries
      final img.Image cropped = img.copyCrop(
        image,
        x: x,
        y: y,
        width: w,
        height: h,
      );

      // Encode as clean high-quality JPEG
      final croppedJpg = img.encodeJpg(cropped, quality: 95);

      final tempDir = widget.imageFile.parent;
      final fileName = 'clean_card_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final cleanFile = File('${tempDir.path}/$fileName');
      await cleanFile.writeAsBytes(croppedJpg);

      if (!mounted) return;

      if (!widget.isBackSide) {
        // If there is a back side image waiting to be cropped
        if (widget.backImageFile != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CropScreen(
                imageFile: widget.backImageFile!,
                isBackSide: true,
                croppedFrontFile: cleanFile,
              ),
            ),
          );
        } else {
          // Proceed to OCR with clean front image
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => OcrProcessingScreen(
                cardImageFile: cleanFile,
              ),
            ),
          );
        }
      } else {
        // Both front and back are cropped! Proceed to OCR
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OcrProcessingScreen(
              cardImageFile: widget.croppedFrontFile!,
              backImageFile: cleanFile,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        Helpers.showSnackBar(context, 'Failed to crop card: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isBackSide ? 'Crop Card (Back Side)' : 'Crop Card (Front Side)';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right, color: Colors.white),
            tooltip: 'Rotate 90°',
            onPressed: _rotateClockwise,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reset Crop',
            onPressed: () {
              setState(() {
                _rotationAngle = 0;
                _cropLeft = 0.05;
                _cropTop = 0.20;
                _cropRight = 0.95;
                _cropBottom = 0.80;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Stack(
              children: [
                // 1. Image Preview with Rotation
                Center(
                  child: RotatedBox(
                    quarterTurns: _rotationAngle ~/ 90,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildCroppingWorkspace(constraints);
                      },
                    ),
                  ),
                ),

                // 2. Loading Indicator while saving
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Cropping card & removing background...',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 3. Bottom Action Bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.95),
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.crop, color: Colors.white70, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Adjust handles to card edges. Desk/background is removed.',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white38),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                  label: const Text('Retake'),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _isProcessing ? null : _cropAndProceed,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 2,
                                  ),
                                  icon: const Icon(Icons.check, size: 20),
                                  label: const Text(
                                    'Scan Card Only (OCR)',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCroppingWorkspace(BoxConstraints constraints) {
    if (_imageBytes == null) return const SizedBox.shrink();

    final maxW = constraints.maxWidth;
    final maxH = constraints.maxHeight - 140; // reserve bottom bar room

    // Compute aspect-fit dimensions for display
    double displayW = maxW;
    double displayH = (maxW * _imageHeight) / _imageWidth;
    if (displayH > maxH) {
      displayH = maxH;
      displayW = (maxH * _imageWidth) / _imageHeight;
    }

    return SizedBox(
      width: displayW,
      height: displayH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The Card Photo
          Image.memory(
            _imageBytes!,
            fit: BoxFit.fill,
          ),

          // Darkened Background Mask outside the crop box
          CustomPaint(
            painter: _CropMaskPainter(
              left: _cropLeft,
              top: _cropTop,
              right: _cropRight,
              bottom: _cropBottom,
            ),
          ),

          // Interactive Draggable Crop Frame
          Positioned(
            left: _cropLeft * displayW,
            top: _cropTop * displayH,
            width: (_cropRight - _cropLeft) * displayW,
            height: (_cropBottom - _cropTop) * displayH,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  // Corner Visuals
                  _buildCornerMarker(Alignment.topLeft),
                  _buildCornerMarker(Alignment.topRight),
                  _buildCornerMarker(Alignment.bottomLeft),
                  _buildCornerMarker(Alignment.bottomRight),

                  // Center grid lines
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1),
                          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1),
                        ),
                      ),
                      height: ((_cropBottom - _cropTop) * displayH) / 3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Touch Drag Handles for the 4 corners
          _buildDragHandle(
            alignment: Alignment.topLeft,
            displayW: displayW,
            displayH: displayH,
            onDrag: (dx, dy) {
              setState(() {
                _cropLeft = (_cropLeft + dx / displayW).clamp(0.0, _cropRight - 0.20);
                _cropTop = (_cropTop + dy / displayH).clamp(0.0, _cropBottom - 0.15);
              });
            },
          ),
          _buildDragHandle(
            alignment: Alignment.topRight,
            displayW: displayW,
            displayH: displayH,
            onDrag: (dx, dy) {
              setState(() {
                _cropRight = (_cropRight + dx / displayW).clamp(_cropLeft + 0.20, 1.0);
                _cropTop = (_cropTop + dy / displayH).clamp(0.0, _cropBottom - 0.15);
              });
            },
          ),
          _buildDragHandle(
            alignment: Alignment.bottomLeft,
            displayW: displayW,
            displayH: displayH,
            onDrag: (dx, dy) {
              setState(() {
                _cropLeft = (_cropLeft + dx / displayW).clamp(0.0, _cropRight - 0.20);
                _cropBottom = (_cropBottom + dy / displayH).clamp(_cropTop + 0.15, 1.0);
              });
            },
          ),
          _buildDragHandle(
            alignment: Alignment.bottomRight,
            displayW: displayW,
            displayH: displayH,
            onDrag: (dx, dy) {
              setState(() {
                _cropRight = (_cropRight + dx / displayW).clamp(_cropLeft + 0.20, 1.0);
                _cropBottom = (_cropBottom + dy / displayH).clamp(_cropTop + 0.15, 1.0);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCornerMarker(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildDragHandle({
    required Alignment alignment,
    required double displayW,
    required double displayH,
    required Function(double dx, double dy) onDrag,
  }) {
    double left = 0;
    double top = 0;

    if (alignment == Alignment.topLeft) {
      left = _cropLeft * displayW - 24;
      top = _cropTop * displayH - 24;
    } else if (alignment == Alignment.topRight) {
      left = _cropRight * displayW - 24;
      top = _cropTop * displayH - 24;
    } else if (alignment == Alignment.bottomLeft) {
      left = _cropLeft * displayW - 24;
      top = _cropBottom * displayH - 24;
    } else if (alignment == Alignment.bottomRight) {
      left = _cropRight * displayW - 24;
      top = _cropBottom * displayH - 24;
    }

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta.dx, details.delta.dy),
        child: Container(
          width: 48,
          height: 48,
          color: Colors.transparent, // Large touch hit area
        ),
      ),
    );
  }
}

/// Darkens regions outside the active crop rectangle
class _CropMaskPainter extends CustomPainter {
  final double left;
  final double top;
  final double right;
  final double bottom;

  _CropMaskPainter({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final cropRect = Rect.fromLTRB(
      left * size.width,
      top * size.height,
      right * size.width,
      bottom * size.height,
    );

    // Cut out the cropRect so only the card is bright
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter oldDelegate) {
    return oldDelegate.left != left ||
        oldDelegate.top != top ||
        oldDelegate.right != right ||
        oldDelegate.bottom != bottom;
  }
}
