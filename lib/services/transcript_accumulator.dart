/// Pure helper that turns the stream of speech-recognition results into
/// one growing transcript.
///
/// The platform recogniser reports partial results while the speaker is
/// talking and a final result when a phrase is complete. Only final
/// results are committed to the transcript; the latest partial result is
/// kept separately as a live preview. Kept free of any plugin so it can
/// be unit tested.
class TranscriptAccumulator {
  final StringBuffer _final = StringBuffer();
  String _partial = '';

  /// Feed one recognition result. [words] is the recognised text,
  /// [isFinal] is true when the recogniser has finished this phrase.
  void addResult(String words, {required bool isFinal}) {
    final clean = words.trim();
    if (isFinal) {
      if (clean.isNotEmpty) {
        final current = _final.toString();
        // Guard against the recogniser re-reporting the same final phrase.
        if (!current.endsWith(clean)) {
          if (current.isNotEmpty) _final.write(' ');
          _final.write(clean);
        }
      }
      _partial = '';
    } else {
      _partial = clean;
    }
  }

  /// The committed transcript (final results only).
  String get transcript => _final.toString().trim();

  /// What the user should see live: transcript plus the in-progress phrase.
  String get displayText {
    final base = transcript;
    if (_partial.isEmpty) return base;
    if (base.isEmpty) return _partial;
    return '$base $_partial';
  }

  /// The in-progress phrase, empty when the recogniser is between phrases.
  String get partial => _partial;

  void clear() {
    _final.clear();
    _partial = '';
  }
}
