import 'package:material_ui/material_ui.dart';

import '../models/lecture.dart';
import '../services/database_helper.dart';

/// Flashcard study view: tap a card to flip it, then mark it known or
/// unknown. Progress is saved per card in SQLite.
class FlashcardsScreen extends StatefulWidget {
  final int lectureId;
  final String title;

  const FlashcardsScreen({
    super.key,
    required this.lectureId,
    required this.title,
  });

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final _db = DatabaseHelper.instance;
  final _pageController = PageController();

  List<Flashcard> _cards = [];
  bool _loading = true;
  bool _flipped = false;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cards = await _db.getFlashcards(widget.lectureId);
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _loading = false;
      _index = 0;
      _flipped = false;
    });
  }

  Future<void> _mark(bool known) async {
    if (_cards.isEmpty) return;
    final card = _cards[_index];
    await _db.setFlashcardKnown(card.id!, known);
    final updated = await _db.getFlashcards(widget.lectureId);
    if (!mounted) return;
    setState(() {
      _cards = updated;
      _flipped = false;
    });
    if (_index < _cards.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final knownCount = _cards.where((c) => c.known).length;
    return Scaffold(
      appBar: AppBar(title: Text('Flashcards — ${widget.title}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No flashcards for this lecture yet.\n'
                      'Generate a summary from the Summary tab and '
                      'flashcards will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Text(
                            'Card ${_index + 1} of ${_cards.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text('$knownCount known'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: LinearProgressIndicator(
                        value: _cards.isEmpty
                            ? 0
                            : knownCount / _cards.length,
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _cards.length,
                        onPageChanged: (i) {
                          setState(() {
                            _index = i;
                            _flipped = false;
                          });
                        },
                        itemBuilder: (context, i) {
                          final card = _cards[i];
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _flipped = !_flipped);
                              },
                              child: Card(
                                elevation: 4,
                                color: _flipped
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : null,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _flipped ? 'Answer' : 'Question',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _flipped
                                              ? card.answer
                                              : card.question,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'Tap to flip',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _mark(false),
                              icon: const Icon(Icons.close),
                              label: const Text("Don't know yet"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _mark(true),
                              icon: const Icon(Icons.check),
                              label: const Text('I know this'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
