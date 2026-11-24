import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../models/contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class EditContactScreen extends StatefulWidget {
  final ContactModel contact;

  const EditContactScreen({super.key, required this.contact});

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _companyController;
  late TextEditingController _designationController;
  late TextEditingController _phoneController;
  late TextEditingController _altPhoneController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _gstController;
  late TextEditingController _servicesController;
  late TextEditingController _notesController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _nameController = TextEditingController(text: c.personName);
    _companyController = TextEditingController(text: c.companyName);
    _designationController = TextEditingController(text: c.designation);
    _phoneController = TextEditingController(text: c.phone);
    _altPhoneController = TextEditingController(text: c.alternativePhone);
    _emailController = TextEditingController(text: c.email);
    _websiteController = TextEditingController(text: c.website);
    _addressController = TextEditingController(text: c.address);
    _cityController = TextEditingController(text: c.city);
    _stateController = TextEditingController(text: c.state);
    _countryController = TextEditingController(text: c.country);
    _gstController = TextEditingController(text: c.gstNumber);
    _servicesController = TextEditingController(text: c.servicesOffered);
    _notesController = TextEditingController(text: c.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _designationController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _gstController.dispose();
    _servicesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    final dashProvider = Provider.of<DashboardProvider>(context, listen: false);

    final updated = widget.contact.copyWith(
      personName: _nameController.text.trim(),
      companyName: _companyController.text.trim(),
      designation: _designationController.text.trim(),
      phone: _phoneController.text.trim(),
      alternativePhone: _altPhoneController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      website: _websiteController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      country: _countryController.text.trim(),
      gstNumber: _gstController.text.trim(),
      servicesOffered: _servicesController.text.trim(),
      notes: _notesController.text.trim(),
    );

    final success = await contactProvider.updateContact(updated);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      dashProvider.fetchDashboardData();
      Helpers.showSnackBar(context, 'Contact updated successfully', isSuccess: true);
      Navigator.of(context).pop();
    } else {
      Helpers.showSnackBar(
        context,
        contactProvider.errorMessage ?? 'Failed to update contact',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Contact'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _nameController,
                label: 'Person Name',
                isRequired: true,
                validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),

              CustomTextField(controller: _companyController, label: 'Company Name'),
              const SizedBox(height: 14),

              CustomTextField(controller: _designationController, label: 'Designation'),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _phoneController,
                      label: 'Phone',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _altPhoneController,
                      label: 'Alt Phone',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              CustomTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),

              CustomTextField(controller: _websiteController, label: 'Website'),
              const SizedBox(height: 14),

              CustomTextField(
                controller: _servicesController,
                label: 'Products & Services Offered',
                hint: 'Website, CRM, ERP or SIP, Insurance or CNC Machines',
                maxLines: 2,
              ),
              const SizedBox(height: 14),

              CustomTextField(controller: _addressController, label: 'Address', maxLines: 2),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(child: CustomTextField(controller: _cityController, label: 'City')),
                  const SizedBox(width: 12),
                  Expanded(child: CustomTextField(controller: _stateController, label: 'State')),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(child: CustomTextField(controller: _countryController, label: 'Country')),
                  const SizedBox(width: 12),
                  Expanded(child: CustomTextField(controller: _gstController, label: 'GST Number')),
                ],
              ),
              const SizedBox(height: 14),

              CustomTextField(controller: _notesController, label: 'Notes', maxLines: 2),
              const SizedBox(height: 28),

              CustomButton(
                text: 'Save Changes',
                isLoading: _isSaving,
                onPressed: _handleUpdate,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
