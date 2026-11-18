import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../models/lecture.dart';
import '../services/database_helper.dart';
import '../services/gemini_service.dart';
import 'flashcards_screen.dart';
import 'settings_screen.dart';

/// One lecture: audio playback, editable notes, full transcript, and an
/// AI summary (only when the user has entered their own Gemini key).
class LectureDetailScreen extends StatefulWidget {
  final int lectureId;

  const LectureDetailScreen({super.key, required this.lectureId});

  @override
  State<LectureDetailScreen> createState() => _LectureDetailScreenState();
}

class _LectureDetailScreenState extends State<LectureDetailScreen> {
  final _db = DatabaseHelper.instance;
  final _notesController = TextEditingController();
  final _player = AudioPlayer();

  Lecture? _lecture;
  List<Flashcard> _flashcards = [];
  bool _loading = true;
  bool _generating = false;
  bool _notesDirty = false;
  String? _audioError;
  String? _summaryError;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _duration = dur);
    });
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _playing = state.playing);
      }
    });
    _load();
  }

  Future<void> _load() async {
    final lecture = await _db.getLecture(widget.lectureId);
    final cards = await _db.getFlashcards(widget.lectureId);
    if (!mounted) return;
    setState(() {
      _lecture = lecture;
      _flashcards = cards;
      _loading = false;
      if (lecture != null) {
        _notesController.text = lecture.notes;
        _notesDirty = false;
      }
    });
    if (lecture != null && lecture.audioPath.isNotEmpty) {
      _initAudio(lecture.audioPath);
    }
  }

  Future<void> _initAudio(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) setState(() => _audioError = 'Audio file not found.');
      return;
    }
    try {
      await _player.setFilePath(path);
    } catch (_) {
      if (mounted) {
        setState(() => _audioError = 'Could not load the audio file.');
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final lecture = _lecture;
    if (lecture == null) return;
    final updated = lecture.copyWith(notes: _notesController.text);
    await _db.updateLecture(updated);
    if (!mounted) return;
    setState(() {
      _lecture = updated;
      _notesDirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notes saved')),
    );
  }

  Future<void> _generateSummary() async {
    final lecture = _lecture;
    if (lecture == null || _generating) return;
    final key = await _db.getGeminiKey();
    if (key == null || key.trim().isEmpty) {
      setState(
        () => _summaryError = 'Add your Gemini API key in Settings first.',
      );
      return;
    }
    if (lecture.transcript.trim().isEmpty) {
      setState(
        () => _summaryError =
            'There is no transcript to summarise for this lecture.',
      );
      return;
    }
    setState(() {
      _generating = true;
      _summaryError = null;
    });
    try {
      final result = await GeminiService().generateSummary(
        apiKey: key,
        transcript: lecture.transcript,
        lectureId: lecture.id!,
      );
      final updated = lecture.copyWith(
        summary: result.summary,
        keyPoints: result.keyPoints,
      );
      await _db.updateLecture(updated);
      await _db.replaceFlashcards(lecture.id!, result.flashcards);
      final cards = await _db.getFlashcards(lecture.id!);
      if (!mounted) return;
      setState(() {
        _lecture = updated;
        _flashcards = cards;
        _generating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Summary ready — ${result.flashcards.length} flashcards created.',
          ),
        ),
      );
    } on GeminiException catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _summaryError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _summaryError = 'Summary failed: $e';
      });
    }
  }

  Future<void> _togglePlay() async {
    if (_audioError != null) return;
    if (_playing) {
      await _player.pause();
    } else {
      if (_duration != Duration.zero &&
          _position >= _duration - const Duration(milliseconds: 500)) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final lecture = _lecture;
    return Scaffold(
      appBar: AppBar(
        title: Text(lecture?.title ?? 'Lecture'),
        actions: [
          if (_notesDirty)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save notes',
              onPressed: _saveNotes,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : lecture == null
              ? const Center(child: Text('Lecture not found.'))
              : DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      _AudioPlayerBar(
                        lecture: lecture,
                        playing: _playing,
                        position: _position,
                        duration: _duration,
                        error: _audioError,
                        format: _format,
                        onToggle: _togglePlay,
                        onSeek: (pos) => _player.seek(pos),
                      ),
                      const TabBar(
                        tabs: [
                          Tab(text: 'Notes'),
                          Tab(text: 'Transcript'),
                          Tab(text: 'Summary'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _NotesTab(
                              controller: _notesController,
                              onChanged: () {
                                if (!_notesDirty) {
                                  setState(() => _notesDirty = true);
                                }
                              },
                              onSave: _saveNotes,
                              dirty: _notesDirty,
                            ),
                            _TranscriptTab(transcript: lecture.transcript),
                            _SummaryTab(
                              lecture: lecture,
                              flashcards: _flashcards,
                              generating: _generating,
                              error: _summaryError,
                              onGenerate: _generateSummary,
                              onOpenFlashcards: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FlashcardsScreen(
                                      lectureId: lecture.id!,
                                      title: lecture.title,
                                    ),
                                  ),
                                );
                                _load();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _AudioPlayerBar extends StatelessWidget {
  final Lecture lecture;
  final bool playing;
  final Duration position;
  final Duration duration;
  final String? error;
  final String Function(Duration) format;
  final VoidCallback onToggle;
  final void Function(Duration) onSeek;

  const _AudioPlayerBar({
    required this.lecture,
    required this.playing,
    required this.position,
    required this.duration,
    required this.error,
    required this.format,
    required this.onToggle,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final maxMs = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : lecture.durationSeconds * 1000.0;
    final value = position.inMilliseconds
        .clamp(0, maxMs.toInt())
        .toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEE, d MMM yyyy • h:mm a').format(lecture.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filled(
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: error == null ? onToggle : null,
                tooltip: playing ? 'Pause' : 'Play recording',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: maxMs > 0 ? value : 0,
                  max: maxMs > 0 ? maxMs : 1,
                  onChanged: error == null
                      ? (v) => onSeek(Duration(milliseconds: v.toInt()))
                      : null,
                ),
              ),
              Text(
                '${format(position)} / ${format(duration == Duration.zero ? Duration(seconds: lecture.durationSeconds) : duration)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _NotesTab extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onSave;
  final bool dirty;

  const _NotesTab({
    required this.controller,
    required this.onChanged,
    required this.onSave,
    required this.dirty,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Your own notes — key ideas, questions to ask, things to look up…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: dirty ? onSave : null,
            icon: const Icon(Icons.save_outlined),
            label: Text(dirty ? 'Save notes' : 'Notes saved'),
          ),
        ],
      ),
    );
  }
}

class _TranscriptTab extends StatelessWidget {
  final String transcript;

  const _TranscriptTab({required this.transcript});

  @override
  Widget build(BuildContext context) {
    if (transcript.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No transcript was captured for this lecture.\n'
            'Live transcription needs the device speech recogniser '
            'and audible speech during recording. You can still use '
            'the Notes tab.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(transcript, style: const TextStyle(height: 1.5)),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final Lecture lecture;
  final List<Flashcard> flashcards;
  final bool generating;
  final String? error;
  final VoidCallback onGenerate;
  final VoidCallback onOpenFlashcards;

  const _SummaryTab({
    required this.lecture,
    required this.flashcards,
    required this.generating,
    required this.error,
    required this.onGenerate,
    required this.onOpenFlashcards,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: DatabaseHelper.instance.getGeminiKey(),
      builder: (context, snapshot) {
        final hasKey =
            snapshot.hasData && (snapshot.data?.trim().isNotEmpty ?? false);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!lecture.hasSummary) ...[
                if (!hasKey)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.key_outlined),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Add your Gemini API key in Settings to generate a summary',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Summaries are generated with your own Gemini '
                            'API key, stored only on this device. Without '
                            'a key, LectureLens will not invent a summary — '
                            'your transcript and manual notes are still '
                            'available below.',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Open Settings'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: generating ? null : onGenerate,
                    icon: generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      generating ? 'Generating summary…' : 'Generate summary',
                    ),
                  ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Your transcript and notes are available in the other tabs while no summary exists.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ] else ...[
                const Text(
                  'Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(lecture.summary!, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 20),
                const Text(
                  'Key points',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...lecture.keyPoints.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(point)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: flashcards.isEmpty
                            ? null
                            : onOpenFlashcards,
                        icon: const Icon(Icons.style_outlined),
                        label: Text(
                          flashcards.isEmpty
                              ? 'No flashcards yet'
                              : 'Study flashcards (${flashcards.length})',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: generating ? null : onGenerate,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    generating ? 'Regenerating…' : 'Regenerate summary',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
