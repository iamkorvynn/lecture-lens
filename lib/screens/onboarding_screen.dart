import 'package:material_ui/material_ui.dart';

import '../services/database_helper.dart';
import 'home_screen.dart';

/// First-run onboarding: three pages explaining record → transcript →
/// summary. Shown once; the choice is stored in the local settings table.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.mic,
      title: 'Record the lecture',
      body:
          'Tap "Record lecture" and LectureLens captures the audio on your '
          'phone. While you record, your phone\'s own speech recogniser '
          'transcribes the lecture live — no server, no upload.',
    ),
    _OnboardingPage(
      icon: Icons.notes_outlined,
      title: 'Read it back, add your notes',
      body:
          'After class, replay the audio, read the full transcript, and '
          'write your own notes alongside it. Everything is stored on '
          'this device, in a local database.',
    ),
    _OnboardingPage(
      icon: Icons.auto_awesome,
      title: 'Summarise with your own Gemini key',
      body:
          'Paste your Gemini API key in Settings and LectureLens turns '
          'the transcript into a short summary, key points, and '
          'flashcards you can flip through. No key, no summary — the app '
          'never fakes one.',
    ),
  ];

  Future<void> _finish() async {
    await DatabaseHelper.instance.setSetting(
      DatabaseHelper.settingOnboardingDone,
      'true',
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _pages[i],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FilledButton(
                onPressed: last
                    ? _finish
                    : () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    last ? 'Start recording' : 'Next',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 96,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}
