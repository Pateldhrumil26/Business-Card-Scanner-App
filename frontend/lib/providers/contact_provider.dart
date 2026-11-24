import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_exception.dart';
import '../models/contact_model.dart';

class ContactProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<ContactModel> _contacts = [];
  List<String> _companies = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  String? _selectedCompany;
  String _sortBy = 'newest';
  int _page = 1;
  int _totalPages = 1;
  int _totalContacts = 0;

  List<ContactModel> get contacts => _contacts;
  List<String> get companies => _companies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedCompany => _selectedCompany;
  String get sortBy => _sortBy;
  int get totalPages => _totalPages;
  int get totalContacts => _totalContacts;

  /// Fetch Contacts with current filters, search, and pagination
  Future<void> fetchContacts({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{
        'page': _page,
        'limit': 50,
        'sortBy': _sortBy,
      };

      if (_searchQuery.trim().isNotEmpty) {
        queryParams['search'] = _searchQuery.trim();
      }

      if (_selectedCompany != null && _selectedCompany!.isNotEmpty) {
        queryParams['company'] = _selectedCompany!;
      }

      final res = await _api.get(
        ApiEndpoints.contacts,
        queryParameters: queryParams,
      );

      if (res.statusCode == 200 && res.data['contacts'] != null) {
        final List rawList = res.data['contacts'];
        final fetched = rawList.map((e) => ContactModel.fromJson(e)).toList();

        if (refresh || _page == 1) {
          _contacts = fetched;
        } else {
          _contacts.addAll(fetched);
        }

        _totalPages = res.data['pages'] ?? 1;
        _totalContacts = res.data['total'] ?? _contacts.length;

        if (res.data['companies'] != null) {
          _companies = List<String>.from(res.data['companies']);
        }
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load contacts: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search contacts
  void searchContacts(String query) {
    _searchQuery = query;
    fetchContacts(refresh: true);
  }

  /// Filter contacts by company
  void filterByCompany(String? company) {
    _selectedCompany = company;
    fetchContacts(refresh: true);
  }

  /// Sort contacts
  void setSortBy(String sort) {
    _sortBy = sort;
    fetchContacts(refresh: true);
  }

  /// Save new contact
  Future<bool> createContact(ContactModel contact) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        ApiEndpoints.contacts,
        data: contact.toJson(),
      );

      if (res.statusCode == 201 && res.data['contact'] != null) {
        final newContact = ContactModel.fromJson(res.data['contact']);
        _contacts.insert(0, newContact);
        _totalContacts += 1;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to save contact: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Update contact
  Future<bool> updateContact(ContactModel contact) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.put(
        ApiEndpoints.contactById(contact.id),
        data: contact.toJson(),
      );

      if (res.statusCode == 200 && res.data['contact'] != null) {
        final updated = ContactModel.fromJson(res.data['contact']);
        final index = _contacts.indexWhere((c) => c.id == contact.id);
        if (index != -1) {
          _contacts[index] = updated;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to update contact: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Delete contact
  Future<bool> deleteContact(String id) async {
    try {
      final res = await _api.delete(ApiEndpoints.contactById(id));
      if (res.statusCode == 200) {
        _contacts.removeWhere((c) => c.id == id);
        _totalContacts = _totalContacts > 0 ? _totalContacts - 1 : 0;
        notifyListeners();
        return true;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to delete contact: $e';
    }
    notifyListeners();
    return false;
  }

  /// Get VCF String
  Future<String?> getVcfString(String id) async {
    try {
      final res = await _api.get(ApiEndpoints.contactVcf(id));
      if (res.statusCode == 200) {
        return res.data.toString();
      }
    } catch (e) {
      debugPrint('[VCF Fetch Error]: $e');
    }
    return null;
  }
}
