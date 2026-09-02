import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'app_diagnostics_service.dart';

class SupportMessage {
  const SupportMessage({
    required this.sender,
    required this.kind,
    required this.message,
    required this.createdAt,
    required this.name,
  });

  final String sender;
  final String kind;
  final String message;
  final DateTime? createdAt;
  final String name;

  bool get isAdmin => sender == 'admin';

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      sender: '${json['sender'] ?? 'system'}',
      kind: '${json['kind'] ?? 'message'}',
      message: '${json['message'] ?? ''}'.trim(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      name: '${json['name'] ?? ''}'.trim(),
    );
  }
}

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
    required this.adminReply,
    required this.messages,
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
  final Map<String, dynamic> adminReply;
  final List<SupportMessage> messages;

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final adminReply = _readMap(json['admin_reply']);
    final rawMessages = json['messages'];
    final parsedMessages = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map(
                (item) =>
                    SupportMessage.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.message.isNotEmpty)
              .toList()
        : <SupportMessage>[];

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
      adminReply: adminReply,
      messages: _withLegacyMessages(
        parsedMessages,
        message: '${json['message'] ?? ''}',
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
        adminReply: adminReply,
      ),
    );
  }

  bool get hasAdminReply {
    return '${adminReply['message'] ?? ''}'.trim().isNotEmpty;
  }

  String get adminReplyMessage {
    return '${adminReply['message'] ?? ''}'.trim();
  }

  String get typeLabel {
    return switch (type) {
      'wrong_chord' => 'Cifra errada',
      'notification' => 'Notificação',
      'update' => 'Atualização',
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
    if (status == 'open' && hasAdminReply) return 'Respondido';
    if (status == 'open') return 'Aguardando suporte';

    return switch (status) {
      'resolved' => 'Resolvido',
      'closed' => 'Fechado',
      _ => 'Aguardando suporte',
    };
  }

  bool get canUserResolve {
    return hasAdminReply && status != 'closed';
  }

  bool get canUserReopen {
    return status == 'resolved' || status == 'closed';
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

  static List<SupportMessage> _withLegacyMessages(
    List<SupportMessage> messages, {
    required String message,
    required DateTime? createdAt,
    required Map<String, dynamic> adminReply,
  }) {
    if (messages.isNotEmpty) return messages;

    final result = <SupportMessage>[
      SupportMessage(
        sender: 'user',
        kind: 'feedback',
        message: message.trim(),
        createdAt: createdAt,
        name: '',
      ),
    ];

    final adminReplyMessage = '${adminReply['message'] ?? ''}'.trim();
    if (adminReplyMessage.isNotEmpty) {
      result.add(
        SupportMessage(
          sender: 'admin',
          kind: 'admin_reply',
          message: adminReplyMessage,
          createdAt: DateTime.tryParse('${adminReply['created_at'] ?? ''}'),
          name: '${adminReply['responder_name'] ?? 'Suporte Cifra Band'}',
        ),
      );
    }

    return result;
  }
}

class MySupportTicketsResult {
  const MySupportTicketsResult({
    required this.tickets,
    required this.canCreateNew,
  });

  final List<SupportTicket> tickets;
  final bool canCreateNew;
}

class SupportTicketService {
  SupportTicketService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Uri _baseUri = Uri.parse('https://cifraband-api.onrender.com');

  static Future<List<SupportTicket>> fetchTickets({
    String status = 'open',
    String type = 'all',
    String severity = 'all',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Você precisa estar logado.');
    }

    final token = await user.getIdToken();
    AppDiagnosticsService.log(
      'Carregando tickets de suporte admin',
      context: {'status': status, 'type': type, 'severity': severity},
    );
    final response = await http
        .get(
          _baseUri.replace(
            path: '/support-tickets',
            queryParameters: {
              'status': status,
              'type': type,
              'severity': severity,
              'limit': '100',
            },
          ),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    final decoded = _decodeBody(response.body);
    if (response.statusCode != 200) {
      AppDiagnosticsService.log(
        'Falha HTTP ao carregar tickets admin',
        level: 'error',
        context: {'statusCode': response.statusCode, 'body': response.body},
      );
      throw StateError(_errorMessage(decoded, response.statusCode));
    }

    final rawTickets = decoded['tickets'];
    if (rawTickets is! List) return const [];

    return rawTickets
        .whereType<Map>()
        .map((item) => SupportTicket.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<MySupportTicketsResult> fetchMyTickets() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Você precisa estar logado.');
    }

    final token = await user.getIdToken();
    AppDiagnosticsService.log('Carregando meus tickets de suporte');
    final response = await http
        .get(
          _baseUri.replace(path: '/my-support-tickets'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    final decoded = _decodeBody(response.body);
    if (response.statusCode != 200) {
      AppDiagnosticsService.log(
        'Falha HTTP ao carregar meus tickets',
        level: 'error',
        context: {'statusCode': response.statusCode, 'body': response.body},
      );
      throw StateError(_errorMessage(decoded, response.statusCode));
    }

    final rawTickets = decoded['tickets'];
    final tickets = rawTickets is List
        ? rawTickets
              .whereType<Map>()
              .map(
                (item) =>
                    SupportTicket.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <SupportTicket>[];

    return MySupportTicketsResult(
      tickets: tickets,
      canCreateNew: decoded['canCreateNew'] != false,
    );
  }

  static Future<void> updateTicketStatus({
    required String ticketId,
    required String status,
    String? reply,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Você precisa estar logado.');
    }

    final token = await user.getIdToken();
    AppDiagnosticsService.log(
      'Atualizando ticket admin',
      context: {'ticketId': ticketId, 'status': status},
    );
    final response = await http
        .patch(
          _baseUri.replace(path: '/support-tickets/$ticketId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'status': status, 'reply': reply?.trim()}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      AppDiagnosticsService.log(
        'Falha HTTP ao atualizar ticket admin',
        level: 'error',
        context: {'statusCode': response.statusCode, 'body': response.body},
      );
      throw StateError(
        _errorMessage(_decodeBody(response.body), response.statusCode),
      );
    }
  }

  static Future<void> updateMyTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Você precisa estar logado.');
    }

    final token = await user.getIdToken();
    AppDiagnosticsService.log(
      'Atualizando meu ticket',
      context: {'ticketId': ticketId, 'status': status},
    );
    final response = await http
        .patch(
          _baseUri.replace(path: '/my-support-tickets/$ticketId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      AppDiagnosticsService.log(
        'Falha HTTP ao atualizar meu ticket',
        level: 'error',
        context: {'statusCode': response.statusCode, 'body': response.body},
      );
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
