import 'package:material_ui/material_ui.dart';

import '../models/lecture.dart';
import '../services/database_helper.dart';
import '../services/recording_service.dart';

/// Recording screen: big mic button, running timer, and the live
/// transcript as it is recognised. Stop → name the lecture → save.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _service = RecordingService();
  final _titleController = TextEditingController();
  final _scrollController = ScrollController();

  bool _starting = true;
  bool _recording = false;
  bool _saving = false;
  int _elapsed = 0;
  String _liveText = '';
  String? _startError;

  @override
  void initState() {
    super.initState();
    _service.onTranscript = (text) {
      if (!mounted) return;
      setState(() => _liveText = text);
      _scrollToBottom();
    };
    _service.onElapsed = (seconds) {
      if (!mounted) return;
      setState(() => _elapsed = seconds);
    };
    _service.onError = (message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    };
    _begin();
  }

  Future<void> _begin() async {
    final ok = await _service.start();
    if (!mounted) return;
    setState(() {
      _starting = false;
      _recording = ok;
      if (!ok) _startError = 'Recording could not start.';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _scrollController.dispose();
    if (_recording) {
      // Leave the recorder running state clean if the user backs out.
      _service.stop();
    }
    _service.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  String _elapsedLabel() {
    final h = _elapsed ~/ 3600;
    final m = (_elapsed % 3600) ~/ 60;
    final s = _elapsed % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _stopAndSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the lecture a title first.')),
      );
      return;
    }
    setState(() => _saving = true);
    final audioPath = await _service.stop();
    final transcript = _service.transcript;
    final lecture = Lecture(
      title: title,
      createdAt: DateTime.now(),
      durationSeconds: _elapsed,
      audioPath: audioPath ?? '',
      transcript: transcript,
    );
    await DatabaseHelper.instance.insertLecture(lecture);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _recording = false;
    });
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          transcript.isEmpty
              ? '"$title" saved. No speech was recognised — you can still add notes.'
              : '"$title" saved with transcript.',
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!_recording) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop recording?'),
        content: const Text(
          'The recording so far will be discarded if you leave now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep recording'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_recording,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard()) {
          await _service.stop();
          if (context.mounted) Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Record lecture')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Lecture title',
                  hintText: 'e.g. Biology — Cell Division',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Icon(
                      _recording ? Icons.mic : Icons.mic_off,
                      size: 56,
                      color: _recording
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _starting
                          ? 'Starting…'
                          : _recording
                              ? _elapsedLabel()
                              : _startError ?? 'Not recording',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _recording
                          ? 'Recording • transcribing live on this device'
                          : 'Check microphone permission and try again',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Live transcript',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_recording)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Text(
                      _liveText.isEmpty
                          ? 'Start speaking — the transcript will appear here as the lecture goes on.'
                          : _liveText,
                      style: TextStyle(
                        color: _liveText.isEmpty
                            ? Theme.of(context).colorScheme.outline
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _recording && !_saving ? _stopAndSave : null,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.stop),
                label: Text(_saving ? 'Saving…' : 'Stop & save lecture'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
