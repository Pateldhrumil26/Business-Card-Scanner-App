import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../widgets/contact_card.dart';
import '../../widgets/empty_state.dart';
import '../scanner/scanner_screen.dart';
import 'contact_details_screen.dart';

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ContactProvider>(context, listen: false);
      _searchController.text = provider.searchQuery;
      provider.fetchContacts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    Provider.of<ContactProvider>(context, listen: false).searchContacts(val);
  }

  @override
  Widget build(BuildContext context) {
    final contactProvider = Provider.of<ContactProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Contacts Directory'),
        actions: [
          // Sort Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: AppColors.textPrimary),
            tooltip: 'Sort By',
            initialValue: contactProvider.sortBy,
            onSelected: (val) {
              contactProvider.setSortBy(val);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'newest', child: Text('Newest First')),
              const PopupMenuItem(value: 'oldest', child: Text('Oldest First')),
              const PopupMenuItem(value: 'name-asc', child: Text('Name (A-Z)')),
              const PopupMenuItem(value: 'company-asc', child: Text('Company (A-Z)')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Input Bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name, company, email, phone...',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Company Filter Chips (horizontal scroll)
          if (contactProvider.companies.isNotEmpty)
            Container(
              height: 48,
              color: AppColors.surface,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: contactProvider.selectedCompany == null,
                    onSelected: (selected) {
                      if (selected) contactProvider.filterByCompany(null);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: contactProvider.selectedCompany == null ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...contactProvider.companies.map((company) {
                    final isSelected = contactProvider.selectedCompany == company;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(company),
                        selected: isSelected,
                        onSelected: (selected) {
                          contactProvider.filterByCompany(selected ? company : null);
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

          const Divider(height: 1, color: AppColors.border),

          // Contact List or Empty State
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => contactProvider.fetchContacts(refresh: true),
              color: AppColors.primary,
              child: contactProvider.isLoading && contactProvider.contacts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : contactProvider.contacts.isEmpty
                      ? EmptyState(
                          icon: Icons.person_search_outlined,
                          title: 'No Contacts Found',
                          subtitle: contactProvider.searchQuery.isNotEmpty
                              ? 'No results matching "${contactProvider.searchQuery}". Try different keywords.'
                              : 'You haven\'t saved any business card contacts yet.',
                          buttonText: 'Scan Business Card',
                          onButtonPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ScannerScreen()),
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: contactProvider.contacts.length,
                          itemBuilder: (ctx, index) {
                            final ContactModel contact = contactProvider.contacts[index];
                            return ContactCard(
                              contact: contact,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ContactDetailsScreen(contact: contact),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
