import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../models/contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ExtractedDetailsScreen extends StatefulWidget {
  final File? cardImageFile;
  final File? backImageFile;
  final ContactModel initialContact;
  final String rawText;
  final List<String> missingFields;

  const ExtractedDetailsScreen({
    super.key,
    this.cardImageFile,
    this.backImageFile,
    required this.initialContact,
    this.rawText = '',
    this.missingFields = const [],
  });

  @override
  State<ExtractedDetailsScreen> createState() => _ExtractedDetailsScreenState();
}

class _ExtractedDetailsScreenState extends State<ExtractedDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Core Fields (Company, Person 1, Person 2, Mobile 1, Mobile 2, Email, Address)
  late TextEditingController _companyController;
  late TextEditingController _nameController;
  late TextEditingController _person2NameController;
  late TextEditingController _phoneController;
  late TextEditingController _person2PhoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  bool _isSaving = false;
  bool _showFrontPreview = true;

  @override
  void initState() {
    super.initState();
    final c = widget.initialContact;

    // Check if multiple persons were detected
    String person1Name = c.personName;
    String person1Phone = c.phone;

    String person2Name = '';
    String person2Phone = c.alternativePhone;

    if (c.detectedPersons.length >= 2) {
      person1Name = c.detectedPersons[0].name;
      person1Phone = c.detectedPersons[0].phone.isNotEmpty ? c.detectedPersons[0].phone : c.phone;

      person2Name = c.detectedPersons[1].name;
      person2Phone = c.detectedPersons[1].phone.isNotEmpty ? c.detectedPersons[1].phone : c.alternativePhone;
    }

    _companyController = TextEditingController(text: c.companyName);
    _nameController = TextEditingController(text: person1Name);
    _person2NameController = TextEditingController(text: person2Name);
    _phoneController = TextEditingController(text: person1Phone);
    _person2PhoneController = TextEditingController(text: person2Phone);
    _emailController = TextEditingController(text: c.email);
    _addressController = TextEditingController(text: c.address);
  }

  @override
  void dispose() {
    _companyController.dispose();
    _nameController.dispose();
    _person2NameController.dispose();
    _phoneController.dispose();
    _person2PhoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool _isFieldUncertain(String fieldName) {
    return widget.missingFields.contains(fieldName);
  }

  Future<void> _handleSaveContact() async {
    if (!_formKey.currentState!.validate()) {
      Helpers.showSnackBar(context, 'Please fill in required fields', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    final dashProvider = Provider.of<DashboardProvider>(context, listen: false);

    final company = _companyController.text.trim();
    final address = _addressController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final website = widget.initialContact.website;
    final notes = widget.initialContact.notes;

    // Primary Contact (preserves parsed city/state/services in the background)
    final primaryContact = ContactModel(
      id: widget.initialContact.id,
      businessCardId: widget.initialContact.businessCardId,
      cardImageUrl: widget.initialContact.cardImageUrl,
      backImageUrl: widget.initialContact.backImageUrl,
      companyName: company,
      personName: _nameController.text.trim(),
      designation: widget.initialContact.designation,
      phone: _phoneController.text.trim(),
      alternativePhone: _person2PhoneController.text.trim(),
      email: email,
      website: website,
      address: address,
      city: widget.initialContact.city,
      state: widget.initialContact.state,
      country: widget.initialContact.country.isNotEmpty ? widget.initialContact.country : 'India',
      servicesOffered: widget.initialContact.servicesOffered,
      gstNumber: widget.initialContact.gstNumber,
      notes: notes,
    );

    final successPrimary = await contactProvider.createContact(primaryContact);

    // Save Person 2 if filled
    final person2Name = _person2NameController.text.trim();
    bool successSecondary = true;
    if (person2Name.isNotEmpty) {
      final secondaryContact = ContactModel(
        id: '',
        businessCardId: widget.initialContact.businessCardId,
        cardImageUrl: widget.initialContact.cardImageUrl,
        backImageUrl: widget.initialContact.backImageUrl,
        companyName: company,
        personName: person2Name,
        designation: widget.initialContact.designation,
        phone: _person2PhoneController.text.trim().isNotEmpty
            ? _person2PhoneController.text.trim()
            : _phoneController.text.trim(),
        alternativePhone: _phoneController.text.trim(),
        email: email,
        website: website,
        address: address,
        city: widget.initialContact.city,
        state: widget.initialContact.state,
        country: widget.initialContact.country.isNotEmpty ? widget.initialContact.country : 'India',
        servicesOffered: widget.initialContact.servicesOffered,
        gstNumber: widget.initialContact.gstNumber,
        notes: notes.isNotEmpty ? '$notes (Partner)' : 'Partner with ${_nameController.text.trim()}',
      );
      successSecondary = await contactProvider.createContact(secondaryContact);
    }

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (successPrimary && successSecondary) {
      dashProvider.fetchDashboardData();
      final msg = person2Name.isNotEmpty
          ? 'Both contacts saved successfully to CRM!'
          : 'Contact saved successfully to CRM!';
      Helpers.showSnackBar(context, msg, isSuccess: true);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Helpers.showSnackBar(
        context,
        contactProvider.errorMessage ?? 'Failed to save contact. Please check network.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBackSide = widget.backImageFile != null ||
        (widget.initialContact.backImageUrl != null && widget.initialContact.backImageUrl!.isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Review Extracted Details'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert, color: AppColors.accent),
            tooltip: 'Swap Company & Person Name',
            onPressed: () {
              setState(() {
                final temp = _nameController.text;
                _nameController.text = _companyController.text;
                _companyController.text = temp;
              });
              Helpers.showSnackBar(context, 'Swapped Company Name & Person Name', isSuccess: true);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Front / Back Side Toggle (if 2-sided card)
                if (hasBackSide)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Front Side'),
                          selected: _showFrontPreview,
                          selectedColor: AppColors.accent,
                          labelStyle: TextStyle(
                            color: _showFrontPreview ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _showFrontPreview = true);
                          },
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Back Side'),
                          selected: !_showFrontPreview,
                          selectedColor: AppColors.accent,
                          labelStyle: TextStyle(
                            color: !_showFrontPreview ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _showFrontPreview = false);
                          },
                        ),
                      ],
                    ),
                  ),

                // Card Preview Image (supports both File and Network)
                Container(
                  height: 160,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade100,
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildPreviewImage(),
                      if (hasBackSide)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _showFrontPreview ? 'Front Side' : 'Back Side',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Simple Info Note
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Review extracted fields below and tap Save Contact to CRM.',
                          style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

                // ==========================================
                // 1. COMPANY NAME (Top Field)
                // ==========================================
                CustomTextField(
                  controller: _companyController,
                  label: 'Company Name *',
                  hint: 'Company / Business Name',
                  prefixIcon: Icons.business_outlined,
                  isMissingOrUncertain: _isFieldUncertain('companyName'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Company name is required';
                    }
                    return null;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.swap_vert, size: 15, color: AppColors.accent),
                        label: const Text(
                          'Swap Company & Person Name',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
                        ),
                        onPressed: () {
                          setState(() {
                            final temp = _nameController.text;
                            _nameController.text = _companyController.text;
                            _companyController.text = temp;
                          });
                          Helpers.showSnackBar(context, 'Swapped Company Name & Person Name', isSuccess: true);
                        },
                      ),
                    ],
                  ),
                ),

                // ==========================================
                // 2. PERSON NAME
                // ==========================================
                CustomTextField(
                  controller: _nameController,
                  label: 'Person Name *',
                  hint: 'Contact Person Name',
                  prefixIcon: Icons.person_outlined,
                  isMissingOrUncertain: _isFieldUncertain('personName'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Person name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // PERSON 2 NAME (Fixed field, populated when 2 persons are detected)
                CustomTextField(
                  controller: _person2NameController,
                  label: 'Person 2 Name (Optional)',
                  hint: 'Second partner/director if on card',
                  prefixIcon: Icons.person_add_alt_outlined,
                ),
                const SizedBox(height: 12),

                // ==========================================
                // 3. MOBILE NUMBER(S) (Full width for clear, unclipped 10-digit view)
                // ==========================================
                CustomTextField(
                  controller: _phoneController,
                  label: 'Mobile Number *',
                  hint: '+91 98765 43210',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  isMissingOrUncertain: _isFieldUncertain('phone'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Mobile number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                CustomTextField(
                  controller: _person2PhoneController,
                  label: 'Mobile 2 / Alt Phone (Optional)',
                  hint: '+91 98250 12345',
                  prefixIcon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                // ==========================================
                // 4. EMAIL ID
                // ==========================================
                CustomTextField(
                  controller: _emailController,
                  label: 'Email ID',
                  hint: 'contact@company.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  isMissingOrUncertain: _isFieldUncertain('email'),
                ),
                const SizedBox(height: 12),

                // ==========================================
                // 5. BUSINESS ADDRESS
                // ==========================================
                CustomTextField(
                  controller: _addressController,
                  label: 'Business Address',
                  hint: 'Office No, Building, Area, City, State, PIN',
                  prefixIcon: Icons.location_on_outlined,
                  maxLines: 2,
                ),

                const SizedBox(height: 24),

                // ==========================================
                // EXACTLY ONE SAVE BUTTON
                // ==========================================
                CustomButton(
                  text: 'Save Contact to CRM',
                  icon: Icons.check,
                  isLoading: _isSaving,
                  onPressed: _handleSaveContact,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewImage() {
    final isFront = _showFrontPreview;
    final file = isFront ? widget.cardImageFile : (widget.backImageFile ?? widget.cardImageFile);
    final url = isFront ? widget.initialContact.cardImageUrl : (widget.initialContact.backImageUrl ?? widget.initialContact.cardImageUrl);

    if (file != null && file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallback(url),
      );
    }
    return _buildFallback(url);
  }

  Widget _buildFallback(String? url) {
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.credit_card, size: 40, color: Colors.grey),
    );
  }
}
