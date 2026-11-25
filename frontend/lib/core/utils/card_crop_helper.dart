import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Intelligent Business Card Detection & Background Removal Utility.
///
/// Detects the card boundaries on any table/desk surface, crops away
/// the surrounding background, and returns the clean card-only image.
class CardCropHelper {
  /// Standard business card aspect ratio (e.g. 85.6mm x 53.98mm = 1.586, 3.5in x 2.0in = 1.75).
  static const double targetCardAspectRatio = 1.58;

  /// Automatically detects the business card inside [originalFile],
  /// crops away all surrounding desk/table/background,
  /// and returns a clean File containing ONLY the card.
  static Future<File> autoCropToCard(File originalFile) async {
    try {
      if (!await originalFile.exists()) return originalFile;

      final bytes = await originalFile.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return originalFile;

      // 1. Bake EXIF orientation so pixel coordinates match what is visually seen
      decoded = img.bakeOrientation(decoded);
      final imgW = decoded.width;
      final imgH = decoded.height;

      if (imgW < 50 || imgH < 50) return originalFile;

      // 2. Save a normalized temporary image to run ML Kit OCR
      final tempDir = await getTemporaryDirectory();
      final tempOrientedPath =
          '${tempDir.path}/temp_orient_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempOrientedFile = File(tempOrientedPath);
      await tempOrientedFile.writeAsBytes(img.encodeJpg(decoded, quality: 90), flush: true);

      // 3. Run Google ML Kit to detect all text blocks and their bounding envelopes
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFile(tempOrientedFile);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      // Clean up temporary oriented file
      try {
        if (await tempOrientedFile.exists()) {
          await tempOrientedFile.delete();
        }
      } catch (_) {}

      // 4. Calculate crop rectangle
      Rect cropRect;

      final validBlocks = recognizedText.blocks.where((b) {
        final t = b.text.trim();
        // Ignore noise / single punctuation marks
        return t.isNotEmpty && t.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').isNotEmpty;
      }).toList();

      if (validBlocks.isNotEmpty) {
        // Enclosing bounding box of all text on the card
        double minX = double.infinity;
        double minY = double.infinity;
        double maxX = 0.0;
        double maxY = 0.0;

        for (final block in validBlocks) {
          final box = block.boundingBox;
          if (box.left < minX) minX = box.left;
          if (box.top < minY) minY = box.top;
          if (box.right > maxX) maxX = box.right;
          if (box.bottom > maxY) maxY = box.bottom;
        }

        // Clamp to image dimensions
        minX = minX.clamp(0.0, imgW.toDouble());
        minY = minY.clamp(0.0, imgH.toDouble());
        maxX = maxX.clamp(minX + 10.0, imgW.toDouble());
        maxY = maxY.clamp(minY + 10.0, imgH.toDouble());

        final textW = maxX - minX;
        final textH = maxY - minY;

        // Try edge-gradient refinement outward from text bounds
        final detectedLeft = _findEdge(decoded, minX.round(), isHorizontal: true, isForward: false, startY: minY.round(), endY: maxY.round(), maxScan: (textW * 0.35).round());
        final detectedRight = _findEdge(decoded, maxX.round(), isHorizontal: true, isForward: true, startY: minY.round(), endY: maxY.round(), maxScan: (textW * 0.35).round());
        final detectedTop = _findEdge(decoded, minY.round(), isHorizontal: false, isForward: false, startX: minX.round(), endX: maxX.round(), maxScan: (textH * 0.45).round());
        final detectedBottom = _findEdge(decoded, maxY.round(), isHorizontal: false, isForward: true, startX: minX.round(), endX: maxX.round(), maxScan: (textH * 0.45).round());

        // Default margins around text envelope:
        // Horizontal: 9% of text width
        // Vertical: 15% of text height
        final defaultPadX = textW * 0.09;
        final defaultPadY = textH * 0.15;

        double finalLeft = detectedLeft != null ? detectedLeft.toDouble() - (textW * 0.02) : minX - defaultPadX;
        double finalRight = detectedRight != null ? detectedRight.toDouble() + (textW * 0.02) : maxX + defaultPadX;
        double finalTop = detectedTop != null ? detectedTop.toDouble() - (textH * 0.03) : minY - defaultPadY;
        double finalBottom = detectedBottom != null ? detectedBottom.toDouble() + (textH * 0.03) : maxY + defaultPadY;

        // Ensure text is never clipped
        finalLeft = min(finalLeft, minX - 8.0);
        finalRight = max(finalRight, maxX + 8.0);
        finalTop = min(finalTop, minY - 8.0);
        finalBottom = max(finalBottom, maxY + 8.0);

        // Standard aspect ratio adjustment for business cards
        double cardW = finalRight - finalLeft;
        double cardH = finalBottom - finalTop;

        if (cardW >= cardH) {
          // Landscape card
          final currentRatio = cardW / cardH;
          if (currentRatio < 1.45) {
            final targetW = cardH * targetCardAspectRatio;
            final expand = (targetW - cardW) / 2.0;
            finalLeft -= expand;
            finalRight += expand;
          } else if (currentRatio > 1.85) {
            final targetH = cardW / targetCardAspectRatio;
            final expand = (targetH - cardH) / 2.0;
            finalTop -= expand;
            finalBottom += expand;
          }
        } else {
          // Portrait card
          final currentRatio = cardH / cardW;
          if (currentRatio < 1.45) {
            final targetH = cardW * targetCardAspectRatio;
            final expand = (targetH - cardH) / 2.0;
            finalTop -= expand;
            finalBottom += expand;
          } else if (currentRatio > 1.85) {
            final targetW = cardH / targetCardAspectRatio;
            final expand = (targetW - cardW) / 2.0;
            finalLeft -= expand;
            finalRight += expand;
          }
        }

        cropRect = Rect.fromLTRB(finalLeft, finalTop, finalRight, finalBottom);
      } else {
        // Fallback when no text detected: Center guide region (~75% width, 1.58 aspect ratio)
        final cropW = imgW * 0.78;
        final cropH = cropW / targetCardAspectRatio;
        final cropX = (imgW - cropW) / 2.0;
        final cropY = (imgH - cropH) / 2.0;
        cropRect = Rect.fromLTWH(cropX, cropY, cropW, cropH);
      }

      // 5. Safe clamping to image bounds
      int cropX = cropRect.left.round().clamp(0, imgW - 1);
      int cropY = cropRect.top.round().clamp(0, imgH - 1);
      int cropW = cropRect.width.round().clamp(20, imgW - cropX);
      int cropH = cropRect.height.round().clamp(20, imgH - cropY);

      // 6. Crop exclusively to the business card
      final cropped = img.copyCrop(
        decoded,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      // 7. Write clean cropped card to persistent temporary file
      final croppedPath =
          '${tempDir.path}/card_cropped_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}.jpg';
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(img.encodeJpg(cropped, quality: 95), flush: true);

      return croppedFile;
    } catch (e) {
      debugPrint('[CardCropHelper Error]: $e');
      return originalFile;
    }
  }

  /// Scans outward along multiple slices to locate the sharpest color/luminance contrast edge
  static int? _findEdge(
    img.Image image,
    int startPos, {
    required bool isHorizontal,
    required bool isForward,
    int? startY,
    int? endY,
    int? startX,
    int? endX,
    required int maxScan,
  }) {
    try {
      if (maxScan <= 5) return null;

      final imgW = image.width;
      final imgH = image.height;

      // Sample 5 scan lines across the orthogonal span
      final List<int> samples = [];
      if (isHorizontal && startY != null && endY != null) {
        final span = max(1, endY - startY);
        for (int i = 1; i <= 5; i++) {
          final y = (startY + (span * (i / 6))).round().clamp(0, imgH - 1);
          samples.add(y);
        }
      } else if (!isHorizontal && startX != null && endX != null) {
        final span = max(1, endX - startX);
        for (int i = 1; i <= 5; i++) {
          final x = (startX + (span * (i / 6))).round().clamp(0, imgW - 1);
          samples.add(x);
        }
      }

      if (samples.isEmpty) return null;

      double maxGradient = 0.0;
      int bestEdgePos = startPos;
      final step = isForward ? 1 : -1;

      for (int offset = 4; offset <= maxScan; offset += 2) {
        final currentPos = startPos + (step * offset);
        if (isHorizontal) {
          if (currentPos < 2 || currentPos >= imgW - 2) break;
        } else {
          if (currentPos < 2 || currentPos >= imgH - 2) break;
        }

        double totalDiff = 0.0;

        for (final sample in samples) {
          final p1 = isHorizontal
              ? image.getPixel(currentPos - (step * 2), sample)
              : image.getPixel(sample, currentPos - (step * 2));
          final p2 = isHorizontal
              ? image.getPixel(currentPos + (step * 2), sample)
              : image.getPixel(sample, currentPos + (step * 2));

          final lum1 = (0.299 * p1.r + 0.587 * p1.g + 0.114 * p1.b) / 255.0;
          final lum2 = (0.299 * p2.r + 0.587 * p2.g + 0.114 * p2.b) / 255.0;

          totalDiff += (lum2 - lum1).abs();
        }

        final avgGradient = totalDiff / samples.length;

        // Significant contrast step (card boundary meeting table)
        if (avgGradient > maxGradient && avgGradient > 0.14) {
          maxGradient = avgGradient;
          bestEdgePos = currentPos;
        }
      }

      if (maxGradient > 0.16) {
        return bestEdgePos;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
