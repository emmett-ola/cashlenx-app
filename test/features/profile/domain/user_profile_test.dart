import 'package:cashlenx/features/profile/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses and copies extended profile fields', () {
    final profile = UserProfile.fromResponse({
      'data': {
        'id': 'user-1',
        'username': 'alice',
        'role': 'user',
        'phone_number': '+65 6123 4567',
        'location': 'Singapore',
        'birth_date': '1992-08-21',
      },
    });

    expect(profile.phoneNumber, '+65 6123 4567');
    expect(profile.location, 'Singapore');
    expect(profile.birthDate, '1992-08-21');

    final updated = profile.copyWith(location: 'Tampines');
    expect(updated.location, 'Tampines');
    expect(updated.phoneNumber, profile.phoneNumber);
  });
}
