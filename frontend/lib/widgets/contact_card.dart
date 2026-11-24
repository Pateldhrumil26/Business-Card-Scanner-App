import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/helpers.dart';
import '../models/contact_model.dart';

class ContactCard extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final VoidCallback? onEmail;

  const ContactCard({
    super.key,
    required this.contact,
    this.onTap,
    this.onCall,
    this.onEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar with Initials
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: Text(
                  Helpers.getInitials(contact.personName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Contact Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.personName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (contact.companyName.isNotEmpty || contact.designation.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (contact.designation.isNotEmpty) contact.designation,
                          if (contact.companyName.isNotEmpty) contact.companyName,
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (contact.phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            contact.phone,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons (Call / Email)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (contact.phone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.call_outlined, color: AppColors.accent, size: 20),
                      onPressed: onCall ?? () => Helpers.launchCall(context, contact.phone),
                      tooltip: 'Call',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  if (contact.email.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.mail_outline, color: AppColors.accent, size: 20),
                      onPressed: onEmail ?? () => Helpers.launchEmail(context, contact.email),
                      tooltip: 'Email',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
