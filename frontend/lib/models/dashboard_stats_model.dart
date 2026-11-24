class DashboardStatsModel {
  final int totalScannedCards;
  final int totalContacts;
  final int totalCompanies;
  final int recentContactsCount;

  DashboardStatsModel({
    this.totalScannedCards = 0,
    this.totalContacts = 0,
    this.totalCompanies = 0,
    this.recentContactsCount = 0,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      totalScannedCards: json['totalScannedCards'] ?? 0,
      totalContacts: json['totalContacts'] ?? 0,
      totalCompanies: json['totalCompanies'] ?? 0,
      recentContactsCount: json['recentContactsCount'] ?? 0,
    );
  }
}
