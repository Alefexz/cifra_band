import 'package:firebase_auth/firebase_auth.dart';

class AppOwnerService {
  AppOwnerService._();

  static const Set<String> ownerEmails = {
    'alef08052006@gmail.com',
    'niotico2006@gmail.com',
    'niotio2006@gmail.com',
  };

  static bool get isCurrentUserOwner {
    final email = FirebaseAuth.instance.currentUser?.email
        ?.toLowerCase()
        .trim();
    return email != null && ownerEmails.contains(email);
  }
}
