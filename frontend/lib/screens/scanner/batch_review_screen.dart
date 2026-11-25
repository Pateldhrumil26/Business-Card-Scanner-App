import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../models/contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../main_navigation_screen.dart';

class BatchCardItem {
  final File photo;
  ContactModel contact;
  bool isApproved;
  bool isProcessing;
  String? error;

  BatchCardItem({
    required this.photo,
    required this.contact,
    this.isApproved = true,
    this.isProcessing = false,
    this.error,
  });
}

class BatchReviewScreen extends StatefulWidget {
  final List<File> photos;

  const BatchReviewScreen({super.key, required this.photos});

  @override
  State<BatchReviewScreen> createState() => _BatchReviewScreenState();
}

class _BatchReviewScreenState extends State<BatchReviewScreen> {
  final ApiClient _api = ApiClient();
  final List<BatchCardItem> _items = [];
  bool _isExtracting = true;
  bool _isSavingAll = false;
  int _processedCount = 0;
  String _currentProcessingText = 'Initializing OCR...';
  TextRecognizer? _textRecognizer;

  @override
  void initState() {
    super.initState();
    _startBatchExtraction();
  }

  @override
  void dispose() {
    _textRecognizer?.close();
    super.dispose();
  }

  Future<void> _startBatchExtraction() async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _textRecognizer = textRecognizer;
    final List<Map<String, dynamic>> batchPayload = [];
    final List<File> validPhotos = [];

    try {
      for (int i = 0; i < widget.photos.length; i++) {
        final File photo = widget.photos[i];
        if (!mounted) break;

        setState(() {
          _processedCount = i;
          _currentProcessingText = 'Reading text on card ${i + 1} of ${widget.photos.length}...';
        });

        try {
          final inputImage = InputImage.fromFile(photo);
          final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
          final rawText = recognizedText.text;

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

          batchPayload.add({
            'index': i,
            'rawText': rawText,
            'lineData': lineData,
          });
          validPhotos.add(photo);
        } catch (ocrErr) {
          debugPrint('[Batch OCR Local Error]: $ocrErr');
          batchPayload.add({
            'index': i,
            'rawText': '',
            'lineData': [],
          });
          validPhotos.add(photo);
        }
      }
    } finally {
      await textRecognizer.close();
      if (_textRecognizer == textRecognizer) {
        _textRecognizer = null;
      }
    }

    if (mounted) {
      setState(() {
        _currentProcessingText = 'Structuring contacts via backend batch parser...';
      });
    }

    try {
      final batchRes = await _api.post(
        ApiEndpoints.batchExtractCard,
        data: {'cards': batchPayload},
      );

      if (batchRes.statusCode == 200 && batchRes.data['data'] != null) {
        final List results = batchRes.data['data'];
        for (int i = 0; i < validPhotos.length; i++) {
          final photo = validPhotos[i];
          final resItem = results.firstWhere(
            (r) => r['index'] == i,
            orElse: () => null,
          );

          if (resItem != null && resItem['extracted'] != null) {
            final data = resItem['extracted'];
            final contact = ContactModel(
              id: '',
              businessCardId: '',
              cardImageUrl: '',
              personName: data['personName'] != null && data['personName'].toString().trim().isNotEmpty
                  ? data['personName'].toString().trim()
                  : (data['companyName'] != null && data['companyName'].toString().trim().isNotEmpty
                      ? data['companyName'].toString().trim()
                      : 'Card #${i + 1}'),
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
              servicesOffered: data['servicesOffered'] ?? '',
              gstNumber: data['gstNumber'] ?? '',
              notes: 'Batch Scanned Card',
            );

            _items.add(BatchCardItem(
              photo: photo,
              contact: contact,
              isApproved: true,
            ));
          } else {
            _items.add(BatchCardItem(
              photo: photo,
              contact: ContactModel(
                id: '',
                businessCardId: '',
                cardImageUrl: '',
                personName: 'Card #${i + 1}',
                companyName: '',
                phone: '',
                email: '',
              ),
              isApproved: true,
            ));
          }
        }
      } else {
        for (int i = 0; i < validPhotos.length; i++) {
          _items.add(BatchCardItem(
            photo: validPhotos[i],
            contact: ContactModel(
              id: '',
              businessCardId: '',
              cardImageUrl: '',
              personName: 'Card #${i + 1}',
              companyName: '',
              phone: '',
              email: '',
            ),
            isApproved: true,
          ));
        }
      }
    } catch (apiErr) {
      debugPrint('[Batch Extract API Error]: $apiErr');
      for (int i = 0; i < validPhotos.length; i++) {
        _items.add(BatchCardItem(
          photo: validPhotos[i],
          contact: ContactModel(
            id: '',
            businessCardId: '',
            cardImageUrl: '',
            personName: 'Card #${i + 1}',
            companyName: '',
            phone: '',
            email: '',
          ),
          isApproved: true,
          error: 'Could not connect to backend parser.',
        ));
      }
    }

