import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/business_card_model.dart';
import '../models/contact_model.dart';
import '../models/dashboard_stats_model.dart';

class DashboardProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  DashboardStatsModel _stats = DashboardStatsModel();
  List<ContactModel> _recentContacts = [];
  List<BusinessCardModel> _recentCards = [];
  bool _isLoading = false;
  String? _errorMessage;

  DashboardStatsModel get stats => _stats;
  List<ContactModel> get recentContacts => _recentContacts;
  List<BusinessCardModel> get recentCards => _recentCards;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetch both dashboard stats and recent activity in parallel
  Future<void> fetchDashboardData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.get(ApiEndpoints.dashboardStats),
        _api.get(ApiEndpoints.dashboardRecent),
      ]);

      // Process Stats
      final statsRes = results[0];
      if (statsRes.statusCode == 200 && statsRes.data['stats'] != null) {
        _stats = DashboardStatsModel.fromJson(statsRes.data['stats']);
      }

      // Process Recent Contacts and Cards
      final recentRes = results[1];
      if (recentRes.statusCode == 200) {
        if (recentRes.data['recentContacts'] != null) {
          final List cList = recentRes.data['recentContacts'];
          _recentContacts = cList.map((e) => ContactModel.fromJson(e)).toList();
        }
        if (recentRes.data['recentCards'] != null) {
          final List cardList = recentRes.data['recentCards'];
          _recentCards = cardList.map((e) => BusinessCardModel.fromJson(e)).toList();
        }
      }
    } catch (e) {
      _errorMessage = 'Could not refresh dashboard data.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
