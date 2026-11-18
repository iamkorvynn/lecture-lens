import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lecture.dart';

/// Calls the Gemini REST API with the user's own API key and the lecture
/// transcript, and parses the structured result.
///
/// The model is asked to reply with a single JSON object:
///   {"summary": "...", "key_points": ["...", ...],
///    "flashcards": [{"question": "...", "answer": "..."}, ...]}
///
/// No summary is ever invented locally: if there is no key, callers must
/// not call [generateSummary] at all, and the UI says so plainly.
class GeminiService {
  final http.Client _client;

  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  static const String _model = 'gemini-2.5-flash';

  /// Prompt sent to Gemini. Kept in one place so tests can assert on it.
  static String buildPrompt(String transcript) {
    return '''
You are a study assistant. The text below is a transcript of a lecture.
Summarise it for a student who wants to revise quickly.

Reply with ONLY a JSON object (no markdown fences, no extra text) with
exactly these keys:
- "summary": a short summary, 3-6 sentences, plain text.
- "key_points": a list of 4-8 short bullet strings with the most
  important ideas, definitions, or facts from the lecture.
- "flashcards": a list of 5-10 objects, each with "question" and
  "answer" keys, covering the core concepts a student should be able
  to recall. Questions should test understanding, not just repeat a
  sentence. Answers should be one or two sentences.

Transcript:
$transcript
''';
  }

  /// Sends [transcript] to Gemini with [apiKey] and returns the parsed
  /// [AiSummary]. Throws [GeminiException] on any failure so the UI can
  /// show the real error instead of a fake result.
  Future<AiSummary> generateSummary({
    required String apiKey,
    required String transcript,
    required int lectureId,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const GeminiException('No Gemini API key set.');
    }
    if (transcript.trim().isEmpty) {
      throw const GeminiException(
        'There is no transcript to summarise yet.',
      );
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=${Uri.encodeComponent(apiKey.trim())}',
    );
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': buildPrompt(transcript)},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.3},
    });

    http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      throw GeminiException('Could not reach Gemini: $e');
    }

    if (response.statusCode != 200) {
      throw GeminiException(_errorMessage(response));
    }

    try {
      return parseGeminiResponse(response.body, lectureId);
    } on GeminiException {
      rethrow;
    } catch (e) {
      throw GeminiException('Could not understand Gemini\'s reply: $e');
    }
  }

  /// Human-readable message for a non-200 Gemini response.
  static String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) {
            if (response.statusCode == 400) {
              return 'Gemini rejected the request: $message';
            }
            if (response.statusCode == 403) {
              return 'Gemini refused the key (403). Check the API key in Settings.';
            }
            return 'Gemini error (${response.statusCode}): $message';
          }
        }
      }
    } catch (_) {
      // Fall through to the generic message.
    }
    if (response.statusCode == 400) {
      return 'Gemini rejected the request (400). The key or transcript may be invalid.';
    }
    if (response.statusCode == 403) {
      return 'Gemini refused the key (403). Check the API key in Settings.';
    }
    if (response.statusCode == 429) {
      return 'Gemini rate limit reached (429). Try again in a little while.';
    }
    return 'Gemini returned HTTP ${response.statusCode}.';
  }

  /// Extracts the model's text from a raw Gemini `generateContent`
  /// response body and parses the JSON object inside it into an
  /// [AiSummary]. Pure function — unit tested.
  static AiSummary parseGeminiResponse(String responseBody, int lectureId) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const GeminiException('Unexpected Gemini response format.');
    }
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const GeminiException(
        'Gemini returned no answer. Try again.',
      );
    }
    final content = candidates.first['content'];
    final parts = content is Map<String, dynamic> ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) {
      throw const GeminiException('Gemini returned an empty answer.');
    }
    final text = parts.first['text'];
    if (text is! String || text.trim().isEmpty) {
      throw const GeminiException('Gemini returned an empty answer.');
    }
    return parseSummaryJson(text, lectureId);
  }

  /// Parses the JSON object the model was asked to produce. Tolerates
  /// ```json fences and surrounding prose. Missing keys become empty
  /// values rather than a crash; a completely unparseable body throws.
  static AiSummary parseSummaryJson(String text, int lectureId) {
    final jsonText = _extractJson(text);
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const GeminiException(
        'Gemini did not return a summary object.',
      );
    }

    final summary = decoded['summary'];
    final rawPoints = decoded['key_points'];
    final rawCards = decoded['flashcards'];

    final keyPoints = <String>[];
    if (rawPoints is List) {
      for (final point in rawPoints) {
        final s = point.toString().trim();
        if (s.isNotEmpty) keyPoints.add(s);
      }
    }

    final flashcards = <Flashcard>[];
    if (rawCards is List) {
      for (final raw in rawCards) {
        if (raw is Map<String, dynamic>) {
          final q = (raw['question'] ?? '').toString().trim();
          final a = (raw['answer'] ?? '').toString().trim();
          if (q.isNotEmpty && a.isNotEmpty) {
            flashcards.add(
              Flashcard(lectureId: lectureId, question: q, answer: a),
            );
          }
        }
      }
    }

    return AiSummary(
      summary: summary is String ? summary.trim() : '',
      keyPoints: keyPoints,
      flashcards: flashcards,
    );
  }

  /// Pulls the first {...} JSON object out of [text], stripping
  /// markdown code fences if present.
  static String _extractJson(String text) {
    var cleaned = text.trim();
    cleaned = cleaned.replaceAll('```json', '').replaceAll('```', '').trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return cleaned.substring(start, end + 1);
    }
    return cleaned;
  }
}

class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);

  @override
  String toString() => message;
}
