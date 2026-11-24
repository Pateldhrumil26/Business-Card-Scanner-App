import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_exception.dart';
import '../models/contact_model.dart';

class ScanProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  File? _scannedImageFile;
  File? _scannedBackImageFile;
  String _rawExtractedText = '';
  ContactModel? _extractedContact;
  List<String> _missingFields = [];
  String? _uploadedCardId;
  String? _cardImageUrl;
  String? _backCardImageUrl;

  bool _isProcessing = false;
  String _processingStatusText = '';
  String? _errorMessage;

  File? get scannedImageFile => _scannedImageFile;
  File? get scannedBackImageFile => _scannedBackImageFile;
  String get rawExtractedText => _rawExtractedText;
  ContactModel? get extractedContact => _extractedContact;
  List<String> get missingFields => _missingFields;
  String? get uploadedCardId => _uploadedCardId;
  String? get cardImageUrl => _cardImageUrl;
  String? get backCardImageUrl => _backCardImageUrl;

  bool get isProcessing => _isProcessing;
  String get processingStatusText => _processingStatusText;
  String? get errorMessage => _errorMessage;

  /// Process captured/selected image(s):
  /// 1. Runs Google ML Kit Text Recognition on front (and optional back) image
  /// 2. Uploads images to backend /api/cards/upload
  /// 3. Sends combined extracted text to backend /api/cards/extract for intelligent parsing
  Future<bool> processBusinessCardImage(File imageFile, {File? backImageFile}) async {
    _scannedImageFile = imageFile;
    _scannedBackImageFile = backImageFile;
    _isProcessing = true;
    _errorMessage = null;
    _processingStatusText = 'Initializing Google ML Kit OCR...';
    notifyListeners();

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      // Step 1: Client-Side Google ML Kit OCR (Front Side)
      _processingStatusText = 'Scanning front side with Google ML Kit...';
      notifyListeners();

      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      String frontText = recognizedText.text;

      // Extract lines with their visual bounding box heights (to accurately detect largest font Company text)
      final List<Map<String, dynamic>> lineData = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final box = line.boundingBox;
          lineData.add({
            'text': line.text.trim(),
            'height': box.height,
            'width': box.width,
            'top': box.top,
            'left': box.left,
          });
        }
      }

      // Step 1b: Optional Back Side OCR
      String backText = '';
      if (backImageFile != null && await backImageFile.exists()) {
        _processingStatusText = 'Scanning back side with Google ML Kit...';
        notifyListeners();

        final backInputImage = InputImage.fromFile(backImageFile);
        final RecognizedText backRecognizedText = await textRecognizer.processImage(backInputImage);
        backText = backRecognizedText.text;

        for (final block in backRecognizedText.blocks) {
          for (final line in block.lines) {
            final box = line.boundingBox;
            lineData.add({
              'text': line.text.trim(),
              'height': box.height,
              'width': box.width,
              'top': box.top,
              'left': box.left,
            });
          }
        }
      }

      _rawExtractedText = backText.isNotEmpty
          ? '$frontText\n\n--- BACK SIDE ---\n$backText'
          : frontText;

      if (_rawExtractedText.trim().isEmpty) {
        throw ApiException(
          message: 'No readable text was detected on the card. Please ensure good lighting and clear focus, then retake.',
        );
      }

      // Step 2: Upload Card Image(s) to AWS S3 (Multer-free)
      _processingStatusText = 'Uploading card image(s) to AWS S3...';
      notifyListeners();

      try {
        final bytes = await imageFile.readAsBytes();
        final base64String = base64Encode(bytes);
        final fileName = imageFile.path.split(Platform.pathSeparator).last;

        String? backBase64;
        String? backFileName;
        if (backImageFile != null && await backImageFile.exists()) {
          final backBytes = await backImageFile.readAsBytes();
          backBase64 = base64Encode(backBytes);
          backFileName = backImageFile.path.split(Platform.pathSeparator).last;
        }

        final uploadRes = await _api.post(
          ApiEndpoints.uploadCard,
          data: {
            'image': base64String,
            'fileName': fileName,
            'mimeType': fileName.endsWith('.png') ? 'image/png' : 'image/jpeg',
            if (backBase64 != null) 'backImage': backBase64,
            if (backFileName != null) 'backFileName': backFileName,
          },
        );

        if (uploadRes.statusCode == 201 && uploadRes.data['card'] != null) {
          _uploadedCardId = uploadRes.data['card']['id'];
          _cardImageUrl = uploadRes.data['card']['imageUrl'];
          _backCardImageUrl = uploadRes.data['card']['backImageUrl'];
        }
      } catch (uploadErr) {
        // Continue extraction even if network upload hit soft issue
        debugPrint('[AWS S3 Upload Soft Failure]: $uploadErr');
      }

      // Step 3: Send to Backend Intelligent Extraction Endpoint
      _processingStatusText = 'Structuring details (names, companies, numbers, services)...';
      notifyListeners();

      final extractRes = await _api.post(
        ApiEndpoints.extractCard,
        data: {
          'rawText': _rawExtractedText,
          'cardId': _uploadedCardId,
          'lineData': lineData,
        },
      );

      if (extractRes.statusCode == 200 && extractRes.data['data'] != null) {
        final data = extractRes.data['data'];

        _missingFields = List<String>.from(data['missingFields'] ?? []);

        final List<DetectedPerson> detectedPersons = [];
        if (data['detectedPersons'] != null && data['detectedPersons'] is List) {
          for (final p in data['detectedPersons']) {
            if (p is Map<String, dynamic>) {
              detectedPersons.add(DetectedPerson.fromJson(p));
            }
          }
        }

        _extractedContact = ContactModel(
          id: '',
          businessCardId: _uploadedCardId,
          cardImageUrl: _cardImageUrl,
          backImageUrl: _backCardImageUrl,
          personName: data['personName'] ?? '',
          companyName: data['companyName'] ?? '',
          designation: data['designation'] ?? '',
          phone: data['phone'] ?? '',
          alternativePhone: data['alternativePhone'] ?? '',
          email: data['email'] ?? '',
          website: data['website'] ?? '',
          address: data['address'] ?? '',
          city: data['city'] ?? '',
          state: data['state'] ?? '',
          country: data['country'] ?? 'India',
          gstNumber: data['gstNumber'] ?? '',
          category: data['category'] ?? 'Business',
          servicesOffered: data['servicesOffered'] ?? '',
          hasMultiplePersons: data['hasMultiplePersons'] == true || detectedPersons.length >= 2,
          detectedPersons: detectedPersons,
        );

        _isProcessing = false;
        notifyListeners();
        return true;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'OCR Processing error: $e';
    } finally {
      await textRecognizer.close();
    }

    _isProcessing = false;
    notifyListeners();
    return false;
  }

  void updateExtractedContact(ContactModel updated) {
    _extractedContact = updated;
    notifyListeners();
  }

  void reset() {
    _scannedImageFile = null;
    _scannedBackImageFile = null;
    _rawExtractedText = '';
    _extractedContact = null;
    _missingFields = [];
    _uploadedCardId = null;
    _cardImageUrl = null;
    _backCardImageUrl = null;
    _isProcessing = false;
    _errorMessage = null;
    notifyListeners();
  }
}
