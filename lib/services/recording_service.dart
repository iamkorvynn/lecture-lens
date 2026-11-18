import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'transcript_accumulator.dart';

/// Owns the microphone: audio recording to a file (via `record`) and,
/// in parallel, live on-device speech recognition (via `speech_to_text`)
/// so a transcript is captured even on a normal phone with no server.
///
/// The recogniser on Android stops listening after a pause, so when it
/// reports itself done while a recording is still running, listening is
/// restarted automatically.
class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final SpeechToText _speech = SpeechToText();
  final TranscriptAccumulator accumulator = TranscriptAccumulator();

  bool _recording = false;
  bool _listening = false;
  String? _audioPath;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  void Function(String displayText)? onTranscript;
  void Function(int elapsedSeconds)? onElapsed;
  void Function(String message)? onError;

  bool get isRecording => _recording;
  int get elapsedSeconds => _elapsedSeconds;
  String get transcript => accumulator.transcript;
  String? get audioPath => _audioPath;

  /// Requests microphone permission, then starts audio recording and
  /// live transcription. Returns false (and reports via [onError]) when
  /// permission is denied or the recorder cannot start.
  Future<bool> start() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      onError?.call(
        'Microphone permission is needed to record a lecture. '
        'Allow it in your phone settings and try again.',
      );
      return false;
    }

    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${dir.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    _audioPath =
        p.join(recordingsDir.path, 'lecture_${DateTime.now().millisecondsSinceEpoch}.m4a');

    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _audioPath!,
      );
    } catch (e) {
      onError?.call('Could not start recording: $e');
      return false;
    }

    accumulator.clear();
    _elapsedSeconds = 0;
    _recording = true;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      onElapsed?.call(_elapsedSeconds);
    });

    await _startListening();
    return true;
  }

  Future<void> _startListening() async {
    if (!_recording) return;
    bool available = false;
    try {
      available = await _speech.initialize(
        onError: (_) {},
        onStatus: (status) {
          // Android stops the recogniser after a pause; restart it so
          // the transcript keeps flowing for the whole lecture.
          if (_recording && !_speech.isListening && status == 'done') {
            _listening = false;
            unawaited(_startListening());
          }
        },
      );
    } catch (_) {
      available = false;
    }
    if (!available) {
      onError?.call(
        'Live transcription is not available on this device. '
        'Audio is still being recorded — you can add notes manually.',
      );
      return;
    }
    _listening = true;
    try {
      await _speech.listen(
        onResult: (result) {
          accumulator.addResult(
            result.recognizedWords,
            isFinal: result.finalResult,
          );
          onTranscript?.call(accumulator.displayText);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          pauseFor: const Duration(seconds: 10),
          listenFor: const Duration(hours: 3),
        ),
      );
    } catch (_) {
      _listening = false;
    }
  }

  /// Stops recording and transcription. Returns the saved audio path,
  /// or null if nothing was recorded.
  Future<String?> stop() async {
    _recording = false;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    if (_listening) {
      try {
        await _speech.stop();
      } catch (_) {
        // Recogniser already stopped.
      }
      _listening = false;
    }
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = _audioPath;
    }
    return path ?? _audioPath;
  }

  Future<void> dispose() async {
    _elapsedTimer?.cancel();
    try {
      await _speech.cancel();
    } catch (_) {}
    try {
      await _recorder.dispose();
    } catch (_) {}
  }
}
