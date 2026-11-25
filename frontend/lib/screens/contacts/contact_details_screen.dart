import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/card_crop_helper.dart';
import '../../models/contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/dashboard_provider.dart';
import 'edit_contact_screen.dart';

class ContactDetailsScreen extends StatefulWidget {
  final ContactModel contact;

  const ContactDetailsScreen({super.key, required this.contact});

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  late ContactModel _contact;
  final ApiClient _api = ApiClient();
  bool _isLoadingFresh = false;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
    _fetchFreshContactDetails();
  }

  Future<void> _fetchFreshContactDetails() async {
    if (_contact.id.isEmpty) return;
    setState(() => _isLoadingFresh = true);
    try {
      final res = await _api.get(ApiEndpoints.contactById(_contact.id));
      if (res.statusCode == 200 && res.data['contact'] != null && mounted) {
        setState(() {
          _contact = ContactModel.fromJson(res.data['contact']);
        });
      }
    } catch (e) {
      debugPrint('[Fetch Fresh Contact Soft Failure]: $e');
    } finally {
      if (mounted) setState(() => _isLoadingFresh = false);
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${_contact.personName} from your CRM?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final contactProvider = Provider.of<ContactProvider>(context, listen: false);
      final dashProvider = Provider.of<DashboardProvider>(context, listen: false);

      final success = await contactProvider.deleteContact(_contact.id);
      if (context.mounted) {
        if (success) {
          dashProvider.fetchDashboardData();
          Helpers.showSnackBar(context, 'Contact deleted successfully', isSuccess: true);
          Navigator.of(context).pop();
        } else {
          Helpers.showSnackBar(context, 'Failed to delete contact', isError: true);
        }
      }
    }
  }

  Future<void> _handleShareVcf(BuildContext context) async {
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    final vcfData = await contactProvider.getVcfString(_contact.id);

    if (vcfData != null) {
      await Share.share(
        vcfData,
        subject: '${_contact.personName} Contact Card',
      );
    } else {
      final text = '''
Contact: ${_contact.personName}
Company: ${_contact.companyName}
Title: ${_contact.designation}
Phone: ${_contact.phone}
Email: ${_contact.email}
Web: ${_contact.website}
''';
      await Share.share(text, subject: _contact.personName);
    }
  }

  Future<void> _pickAndUploadCardPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              const Text('Attach Card Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: AppColors.primary, size: 20),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library, color: AppColors.accent, size: 20),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await picker.pickImage(source: source, imageQuality: 92);
      if (picked == null) return;

      if (!mounted) return;
      Helpers.showSnackBar(context, 'Cropping card and uploading to AWS S3...', isSuccess: true);

      final rawFile = File(picked.path);
      final file = await CardCropHelper.autoCropToCard(rawFile);
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final fileName = file.path.split(Platform.pathSeparator).last;

      // Upload to backend AWS S3
      final uploadRes = await _api.post(
        ApiEndpoints.uploadCard,
        data: {
          'image': base64String,
          'fileName': fileName,
          'mimeType': 'image/jpeg',
        },
      );

      String newImageUrl = '';
      String? cardId;
      if (uploadRes.statusCode == 201 && uploadRes.data['card'] != null) {
        newImageUrl = uploadRes.data['card']['imageUrl'] ?? '';
        cardId = uploadRes.data['card']['id'];
      }

      final finalUrl = newImageUrl.isNotEmpty ? newImageUrl : file.path;

      // Update contact on backend
      final contactProvider = Provider.of<ContactProvider>(context, listen: false);
      final updatedContact = _contact.copyWith(
        cardImageUrl: finalUrl,
        businessCardId: cardId ?? _contact.businessCardId,
      );

      final success = await contactProvider.updateContact(updatedContact);
      if (success && mounted) {
        setState(() {
          _contact = updatedContact;
        });
        Helpers.showSnackBar(context, 'Card photo attached successfully!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to upload photo: $e', isError: true);
      }
    }
  }

  void _showFullImageDialog(String imageUrl, {required String title}) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    title,
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
                  child: _buildImageWidget(imageUrl, fit: BoxFit.contain),
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

  Widget _buildImageWidget(String pathOrUrl, {BoxFit fit = BoxFit.cover}) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(
        pathOrUrl,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            color: Colors.grey.shade100,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 160,
            color: Colors.grey.shade100,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_outlined, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 6),
                  Text(
                    'Card image unavailable',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      final file = File(pathOrUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(
            height: 160,
            color: Colors.grey.shade100,
            child: const Center(child: Icon(Icons.broken_image_outlined, size: 36)),
          ),
        );
      } else {
        return Container(
          height: 160,
          color: Colors.grey.shade100,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.credit_card_outlined, size: 36, color: Colors.grey.shade400),
                const SizedBox(height: 6),
                Text(
                  'Card Photo File Not Found',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Contact Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Contact',
            onPressed: () => _handleShareVcf(context),
          ),
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'edit') {
                final updated = await Navigator.of(context).push<ContactModel>(
                  MaterialPageRoute(builder: (_) => EditContactScreen(contact: _contact)),
                );
                if (updated != null && mounted) {
                  setState(() => _contact = updated);
                }
              } else if (val == 'delete') {
                _handleDelete(context);
              } else if (val == 'vcf') {
                _handleShareVcf(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Edit Contact'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'vcf',
                child: Row(
                  children: [
                    Icon(Icons.download_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Export as VCF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                    SizedBox(width: 10),
                    Text('Delete Contact', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Profile Card Header (Business Card Photo replaces the circle avatar)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Top Profile Photo: Business Card Photo (click opens proper fullscreen zoom photo)
                  _buildTopProfileCardPhoto(context),
                  const SizedBox(height: 16),
                  Text(
                    _contact.personName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_contact.designation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _contact.designation,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_contact.companyName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _contact.companyName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Quick Action Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_contact.phone.isNotEmpty)
                        _buildActionButton(
                          icon: Icons.phone,
                          label: 'Call',
                          color: AppColors.success,
                          onTap: () => Helpers.launchCall(context, _contact.phone),
                        ),
                      if (_contact.email.isNotEmpty)
                        _buildActionButton(
                          icon: Icons.email,
                          label: 'Email',
                          color: AppColors.accent,
                          onTap: () => Helpers.launchEmail(context, _contact.email),
                        ),
                      if (_contact.website.isNotEmpty)
                        _buildActionButton(
                          icon: Icons.language,
                          label: 'Website',
                          color: AppColors.info,
                          onTap: () => Helpers.launchWeb(context, _contact.website),
                        ),
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'Share',
                        color: AppColors.primary,
                        onTap: () => _handleShareVcf(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Detailed Information Section
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  if (_contact.phone.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.phone_outlined,
                      title: 'Phone Number',
                      value: _contact.phone,
                      onTap: () => Helpers.launchCall(context, _contact.phone),
                    ),
                  if (_contact.alternativePhone.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.call_outlined,
                      title: 'Alternative Phone',
                      value: _contact.alternativePhone,
                      onTap: () => Helpers.launchCall(context, _contact.alternativePhone),
                    ),
                  if (_contact.email.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.email_outlined,
                      title: 'Email Address',
                      value: _contact.email,
                      onTap: () => Helpers.launchEmail(context, _contact.email),
                    ),
                  if (_contact.website.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.language_outlined,
                      title: 'Website',
                      value: _contact.website,
                      onTap: () => Helpers.launchWeb(context, _contact.website),
                    ),
                  if (_contact.address.isNotEmpty || _contact.city.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.location_on_outlined,
                      title: 'Address',
                      value: [
                        if (_contact.address.isNotEmpty) _contact.address,
                        if (_contact.city.isNotEmpty) _contact.city,
                        if (_contact.state.isNotEmpty) _contact.state,
                        if (_contact.country.isNotEmpty) _contact.country,
                      ].join(', '),
                    ),
                  if (_contact.gstNumber.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'GST Number',
                      value: _contact.gstNumber,
                    ),
                  if (_contact.servicesOffered.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.inventory_2_outlined,
                      title: 'Products & Services',
                      value: _contact.servicesOffered,
                    ),
                  if (_contact.notes.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.note_outlined,
                      title: 'Notes',
                      value: _contact.notes,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProfileCardPhoto(BuildContext context) {
    final hasPhoto = _contact.cardImageUrl != null && _contact.cardImageUrl!.trim().isNotEmpty;

    if (hasPhoto) {
      return GestureDetector(
        onTap: () => _showFullImageDialog(
          _contact.cardImageUrl!,
          title: '${_contact.personName} - Business Card',
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: 1.58,
                  child: _buildImageWidget(_contact.cardImageUrl!, fit: BoxFit.cover),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _pickAndUploadCardPhoto(context),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Tap to zoom',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _pickAndUploadCardPhoto(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_a_photo_outlined, size: 28, color: AppColors.accent),
              ),
              const SizedBox(height: 8),
              const Text(
                'Attach Business Card Photo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap to take photo with camera or choose from gallery',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: onTap != null
          ? const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted)
          : null,
      onTap: onTap,
    );
  }
}
