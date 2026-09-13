import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class MemberActionsService {
  static Future<Map<String, dynamic>> send(
    String action,
    Map<String, dynamic> body,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Entre na sua conta para continuar.');
    final token = await user.getIdToken();
    final response = await http
        .post(
          Uri.https('cifraband-api.onrender.com', '/members/$action'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 35));
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      throw StateError(
        data is Map
            ? '${data['message'] ?? 'Tente novamente.'}'
            : 'Servidor indisponivel.',
      );
    }
    if (FirebaseAuth.instance.currentUser?.uid != user.uid)
      throw StateError('A conta foi alterada.');
    return data;
  }
}
