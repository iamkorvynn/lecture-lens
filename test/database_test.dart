import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_lens/models/lecture.dart';
import 'package:lecture_lens/services/database_helper.dart';

import 'test_setup.dart';

void main() {
  setUpAll(setupTestDb);

  test('insert, list, search, update, and delete lectures', () async {
    final db = DatabaseHelper.instance;

    final id = await db.insertLecture(
      Lecture(
        title: 'Biology — Cell Division',
        createdAt: DateTime(2026, 11, 18, 10, 0),
        durationSeconds: 120,
        audioPath: '/tmp/no-such-file.m4a',
        transcript: 'Mitosis produces two identical cells.',
        notes: 'Revise meiosis too.',
      ),
    );
    expect(id, isNotNull);

    final all = await db.getLectures();
    expect(all.length, 1);
    expect(all.first.title, 'Biology — Cell Division');

    expect((await db.getLectures(query: 'mitosis')).length, 1);
    expect((await db.getLectures(query: 'photosynthesis')).length, 0);

    final updated = all.first.copyWith(
      summary: 'About cell division.',
      keyPoints: ['mitosis', 'meiosis'],
    );
    await db.updateLecture(updated);
    final reloaded = await db.getLecture(id);
    expect(reloaded?.summary, 'About cell division.');
    expect(reloaded?.keyPoints, ['mitosis', 'meiosis']);
    expect(reloaded?.notes, 'Revise meiosis too.');

    await db.deleteLecture(reloaded!);
    expect(await db.getLectures(), isEmpty);
  });

  test('flashcards are stored per lecture and removed with it', () async {
    final db = DatabaseHelper.instance;
    final id = await db.insertLecture(
      Lecture(
        title: 'Chemistry',
        createdAt: DateTime(2026, 11, 18, 11, 0),
        durationSeconds: 60,
        audioPath: '',
        transcript: 'Atoms bond.',
      ),
    );
    await db.replaceFlashcards(id, [
      Flashcard(lectureId: id, question: 'Q1?', answer: 'A1.'),
      Flashcard(lectureId: id, question: 'Q2?', answer: 'A2.'),
    ]);

    var cards = await db.getFlashcards(id);
    expect(cards.length, 2);
    await db.setFlashcardKnown(cards[0].id!, true);
    cards = await db.getFlashcards(id);
    expect(cards[0].known, isTrue);
    expect(cards[1].known, isFalse);

    final lecture = await db.getLecture(id);
    await db.deleteLecture(lecture!);
    expect(await db.getFlashcards(id), isEmpty);
  });

  test('settings round-trip stores the Gemini key on device only', () async {
    final db = DatabaseHelper.instance;
    expect(await db.getGeminiKey(), isNull);
    await db.setSetting(DatabaseHelper.settingGeminiKey, 'AIza-test-key');
    expect(await db.getGeminiKey(), 'AIza-test-key');
    await db.deleteSetting(DatabaseHelper.settingGeminiKey);
    expect(await db.getGeminiKey(), isNull);
  });
}
