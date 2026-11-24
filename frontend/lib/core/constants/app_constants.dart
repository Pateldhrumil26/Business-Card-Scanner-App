class AppConstants {
  static const String appName = 'CardScanner Pro';
  static const String appTagline = 'Smart Business Card Scanner & Contact CRM';

  // Storage Keys
  static const String tokenKey = 'cardscanner_jwt_token';
  static const String userKey = 'cardscanner_user_data';
  static const String baseUrlKey = 'cardscanner_custom_base_url';

  // Default Network URLs
  // 10.0.2.2 maps to host machine in Android Emulator
  static const String defaultEmulatorBaseUrl = 'http://10.0.2.2:8080/api';
  static const String defaultLocalhostBaseUrl = 'http://localhost:8080/api';

  // Network Timeouts
  static const int connectTimeoutSeconds = 20;
  static const int receiveTimeoutSeconds = 25;
}
