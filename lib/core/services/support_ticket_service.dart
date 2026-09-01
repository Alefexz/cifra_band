import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.screen,
    required this.user,
    required this.app,
    required this.device,
  });

  final String id;
  final String type;
  final String severity;
  final String message;
  final String status;
  final DateTime? createdAt;
  final String? screen;
  final Map<String, dynamic> user;
  final Map<String, dynamic> app;
  final Map<String, dynamic> device;

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: '${json['id'] ?? ''}',
      type: '${json['type'] ?? 'bug'}',
      severity: '${json['severity'] ?? 'medium'}',
      message: '${json['message'] ?? ''}',
      status: '${json['status'] ?? 'open'}',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      screen: json['screen']?.toString(),
      user: _readMap(json['user']),
      app: _readMap(json['app']),
      device: _readMap(json['device']),
    );
  }

  String get typeLabel {
    return switch (type) {
      'wrong_chord' => 'Cifra errada',
      'question' => 'Dúvida',
      'suggestion' => 'Sugestão',
      _ => 'Bug',
    };
  }

  String get severityLabel {
    return switch (severity) {
      'critical' => 'Crítico',
      'high' => 'Alto',
      'low' => 'Baixo',
      _ => 'Médio',
    };
  }

  String get statusLabel {
    return switch (status) {
      'resolved' => 'Resolvido',
      'closed' => 'Fechado',
      _ => 'Aberto',
    };
  }

  String get userName {
    final name = '${user['name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    final email = '${user['email'] ?? ''}'.trim();
    if (email.isNotEmpty) return email;
    return 'Usuário';
  }

  String get deviceLabel {
    final manufacturer = '${device['manufacturer'] ?? ''}'.trim();
    final model = '${device['model'] ?? ''}'.trim();
    final android = '${device['release'] ?? ''}'.trim();
    final parts = [
      if (manufacturer.isNotEmpty) manufacturer,
      if (model.isNotEmpty) model,
      if (android.isNotEmpty) 'Android $android',
    ];
    return parts.isEmpty ? 'Aparelho não informado' : parts.join(' • ');
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const {};
  }
}

class SupportTicketService {
  SupportTicketService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Uri _baseUri = Uri.parse('https://cifraband-api.onrender.com');

  static Future<List<SupportTicket>> fetchTickets({
    String status = 'open',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Você precisa estar logado.');
    }

    final token = await user.getIdToken();
    final response = await http
        .get(
          _baseUri.replace(
            path: '/support-tickets',
            queryParameters: {'status': status, 'limit': '80'},
          ),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    final decoded = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(decoded, response.statusCode));
    }

    final rawTickets = decoded['tickets'];
    if (rawTickets is! List) return const [];

    return rawTickets
        .whereType<Map>()
        .map((item) => SupportTicket.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<void> updateTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Você precisa estar logado.');
    }

    final token = await user.getIdToken();
    final response = await http
        .patch(
          _baseUri.replace(path: '/support-tickets/$ticketId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw StateError(
        _errorMessage(_decodeBody(response.body), response.statusCode),
      );
    }
  }

  static Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  static String _errorMessage(Map<String, dynamic> body, int statusCode) {
    final message = '${body['message'] ?? ''}'.trim();
    if (message.isNotEmpty) return message;
    return 'API retornou HTTP $statusCode.';
  }
}
