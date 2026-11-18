# LectureLens

**Record a lecture. Read it back. Revise from it.**

LectureLens is a Flutter Android app that turns a spoken lecture into
study material. Record the class, get a live on-device transcript as you
go, replay the audio, write your own notes — and, with your own Gemini
API key, turn the transcript into a short summary, key points, and
flashcards you can flip through.

No accounts. No servers of ours. Everything is stored on your device.

## Features

- **Record lectures** — audio saved to the app documents folder
  (AAC `.m4a`), with a live timer.
- **Live on-device transcription** — your phone's own speech recogniser
  transcribes the lecture while you record, so the transcript exists
  even without a network connection. If the recogniser pauses, it
  restarts automatically for the rest of the lecture.
- **Lecture list** — search by title or transcript text, delete a
  lecture (its audio, transcript, summary, and flashcards go with it).
- **Audio playback** — play/pause and seek through the recording.
- **Manual notes** — your own editable notes per lecture, saved locally.
- **AI summary (your key, your choice)** — with a Gemini API key entered
  in Settings, generate a short summary, key points, and flashcards from
  the transcript. Without a key the app says so plainly and never
  invents a summary.
- **Flashcards** — tap to flip question/answer, mark each card known or
  unknown, with progress per lecture.
- **First-run onboarding** — three pages explaining record → transcript
  → summary.
- **Starts empty** — no sample lectures. Your data is yours.

## How the Gemini key works

LectureLens has no API key of its own and never ships one. To generate
summaries:

1. Open Google AI Studio at <https://aistudio.google.com> and create
   an API key (free tier available).
2. In LectureLens, go to **Settings → Gemini API key** and paste it.
3. The key is stored only in the app's local SQLite database on your
   device. It is never committed to this repo, never bundled in the app,
   and never sent anywhere except to Google's Gemini API
   (`generativelanguage.googleapis.com`, model `gemini-2.5-flash`) when
   you tap **Generate summary**. Only the transcript text is sent —
   never the audio file.
4. Remove the key any time from Settings; summaries simply turn off.

Without a key, recording, transcription, playback, notes, search, and
delete all work normally — the Summary tab just tells you to add a key.

## Tech

- Flutter 3.50 / Dart, Material 3, Android only
- `record` — microphone recording to file
- `speech_to_text` — live on-device speech recognition
- `just_audio` — audio playback
- `sqflite` — local SQLite storage (lectures, flashcards, settings)
- `http` — Gemini REST API calls
- `permission_handler` — runtime microphone permission
- `path_provider` — app documents directory

## Project structure

```
lib/
  main.dart                        App entry, onboarding gate
  models/lecture.dart              Lecture, Flashcard, AiSummary
  services/
    database_helper.dart           SQLite: lectures, flashcards, settings
    recording_service.dart         record + speech_to_text, live transcript
    transcript_accumulator.dart    Pure final/partial result handling
    gemini_service.dart            Gemini REST call + response parser
  screens/
    onboarding_screen.dart         First-run flow explainer
    home_screen.dart               Lecture list, search, delete
    record_screen.dart             Recording + live transcript
    lecture_detail_screen.dart     Playback, notes, transcript, summary
    flashcards_screen.dart         Flip cards, known/unknown
    settings_screen.dart           Gemini key, how-to, about
test/
  gemini_parser_test.dart          Gemini response parsing
  transcript_accumulator_test.dart Transcript accumulation
  models_test.dart                 Lecture / Flashcard models
  database_test.dart               SQLite CRUD (sqflite_common_ffi)
  widget_test.dart                 Onboarding + home screen
```

## Build & run

```bash
flutter pub get
flutter analyze        # must report no issues
flutter test           # must pass
flutter build apk --release
```

Requires a physical Android device or emulator with a microphone for
recording; transcription uses the device speech recogniser, so results
vary by device and language.

## Privacy

- Recordings, transcripts, notes, summaries, flashcards, and your
  Gemini API key live in local storage on the device.
- The only network call the app makes on your behalf is to Google's
  Gemini API, only when you tap **Generate summary** with a key set,
  and only the transcript text is sent.

## License

MIT — see [LICENSE](LICENSE).
