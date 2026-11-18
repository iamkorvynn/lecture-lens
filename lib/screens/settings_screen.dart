import 'package:material_ui/material_ui.dart';

import '../services/database_helper.dart';

/// Settings: the user's own Gemini API key (stored only on this device),
/// plus how the app works and how to get a key.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper.instance;
  final _keyController = TextEditingController();

  bool _loading = true;
  bool _keySaved = false;
  bool _obscured = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await _db.getGeminiKey();
    if (!mounted) return;
    setState(() {
      _keyController.text = key ?? '';
      _keySaved = key != null && key.trim().isNotEmpty;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    setState(() => _saving = true);
    if (key.isEmpty) {
      await _db.deleteSetting(DatabaseHelper.settingGeminiKey);
    } else {
      await _db.setSetting(DatabaseHelper.settingGeminiKey, key);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _keySaved = key.isNotEmpty;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          key.isEmpty
              ? 'Gemini API key removed. Summaries are now off.'
              : 'Gemini API key saved on this device.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Gemini API key',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'LectureLens uses Google Gemini to turn a transcript '
                    'into a summary, key points, and flashcards. The key is '
                    'yours: paste it below and it is stored only in this '
                    'phone\'s local database. It is never sent anywhere '
                    'except to Google\'s Gemini API when you tap '
                    '"Generate summary", and it is never included in any '
                    'backup of the app code. Without a key, the app still '
                    'records, transcribes, and stores your notes — it just '
                    'will not generate a summary.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _keyController,
                    obscureText: _obscured,
                    decoration: InputDecoration(
                      labelText: 'Gemini API key',
                      hintText: 'AIza…',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscured
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscured = !_obscured);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveKey,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _saving
                          ? 'Saving…'
                          : _keyController.text.trim().isEmpty
                              ? 'Remove key'
                              : 'Save key',
                    ),
                  ),
                  if (_keySaved) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text('A key is saved — summaries are enabled.'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'How to get a key',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Open Google AI Studio (aistudio.google.com) in a browser.\n'
                    '2. Sign in with a Google account and tap "Get API key".\n'
                    '3. Create a key, copy it, and paste it above.\n\n'
                    'Free-tier usage limits apply on Google\'s side. '
                    'LectureLens sends only the lecture transcript — never '
                    'your audio file — to Gemini.',
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'How LectureLens works',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Record: audio is saved on this device, and your '
                    'phone\'s own speech recogniser transcribes the lecture '
                    'live as you record.\n'
                    '• Revise: replay the audio, read the transcript, and '
                    'write your own notes.\n'
                    '• Summarise: with your Gemini key, generate a summary, '
                    'key points, and flashcards to study from.\n\n'
                    'All lectures, transcripts, notes, and flashcards live '
                    'in a local database on this device.',
                  ),
                ],
              ),
            ),
    );
  }
}
