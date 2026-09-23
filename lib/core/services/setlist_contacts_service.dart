import 'member_actions_service.dart';

class SetlistContact {
  const SetlistContact({required this.id, required this.name});
  final String id;
  final String name;
}

class SetlistContactsService {
  static Future<List<SetlistContact>> load() async {
    return parse(await MemberActionsService.send('contacts', {}));
  }

  static List<SetlistContact> parse(Map<String, dynamic> response) {
    final contacts = response['contacts'];
    if (contacts is! List) {
      throw const FormatException('Invalid contacts response.');
    }
    return contacts.map((contact) {
      if (contact is! Map ||
          contact['id'] is! String ||
          contact['name'] is! String ||
          (contact['id'] as String).isEmpty) {
        throw const FormatException('Invalid contact.');
      }
      return SetlistContact(
        id: contact['id'] as String,
        name: contact['name'] as String,
      );
    }).toList();
  }
}
