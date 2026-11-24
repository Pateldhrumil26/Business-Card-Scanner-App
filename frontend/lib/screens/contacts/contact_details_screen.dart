import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../models/contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/dashboard_provider.dart';
import 'edit_contact_screen.dart';

class ContactDetailsScreen extends StatelessWidget {
  final ContactModel contact;

  const ContactDetailsScreen({super.key, required this.contact});

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${contact.personName} from your CRM?'),
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

      final success = await contactProvider.deleteContact(contact.id);
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
    final vcfData = await contactProvider.getVcfString(contact.id);

    if (vcfData != null) {
      await Share.share(
        vcfData,
        subject: '${contact.personName} Contact Card',
      );
    } else {
      // Fallback text share
      final text = '''
Contact: ${contact.personName}
Company: ${contact.companyName}
Title: ${contact.designation}
Phone: ${contact.phone}
Email: ${contact.email}
Web: ${contact.website}
''';
      await Share.share(text, subject: contact.personName);
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
            onSelected: (val) {
              if (val == 'edit') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EditContactScreen(contact: contact)),
                );
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
            // Profile Card Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      Helpers.getInitials(contact.personName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    contact.personName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (contact.designation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      contact.designation,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (contact.companyName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      contact.companyName,
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
                      if (contact.phone.isNotEmpty)
                        _buildActionButton(
                          icon: Icons.phone,
                          label: 'Call',
                          color: AppColors.success,
                          onTap: () => Helpers.launchCall(context, contact.phone),
                        ),
                      if (contact.email.isNotEmpty)
                        _buildActionButton(
                          icon: Icons.email,
                          label: 'Email',
                          color: AppColors.accent,
                          onTap: () => Helpers.launchEmail(context, contact.email),
                        ),
                      if (contact.website.isNotEmpty)
                        _buildActionButton(
                          icon: Icons.language,
                          label: 'Website',
                          color: AppColors.info,
                          onTap: () => Helpers.launchWeb(context, contact.website),
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

            // Detailed Information Section
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  if (contact.phone.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.phone_outlined,
                      title: 'Phone Number',
                      value: contact.phone,
                      onTap: () => Helpers.launchCall(context, contact.phone),
                    ),
                  if (contact.alternativePhone.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.call_outlined,
                      title: 'Alternative Phone',
                      value: contact.alternativePhone,
                      onTap: () => Helpers.launchCall(context, contact.alternativePhone),
                    ),
                  if (contact.email.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.email_outlined,
                      title: 'Email Address',
                      value: contact.email,
                      onTap: () => Helpers.launchEmail(context, contact.email),
                    ),
                  if (contact.website.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.language_outlined,
                      title: 'Website',
                      value: contact.website,
                      onTap: () => Helpers.launchWeb(context, contact.website),
                    ),
                  if (contact.address.isNotEmpty || contact.city.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.location_on_outlined,
                      title: 'Address',
                      value: [
                        if (contact.address.isNotEmpty) contact.address,
                        if (contact.city.isNotEmpty) contact.city,
                        if (contact.state.isNotEmpty) contact.state,
                        if (contact.country.isNotEmpty) contact.country,
                      ].join(', '),
                    ),
                  if (contact.gstNumber.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'GST Number',
                      value: contact.gstNumber,
                    ),
                  if (contact.servicesOffered.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.inventory_2_outlined,
                      title: 'Products & Services',
                      value: contact.servicesOffered,
                    ),
                  if (contact.notes.isNotEmpty)
                    _buildInfoTile(
                      icon: Icons.note_outlined,
                      title: 'Notes',
                      value: contact.notes,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
