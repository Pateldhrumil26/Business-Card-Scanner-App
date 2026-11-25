import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/document_scanner_helper.dart';
import 'contacts/contact_list_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'profile/profile_screen.dart';
import 'scanner/scanner_screen.dart';
import 'scanner/batch_scanner_screen.dart';
import 'scanner/batch_review_screen.dart';
import 'scanner/ocr_processing_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    if (index == 1) {
      // Single Card Scanner via Google Native Document Scanner
      _startNativeDocumentScan(isBatch: false);
    } else if (index == 2) {
      // Batch / Multi-Card Scanner via Google Native Document Scanner
      _startNativeDocumentScan(isBatch: true);
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  Future<void> _startNativeDocumentScan({required bool isBatch}) async {
    try {
      final images = await DocumentScannerHelper.scanCards(
        isBatch: isBatch,
        pageLimit: isBatch ? 25 : 1,
      );

      if (images.isNotEmpty && mounted) {
        if (isBatch) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BatchReviewScreen(photos: images),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OcrProcessingScreen(cardImageFile: images.first),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Native Document Scanner Fallback]: $e');
      if (mounted) {
        // Fallback to in-app camera screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => isBatch ? const BatchScannerScreen() : const ScannerScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      const SizedBox.shrink(), // Placeholder for Single Scan
      const SizedBox.shrink(), // Placeholder for Batch Scan
      const ContactListScreen(),
      const ProfileScreen(),
    ];

    // Determine safe active index for IndexedStack (excluding modals at 1 and 2)
    int stackIndex = 0;
    if (_currentIndex == 3) stackIndex = 3;
    if (_currentIndex == 4) stackIndex = 4;

    return Scaffold(
      body: IndexedStack(
        index: stackIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.crop_free),
              activeIcon: Icon(Icons.crop_free_outlined),
              label: 'Single Scan',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.collections_bookmark_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              label: 'Batch Scan',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Contacts',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
