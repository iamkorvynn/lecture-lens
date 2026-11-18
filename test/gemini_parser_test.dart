import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_lens/services/gemini_service.dart';

const _sampleResponse = '''
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "{\\"summary\\": \\"Photosynthesis converts light energy into chemical energy in plants.\\", \\"key_points\\": [\\"Light reactions happen in the thylakoid\\", \\"The Calvin cycle fixes carbon\\"], \\"flashcards\\": [{\\"question\\": \\"Where do the light reactions happen?\\", \\"answer\\": \\"In the thylakoid membrane.\\"}, {\\"question\\": \\"What does the Calvin cycle fix?\\", \\"answer\\": \\"Carbon dioxide into sugars.\\"}]}"
          }
        ],
        "role": "model"
      },
      "finishReason": "STOP"
    }
  ]
}
''';

void main() {
  group('GeminiService.parseGeminiResponse', () {
    test('parses summary, key points, and flashcards from a response', () {
      final result = GeminiService.parseGeminiResponse(_sampleResponse, 42);

      expect(
        result.summary,
        'Photosynthesis converts light energy into chemical energy in plants.',
      );
      expect(result.keyPoints, [
        'Light reactions happen in the thylakoid',
        'The Calvin cycle fixes carbon',
      ]);
      expect(result.flashcards.length, 2);
      expect(
        result.flashcards[0].question,
        'Where do the light reactions happen?',
      );
      expect(result.flashcards[0].answer, 'In the thylakoid membrane.');
      expect(result.flashcards[0].lectureId, 42);
      expect(result.flashcards[0].known, isFalse);
    });

    test('parses a model reply wrapped in a ```json fence', () {
      const fenced = '''
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "```json\\n{\\"summary\\": \\"Fenced summary.\\", \\"key_points\\": [], \\"flashcards\\": []}\\n```"
          }
        ]
      }
    }
  ]
}
''';
      final result = GeminiService.parseGeminiResponse(fenced, 1);
      expect(result.summary, 'Fenced summary.');
      expect(result.keyPoints, isEmpty);
      expect(result.flashcards, isEmpty);
    });

    test('throws when there are no candidates', () {
      expect(
        () => GeminiService.parseGeminiResponse('{"candidates": []}', 1),
        throwsA(isA<GeminiException>()),
      );
    });

    test('throws on a completely invalid body', () {
      expect(
        () => GeminiService.parseGeminiResponse('not json at all', 1),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('GeminiService.parseSummaryJson', () {
    test('missing keys become empty values instead of crashing', () {
      final result = GeminiService.parseSummaryJson('{"summary": "Only this."}', 7);
      expect(result.summary, 'Only this.');
      expect(result.keyPoints, isEmpty);
      expect(result.flashcards, isEmpty);
    });

    test('skips flashcards with an empty question or answer', () {
      final result = GeminiService.parseSummaryJson(
        '{"summary": "s", "key_points": ["p"], "flashcards": ['
        '{"question": "", "answer": "a"}, '
        '{"question": "q", "answer": ""}, '
        '{"question": "Good?", "answer": "Good."}]}',
        3,
      );
      expect(result.flashcards.length, 1);
      expect(result.flashcards[0].question, 'Good?');
    });

    test('throws when the model text is not a JSON object', () {
      expect(
        () => GeminiService.parseSummaryJson('just some prose', 1),
        throwsA(isA<Exception>()),
      );
    });
  });

  test('buildPrompt includes the transcript and asks for JSON', () {
    final prompt = GeminiService.buildPrompt('mitochondria are the powerhouse');
    expect(prompt, contains('mitochondria are the powerhouse'));
    expect(prompt, contains('flashcards'));
    expect(prompt, contains('key_points'));
  });
}
