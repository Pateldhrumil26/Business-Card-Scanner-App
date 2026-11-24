import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

class Helpers {
  // Show clean snackbar
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    Color bgColor = AppColors.primary;
    IconData icon = Icons.info_outline;

    if (isError) {
      bgColor = AppColors.error;
      icon = Icons.error_outline;
    } else if (isSuccess) {
      bgColor = AppColors.success;
      icon = Icons.check_circle_outline;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Dial Phone Number
  static Future<void> launchCall(BuildContext context, String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri url = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (context.mounted) {
          showSnackBar(context, 'Cannot launch dialer for $phone', isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Failed to launch call: $e', isError: true);
      }
    }
  }

  // Send Email
  static Future<void> launchEmail(BuildContext context, String email) async {
    final Uri url = Uri.parse('mailto:$email');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (context.mounted) {
          showSnackBar(context, 'Cannot open email app for $email', isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Failed to open email: $e', isError: true);
      }
    }
  }

  // Open Website
  static Future<void> launchWeb(BuildContext context, String website) async {
    String cleanUrl = website.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final Uri url = Uri.parse(cleanUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          showSnackBar(context, 'Cannot open URL $website', isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Failed to open web link: $e', isError: true);
      }
    }
  }

  // Format initials from name
  static String getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
