import 'package:cifra_band/core/services/setlist_contacts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'contact DTO keeps the picker independent of ministries and private fields',
    () {
      final contacts = SetlistContactsService.parse({
        'contacts': [
          {'id': 'a', 'name': 'Same church'},
          {'id': 'b', 'name': 'Other church'},
        ],
      });
      expect(contacts.map((c) => c.id), ['a', 'b']);
      expect(contacts.map((c) => c.name), ['Same church', 'Other church']);
      expect(SetlistContactsService.parse({'contacts': []}), isEmpty);
    },
  );
  test(
    'bad contacts response is an explicit error, not a silently empty picker',
    () {
      for (final response in <Map<String, dynamic>>[
        {},
        {'contacts': null},
        {
          'contacts': [{}],
        },
        {
          'contacts': [
            {'id': '', 'name': 'Invalid'},
          ],
        },
      ]) {
        expect(
          () => SetlistContactsService.parse(response),
          throwsFormatException,
        );
      }
    },
  );
}
