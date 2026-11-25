import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

/// Helper to launch Google's official native ML Kit Document Scanner.
///
/// Features:
/// - Real-time 4-corner document edge detection with live snapping outline
/// - Automatic perspective correction (deskewing)
/// - Removes surrounding table/desk background completely
/// - Cleans shadows and optimizes contrast
/// - Returns 100% ONLY the card image with ZERO blank space
class DocumentScannerHelper {
  /// Scans one or multiple business cards using Google's native Document Scanner.
  ///
  /// [pageLimit]: Maximum number of cards to scan in a batch session (default 25).
  /// [isBatch]: If true, user can scan multiple cards continuously (Card 1, Card 2...).
  ///            If false, scans exactly 1 card.
  static Future<List<File>> scanCards({
    int pageLimit = 25,
    bool isBatch = true,
  }) async {
    DocumentScanner? documentScanner;
    try {
      documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: {DocumentFormat.jpeg},
          pageLimit: isBatch ? pageLimit : 1,
          mode: ScannerMode.full,
          isGalleryImport: true,
        ),
      );

      final DocumentScanningResult result = await documentScanner.scanDocument();
      final images = result.images;

      if (images == null || images.isEmpty) {
        return [];
      }

      return images.map((path) => File(path)).toList();
    } catch (e) {
      debugPrint('[DocumentScannerHelper Error]: $e');
      rethrow;
    } finally {
      try {
        await documentScanner?.close();
      } catch (_) {}
    }
  }
}
