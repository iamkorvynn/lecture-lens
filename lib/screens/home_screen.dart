import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../models/lecture.dart';
import '../services/database_helper.dart';
import 'lecture_detail_screen.dart';
import 'record_screen.dart';
import 'settings_screen.dart';

/// Lecture list: search, open, delete. Starts empty — lectures only
/// appear once the user records one.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();
  List<Lecture> _lectures = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final lectures = await _db.getLectures(query: _query);
    if (!mounted) return;
    setState(() {
      _lectures = lectures;
      _loading = false;
    });
  }

  Future<void> _openRecord() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RecordScreen()),
    );
    if (saved == true) _load();
  }

  Future<void> _openLecture(Lecture lecture) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LectureDetailScreen(lectureId: lecture.id!),
      ),
    );
    _load();
  }

  Future<void> _delete(Lecture lecture) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete lecture?'),
        content: Text(
          '"${lecture.title}" and its recording, transcript, summary '
          'and flashcards will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteLecture(lecture);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lecture deleted')),
        );
      }
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LectureLens'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search lectures…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                          _load();
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _query = value);
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _lectures.isEmpty
                    ? _EmptyState(onRecord: _openRecord)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _lectures.length,
                        itemBuilder: (context, index) {
                          final lecture = _lectures[index];
                          return _LectureTile(
                            lecture: lecture,
                            onTap: () => _openLecture(lecture),
                            onDelete: () => _delete(lecture),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRecord,
        icon: const Icon(Icons.mic),
        label: const Text('Record lecture'),
      ),
    );
  }
}

class _LectureTile extends StatelessWidget {
  final Lecture lecture;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LectureTile({
    required this.lecture,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, d MMM yyyy • h:mm a').format(
      lecture.createdAt,
    );
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.school_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          lecture.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$date • ${lecture.durationLabel}'),
            const SizedBox(height: 2),
            Text(
              lecture.hasSummary
                  ? 'Summary ready'
                  : lecture.transcriptPreview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lecture.hasSummary)
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRecord;

  const _EmptyState({required this.onRecord});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_none,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No lectures yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap "Record lecture" to capture your first class. '
              'LectureLens records the audio and transcribes it live '
              'on your phone, so you can read, revise, and quiz yourself '
              'afterwards.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRecord,
              icon: const Icon(Icons.mic),
              label: const Text('Record your first lecture'),
            ),
          ],
        ),
      ),
    );
  }
}
