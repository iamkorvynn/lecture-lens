import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_lens/models/lecture.dart';

void main() {
  group('Lecture', () {
    test('durationLabel formats minutes and seconds', () {
      final lecture = Lecture(
        title: 'T',
        createdAt: _epoch,
        durationSeconds: 754,
        audioPath: '/tmp/a.m4a',
        transcript: '',
      );
      expect(lecture.durationLabel, '12:34');
    });

    test('durationLabel pads single digits', () {
      final lecture = Lecture(
        title: 'T',
        createdAt: _epoch,
        durationSeconds: 65,
        audioPath: '',
        transcript: '',
      );
      expect(lecture.durationLabel, '01:05');
    });

    test('transcriptPreview truncates long transcripts', () {
      final lecture = Lecture(
        title: 'T',
        createdAt: _epoch,
        durationSeconds: 0,
        audioPath: '',
        transcript: 'word ' * 40,
      );
      expect(lecture.transcriptPreview.length, 121);
      expect(lecture.transcriptPreview.endsWith('…'), isTrue);
    });

    test('transcriptPreview reports an empty transcript honestly', () {
      final lecture = Lecture(
        title: 'T',
        createdAt: _epoch,
        durationSeconds: 0,
        audioPath: '',
        transcript: '',
      );
      expect(lecture.transcriptPreview, 'No transcript captured yet.');
    });

    test('hasSummary is false without a summary', () {
      final lecture = Lecture(
        title: 'T',
        createdAt: _epoch,
        durationSeconds: 0,
        audioPath: '',
        transcript: 'x',
      );
      expect(lecture.hasSummary, isFalse);
      expect(lecture.copyWith(summary: 'done').hasSummary, isTrue);
    });

    test('toMap/fromMap round-trip preserves fields', () {
      final lecture = Lecture(
        id: 5,
        title: 'Biology',
        createdAt: _epoch,
        durationSeconds: 90,
        audioPath: '/tmp/b.m4a',
        transcript: 'cells divide',
        notes: 'ask about mitosis',
        summary: 'About cells.',
        keyPoints: ['mitosis', 'meiosis'],
      );
      final restored = Lecture.fromMap(lecture.toMap());
      expect(restored.id, 5);
      expect(restored.title, 'Biology');
      expect(restored.durationSeconds, 90);
      expect(restored.transcript, 'cells divide');
      expect(restored.notes, 'ask about mitosis');
      expect(restored.summary, 'About cells.');
      expect(restored.keyPoints, ['mitosis', 'meiosis']);
    });
  });

  group('Flashcard', () {
    test('starts unknown and can be marked known', () {
      const card = Flashcard(
        lectureId: 1,
        question: 'Q?',
        answer: 'A.',
      );
      expect(card.known, isFalse);
      expect(card.copyWith(known: true).known, isTrue);
    });

    test('toMap/fromMap round-trip preserves known state', () {
      const card = Flashcard(
        id: 9,
        lectureId: 2,
        question: 'Q?',
        answer: 'A.',
        known: true,
      );
      final restored = Flashcard.fromMap(card.toMap());
      expect(restored.id, 9);
      expect(restored.lectureId, 2);
      expect(restored.known, isTrue);
    });
  });
}

final _epoch = DateTime(1970);
