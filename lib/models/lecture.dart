import 'dart:convert';

/// A single recorded lecture and everything derived from it.
class Lecture {
  final int? id;
  final String title;
  final DateTime createdAt;
  final int durationSeconds;
  final String audioPath;
  final String transcript;
  final String notes;
  final String? summary;
  final List<String> keyPoints;

  const Lecture({
    this.id,
    required this.title,
    required this.createdAt,
    required this.durationSeconds,
    required this.audioPath,
    required this.transcript,
    this.notes = '',
    this.summary,
    this.keyPoints = const [],
  });

  Lecture copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    int? durationSeconds,
    String? audioPath,
    String? transcript,
    String? notes,
    String? summary,
    List<String>? keyPoints,
  }) {
    return Lecture(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      audioPath: audioPath ?? this.audioPath,
      transcript: transcript ?? this.transcript,
      notes: notes ?? this.notes,
      summary: summary ?? this.summary,
      keyPoints: keyPoints ?? this.keyPoints,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
      'duration_seconds': durationSeconds,
      'audio_path': audioPath,
      'transcript': transcript,
      'notes': notes,
      'summary': summary,
      'key_points': jsonEncode(keyPoints),
    };
  }

  factory Lecture.fromMap(Map<String, Object?> map) {
    final rawPoints = map['key_points'] as String? ?? '[]';
    List<String> points = [];
    try {
      final decoded = jsonDecode(rawPoints);
      if (decoded is List) {
        points = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      points = [];
    }
    return Lecture(
      id: map['id'] as int?,
      title: map['title'] as String? ?? 'Untitled lecture',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? 0,
      ),
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      audioPath: map['audio_path'] as String? ?? '',
      transcript: map['transcript'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      summary: map['summary'] as String?,
      keyPoints: points,
    );
  }

  /// "12:34" style duration label.
  String get durationLabel {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Short preview of the transcript for list rows.
  String get transcriptPreview {
    final t = transcript.trim();
    if (t.isEmpty) return 'No transcript captured yet.';
    return t.length > 120 ? '${t.substring(0, 120)}…' : t;
  }

  bool get hasSummary => summary != null && summary!.trim().isNotEmpty;
}

/// One flashcard generated from a lecture transcript.
class Flashcard {
  final int? id;
  final int lectureId;
  final String question;
  final String answer;
  final bool known;

  const Flashcard({
    this.id,
    required this.lectureId,
    required this.question,
    required this.answer,
    this.known = false,
  });

  Flashcard copyWith({int? id, bool? known}) {
    return Flashcard(
      id: id ?? this.id,
      lectureId: lectureId,
      question: question,
      answer: answer,
      known: known ?? this.known,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'lecture_id': lectureId,
      'question': question,
      'answer': answer,
      'known': known ? 1 : 0,
    };
  }

  factory Flashcard.fromMap(Map<String, Object?> map) {
    return Flashcard(
      id: map['id'] as int?,
      lectureId: map['lecture_id'] as int? ?? 0,
      question: map['question'] as String? ?? '',
      answer: map['answer'] as String? ?? '',
      known: (map['known'] as int? ?? 0) == 1,
    );
  }
}

/// The structured result of a Gemini summarisation: summary + key points +
/// flashcards. Produced only when the user has entered their own API key.
class AiSummary {
  final String summary;
  final List<String> keyPoints;
  final List<Flashcard> flashcards;

  const AiSummary({
    required this.summary,
    required this.keyPoints,
    required this.flashcards,
  });
}
