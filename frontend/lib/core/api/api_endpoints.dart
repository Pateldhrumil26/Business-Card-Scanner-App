class ApiEndpoints {
  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String profile = '/auth/profile';
  static const String changePassword = '/auth/change-password';

  // Business Cards
  static const String uploadCard = '/cards/upload';
  static const String extractCard = '/cards/extract';
  static const String batchExtractCard = '/cards/batch-extract';
  static const String cards = '/cards';
  static String cardById(String id) => '/cards/$id';

  // Contacts
  static const String contacts = '/contacts';
  static const String batchContacts = '/contacts/batch';
  static String contactById(String id) => '/contacts/$id';
  static String contactVcf(String id) => '/contacts/$id/vcf';

  // Dashboard
  static const String dashboardStats = '/dashboard/stats';
  static const String dashboardRecent = '/dashboard/recent-contacts';
}
