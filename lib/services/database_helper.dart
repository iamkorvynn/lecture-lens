import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/lecture.dart';

/// Local SQLite storage. Everything lives on the device: lectures,
/// flashcards, and the user's own Gemini API key (settings table).
/// Nothing is ever uploaded anywhere except the transcript the user
/// explicitly sends to Gemini when they tap "Generate summary".
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'lecture_lens.db';
  static const _dbVersion = 1;

  static const String settingGeminiKey = 'gemini_api_key';
  static const String settingOnboardingDone = 'onboarding_done';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE lectures(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        audio_path TEXT NOT NULL,
        transcript TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        summary TEXT,
        key_points TEXT NOT NULL DEFAULT '[]'
      )
    ''');
    await db.execute('''
      CREATE TABLE flashcards(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lecture_id INTEGER NOT NULL,
        question TEXT NOT NULL,
        answer TEXT NOT NULL,
        known INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (lecture_id) REFERENCES lectures(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ---- Lectures ----

  Future<int> insertLecture(Lecture lecture) async {
    final db = await database;
    return db.insert('lectures', lecture.toMap());
  }

  Future<List<Lecture>> getLectures({String query = ''}) async {
    final db = await database;
    final rows = await db.query(
      'lectures',
      where: query.isEmpty ? null : 'title LIKE ? OR transcript LIKE ?',
      whereArgs: query.isEmpty
          ? null
          : ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
    return rows.map(Lecture.fromMap).toList();
  }

  Future<Lecture?> getLecture(int id) async {
    final db = await database;
    final rows = await db.query(
      'lectures',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Lecture.fromMap(rows.first);
  }

  Future<int> updateLecture(Lecture lecture) async {
    final db = await database;
    return db.update(
      'lectures',
      lecture.toMap(),
      where: 'id = ?',
      whereArgs: [lecture.id],
    );
  }

  Future<void> deleteLecture(Lecture lecture) async {
    final db = await database;
    await db.delete(
      'flashcards',
      where: 'lecture_id = ?',
      whereArgs: [lecture.id],
    );
    await db.delete('lectures', where: 'id = ?', whereArgs: [lecture.id]);
    if (lecture.audioPath.isNotEmpty) {
      try {
        final file = File(lecture.audioPath);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Audio file already gone — nothing to clean up.
      }
    }
  }

  // ---- Flashcards ----

  Future<List<Flashcard>> getFlashcards(int lectureId) async {
    final db = await database;
    final rows = await db.query(
      'flashcards',
      where: 'lecture_id = ?',
      whereArgs: [lectureId],
      orderBy: 'id ASC',
    );
    return rows.map(Flashcard.fromMap).toList();
  }

  Future<void> replaceFlashcards(
    int lectureId,
    List<Flashcard> cards,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'flashcards',
        where: 'lecture_id = ?',
        whereArgs: [lectureId],
      );
      for (final card in cards) {
        await txn.insert('flashcards', card.toMap());
      }
    });
  }

  Future<void> setFlashcardKnown(int id, bool known) async {
    final db = await database;
    await db.update(
      'flashcards',
      {'known': known ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---- Settings (Gemini key, onboarding flag) ----

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  Future<String?> getGeminiKey() => getSetting(settingGeminiKey);

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
