import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/contact_model.dart';
import 'package:frontend/models/dashboard_stats_model.dart';
import 'package:frontend/models/user_model.dart';

void main() {
  group('Flutter Model Serialization Tests', () {
    test('UserModel fromJson and toJson', () {
      final json = {
        'id': 'u123',
        'name': 'Sarah Connor',
        'email': 'sarah@resistance.org',
        'mobile': '+1555123456',
        'createdAt': '2026-11-24T10:00:00.000Z',
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 'u123');
      expect(user.name, 'Sarah Connor');
      expect(user.email, 'sarah@resistance.org');
      expect(user.mobile, '+1555123456');

      final serialized = user.toJson();
      expect(serialized['name'], 'Sarah Connor');
      expect(serialized['email'], 'sarah@resistance.org');
    });

    test('ContactModel fromJson, toJson and copyWith', () {
      final json = {
        '_id': 'c999',
        'personName': 'John Wick',
        'companyName': 'Continental Services',
        'designation': 'Executive Director',
        'phone': '+1999888777',
        'email': 'john@continental.com',
        'website': 'https://continental.com',
        'city': 'New York',
        'country': 'USA',
        'gstNumber': '',
      };

      final contact = ContactModel.fromJson(json);
      expect(contact.id, 'c999');
      expect(contact.personName, 'John Wick');
      expect(contact.companyName, 'Continental Services');

      final updated = contact.copyWith(phone: '+1000111222');
      expect(updated.phone, '+1000111222');
      expect(updated.personName, 'John Wick');

      final map = updated.toJson();
      expect(map['personName'], 'John Wick');
      expect(map['phone'], '+1000111222');
    });

    test('DashboardStatsModel initialization and parsing', () {
      final json = {
        'totalScannedCards': 15,
        'totalContacts': 12,
        'totalCompanies': 8,
        'recentContactsCount': 4,
      };

      final stats = DashboardStatsModel.fromJson(json);
      expect(stats.totalScannedCards, 15);
      expect(stats.totalContacts, 12);
      expect(stats.totalCompanies, 8);
      expect(stats.recentContactsCount, 4);
    });
  });
}
