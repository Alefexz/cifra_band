import 'package:firebase_auth/firebase_auth.dart';

class AppOwnerService {
  AppOwnerService._();

  static const String ownerEmail = 'alef08052006@gmail.com';
  static const String ownerUid = 'lMMSvaliRoZQ3C0ceHBOWUVor2g2';

  static bool get isCurrentUserOwner {
    return FirebaseAuth.instance.currentUser?.uid == ownerUid;
  }
}
