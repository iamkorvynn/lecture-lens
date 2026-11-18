import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_lens/services/transcript_accumulator.dart';

void main() {
  group('TranscriptAccumulator', () {
    test('commits only final results to the transcript', () {
      final acc = TranscriptAccumulator();
      acc.addResult('hello', isFinal: false);
      expect(acc.transcript, isEmpty);
      expect(acc.displayText, 'hello');

      acc.addResult('hello world', isFinal: true);
      expect(acc.transcript, 'hello world');
      expect(acc.displayText, 'hello world');
      expect(acc.partial, isEmpty);
    });

    test('appends successive final phrases with a space', () {
      final acc = TranscriptAccumulator();
      acc.addResult('first phrase', isFinal: true);
      acc.addResult('second phrase', isFinal: true);
      expect(acc.transcript, 'first phrase second phrase');
    });

    test('shows the partial phrase after the committed transcript', () {
      final acc = TranscriptAccumulator();
      acc.addResult('committed', isFinal: true);
      acc.addResult('in pro', isFinal: false);
      expect(acc.displayText, 'committed in pro');
      expect(acc.transcript, 'committed');
    });

    test('does not duplicate a final phrase reported twice', () {
      final acc = TranscriptAccumulator();
      acc.addResult('same phrase', isFinal: true);
      acc.addResult('same phrase', isFinal: true);
      expect(acc.transcript, 'same phrase');
    });

    test('ignores empty results and clears cleanly', () {
      final acc = TranscriptAccumulator();
      acc.addResult('  ', isFinal: true);
      acc.addResult('', isFinal: false);
      expect(acc.transcript, isEmpty);
      acc.addResult('words', isFinal: true);
      acc.clear();
      expect(acc.transcript, isEmpty);
      expect(acc.displayText, isEmpty);
    });
  });
}
