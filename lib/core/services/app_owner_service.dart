import 'package:firebase_auth/firebase_auth.dart';

class AppOwnerService {
  AppOwnerService._();

  static const String ownerEmail = 'alef08052006@gmail.com';

  static bool get isCurrentUserOwner {
    final email = FirebaseAuth.instance.currentUser?.email
        ?.toLowerCase()
        .trim();
    return email == ownerEmail;
  }
}
