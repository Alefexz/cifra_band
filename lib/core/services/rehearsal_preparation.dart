import 'dart:convert';

import 'package:crypto/crypto.dart';

enum PreparationStage { pending, studying, ready, needsHelp, needsReview }

extension PreparationLabel on PreparationStage {
  String get label => switch (this) {
    PreparationStage.pending => 'Ainda não estudei',
    PreparationStage.studying => 'Estudando',
    PreparationStage.ready => 'Preparado',
    PreparationStage.needsHelp => 'Preciso de ajuda',
    PreparationStage.needsReview => 'Revisar arranjo',
  };
}

class RehearsalPreparation {
  const RehearsalPreparation({
    this.stage = PreparationStage.pending,
    this.note = '',
    this.revision = '',
  });

  final PreparationStage stage;
  final String note;
  final String revision;

  factory RehearsalPreparation.fromMap(Map<String, dynamic>? data) {
    final raw = data?['preparation'];
    final stage = switch (raw) {
      'pending' => PreparationStage.pending,
      'studying' => PreparationStage.studying,
      'ready' => PreparationStage.ready,
      'needsHelp' => PreparationStage.needsHelp,
      _ =>
        data?['rehearsed'] == true
            ? PreparationStage.ready
            : PreparationStage.pending,
    };
    return RehearsalPreparation(
      stage: stage,
      note: data?['note']?.toString() ?? '',
      revision: data?['arrangementRevision']?.toString() ?? '',
    );
  }

  PreparationStage forSong(Map<String, dynamic> song) {
    if (stage == PreparationStage.pending) return stage;
    return revision == revisionOf(song) ? stage : PreparationStage.needsReview;
  }

  // Only musical changes invalidate preparation, not votes or display order.
  static String revisionOf(Map<String, dynamic> song) {
    final fields = [
      'title',
      'artist',
      'originalKey',
      'key',
      'shapeKey',
      'capo',
      'bpm',
      'content',
      'referenceUrl',
      'rehearsalNotes',
    ];
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              for (final field in fields) song[field]?.toString().trim() ?? '',
            ]),
          ),
        )
        .toString();
  }
}

class RehearsalMember {
  const RehearsalMember(this.uid, this.name, this.roles);
  final String uid;
  final String name;
  final List<String> roles;

  static List<RehearsalMember> fromAssignments(List<dynamic> assignments) {
    final names = <String, String>{};
    final roles = <String, Set<String>>{};
    for (final entry in assignments.whereType<Map>()) {
      final uid = entry['uid']?.toString() ?? '';
      if (uid.isEmpty || entry['status'] == 'declined') continue;
      names[uid] = entry['name']?.toString() ?? 'Integrante';
      roles.putIfAbsent(uid, () => {});
      final role = entry['role']?.toString() ?? '';
      if (role.isNotEmpty) roles[uid]!.add(role);
    }
    return [
      for (final uid in names.keys)
        RehearsalMember(uid, names[uid]!, roles[uid]!.toList()),
    ];
  }
}