    if (mounted) {
      setState(() {
        _isExtracting = false;
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    if (_items.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  void _openEditDialog(int index) {
    final item = _items[index];
    final c = item.contact;

    final nameCtrl = TextEditingController(text: c.personName);
    final desigCtrl = TextEditingController(text: c.designation);
    final compCtrl = TextEditingController(text: c.companyName);
    final phoneCtrl = TextEditingController(text: c.phone);
    final emailCtrl = TextEditingController(text: c.email);
    final addrCtrl = TextEditingController(text: c.address);
    final ScrollController scrollController = ScrollController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header (Pinned at top)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'CARD #${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Edit Contact Details',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.textSecondary),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 0.8),

                // Middle Form Fields with visible Scrollbar
                Flexible(
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        children: [
                          _buildModalTextField(
                            controller: nameCtrl,
                            label: 'Full Name',
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildModalTextField(
                            controller: desigCtrl,
                            label: 'Job Title / Designation',
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildModalTextField(
                            controller: compCtrl,
                            label: 'Company Name',
                            icon: Icons.apartment_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildModalTextField(
                            controller: phoneCtrl,
                            label: 'Mobile / Phone Number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          _buildModalTextField(
                            controller: emailCtrl,
                            label: 'Email Address',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _buildModalTextField(
                            controller: addrCtrl,
                            label: 'Business Address',
                            icon: Icons.location_on_outlined,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                const Divider(height: 1, thickness: 0.8),

                // Pinned Bottom Action Buttons (Always visible and never clipped)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() {
                              item.contact = c.copyWith(
                                personName: nameCtrl.text.trim(),
                                designation: desigCtrl.text.trim(),
                                companyName: compCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                address: addrCtrl.text.trim(),
                              );
                            });
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        prefixIcon: Icon(icon, size: 20, color: AppColors.accent),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }

  void _showFullPhoto(File photo, int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Card #${index + 1} Photo',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black,
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.file(
                    photo,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Pinch to zoom card',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAllApproved() async {
    final approvedItems = _items.where((it) => it.isApproved).toList();
    if (approvedItems.isEmpty) {
      Helpers.showSnackBar(context, 'Please select at least one card to save.', isError: true);
      return;
    }

    setState(() => _isSavingAll = true);

    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    final dashProvider = Provider.of<DashboardProvider>(context, listen: false);

    // 1. Upload card photos to AWS S3
    final List<ContactModel> contactsToSave = [];

    for (int i = 0; i < approvedItems.length; i++) {
      final item = approvedItems[i];
      String cardImageUrl = '';
      String uploadedCardId = '';

      try {
        final bytes = await item.photo.readAsBytes();
        final base64String = base64Encode(bytes);
        final fileName = item.photo.path.split(Platform.pathSeparator).last;

        final uploadRes = await _api.post(
          ApiEndpoints.uploadCard,
          data: {
            'image': base64String,
            'fileName': fileName,
            'mimeType': 'image/jpeg',
          },
        );

        if (uploadRes.statusCode == 201 && uploadRes.data['card'] != null) {
          uploadedCardId = uploadRes.data['card']['id'] ?? '';
          cardImageUrl = uploadRes.data['card']['imageUrl'] ?? '';
        }
      } catch (uploadErr) {
        debugPrint('[Batch S3 Upload Soft Failure]: $uploadErr');
      }

      contactsToSave.add(item.contact.copyWith(
        cardImageUrl: cardImageUrl.isNotEmpty ? cardImageUrl : item.photo.path,
        businessCardId: uploadedCardId.isNotEmpty ? uploadedCardId : null,
      ));
    }

    // 2. Bulk Save Contacts via Backend Batch Endpoint (single HTTP request & insertMany)
    final savedCount = await contactProvider.createBatchContacts(contactsToSave);

    if (!mounted) return;

    setState(() => _isSavingAll = false);

    dashProvider.fetchDashboardData();

    if (savedCount > 0) {
      Helpers.showSnackBar(
        context,
        'Successfully saved $savedCount contacts in batch to CRM!',
        isSuccess: true,
      );

      // Return to main app (Contacts tab)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(initialIndex: 3), // Contacts list tab
        ),
        (route) => false,
      );
    } else {
      Helpers.showSnackBar(
        context,
        contactProvider.errorMessage ?? 'Failed to save contacts in batch.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isExtracting) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Processing Batch Cards'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(strokeWidth: 3.5, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                Text(
                  _currentProcessingText,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_processedCount} of ${widget.photos.length} cards extracted',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: widget.photos.isNotEmpty ? (_processedCount / widget.photos.length) : 0,
                  backgroundColor: AppColors.border,
                  color: AppColors.accent,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final approvedCount = _items.where((it) => it.isApproved).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Batch Review (${_items.length} Cards)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Modern Summary & Select All Bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_items.length} Cards Extracted',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Tap photo to zoom • Tap edit to adjust',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Select All / Deselect All Toggle Chip
                InkWell(
                  onTap: () {
                    final allApproved = _items.every((it) => it.isApproved);
                    setState(() {
                      for (final item in _items) {
                        item.isApproved = !allApproved;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _items.every((it) => it.isApproved)
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _items.every((it) => it.isApproved)
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 13,
                          color: _items.every((it) => it.isApproved) ? Colors.white : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _items.every((it) => it.isApproved) ? 'Deselect All' : 'Select All',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _items.every((it) => it.isApproved) ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Card List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _items[index];
                final c = item.contact;

                return Container(
                  decoration: BoxDecoration(
                    color: item.isApproved ? Colors.white : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: item.isApproved
                          ? AppColors.accent.withValues(alpha: 0.4)
                          : AppColors.border,
                      width: item.isApproved ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.isApproved
                            ? AppColors.accent.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card Header Row (Tappable to toggle selection)
                      InkWell(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        onTap: () {
                          setState(() {
                            item.isApproved = !item.isApproved;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                          child: Row(
                            children: [
                              // Check Circle Icon
                              Icon(
                                item.isApproved
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: item.isApproved ? AppColors.accent : AppColors.textMuted,
                                size: 22,
                              ),
                              const SizedBox(width: 8),

                              // Card # Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.isApproved
                                      ? AppColors.accent.withValues(alpha: 0.1)
                                      : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'CARD #${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: item.isApproved ? AppColors.accent : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Status Chip
                              if (item.isApproved)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check, size: 10, color: Color(0xFF16A34A)),
                                      SizedBox(width: 3),
                                      Text(
                                        'Ready',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Skipped',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),

                              const Spacer(),

                              // Edit Button (soft circular badge)
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.accent),
                                ),
                                tooltip: 'Edit details',
                                onPressed: () => _openEditDialog(index),
                              ),
                              const SizedBox(width: 4),

                              // Delete Button (soft circular badge)
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                ),
                                tooltip: 'Remove card',
                                onPressed: () => _removeItem(index),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Subtle divider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Divider(
                          height: 1,
                          thickness: 0.8,
                          color: AppColors.border.withValues(alpha: 0.6),
                        ),
                      ),

                      // Card Body: Photo Thumbnail + Extracted Details
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Photo Thumbnail
                            GestureDetector(
                              onTap: () => _showFullPhoto(item.photo, index),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 96,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.border),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: Image.file(
                                        item.photo,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 3,
                                    right: 3,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in_rounded,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 14),

                            // Extracted Fields Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Person Name
                                  Text(
                                    c.personName.isNotEmpty ? c.personName : '— (No Name Detected)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: c.personName.isNotEmpty
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  // Designation
                                  if (c.designation.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      c.designation,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],

                                  // Company Name
                                  if (c.companyName.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.apartment_rounded,
                                          size: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            c.companyName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  // Phone Number
                                  if (c.phone.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.phone_rounded,
                                          size: 12,
                                          color: Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          c.phone,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  // Email
                                  if (c.email.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.mail_outline_rounded,
                                          size: 12,
                                          color: AppColors.accent,
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            c.email,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: approvedCount > 0 ? const Color(0xFF10B981) : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$approvedCount of ${_items.length} selected',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Direct sync to Contacts CRM',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: _isSavingAll
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isSavingAll ? 'Saving...' : 'Save Contacts ($approvedCount)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: (_isSavingAll || approvedCount == 0) ? null : _saveAllApproved,
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
