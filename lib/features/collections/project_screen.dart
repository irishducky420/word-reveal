import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../core/widgets.dart';
import '../../domain/models/content.dart';
import '../../domain/models/progress.dart';
import '../reveal/project_thumbnail.dart';

/// One image project: the accumulating masterpiece + its puzzle list.
class ProjectScreen extends ConsumerWidget {
  final String collectionId;
  final String projectId;

  const ProjectScreen(
      {super.key, required this.collectionId, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    final progressMap = ref.watch(progressProvider).valueOrNull ?? const {};

    return collections.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
          appBar: AppBar(), body: Center(child: Text('Error: $error'))),
      data: (list) {
        final project = list
            .expand((c) => c.id == collectionId ? c.projects : <ImageProject>[])
            .where((p) => p.id == projectId)
            .firstOrNull;
        if (project == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Picture not found.')));
        }
        final progress = progressMap[projectId];
        final percent = _overallRevealPercent(project, progress);
        final nextIndex = _firstIncomplete(project, progress);

        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: const [CoinChip()],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ProjectThumbnail(
                          project: project, progress: progress),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  progress?.completed ?? false
                      ? 'Masterpiece complete!'
                      : '$percent% revealed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < project.puzzles.length; i++)
                _PuzzleTile(
                  collectionId: collectionId,
                  project: project,
                  index: i,
                  progress: progress,
                ),
              const SizedBox(height: 80),
            ],
          ),
          floatingActionButton: nextIndex == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => context.go(
                      Routes.puzzle(collectionId, projectId, nextIndex)),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(progress == null || progress.puzzles.isEmpty
                      ? 'Start'
                      : 'Continue'),
                ),
        );
      },
    );
  }

  int _overallRevealPercent(ImageProject project, ProjectProgress? progress) {
    var revealed = 0;
    var total = 0;
    for (var i = 0; i < project.puzzles.length; i++) {
      final n = project.puzzles[i].difficulty.gridSize;
      total += n * n;
      revealed += (progress?.isPuzzleCompleted(i) ?? false)
          ? n * n
          : progress?.puzzles[i]?.revealedCells.length ?? 0;
    }
    return total == 0 ? 0 : (revealed * 100 ~/ total);
  }

  int? _firstIncomplete(ImageProject project, ProjectProgress? progress) {
    for (var i = 0; i < project.puzzles.length; i++) {
      if (!(progress?.isPuzzleCompleted(i) ?? false)) return i;
    }
    return null;
  }
}

class _PuzzleTile extends StatelessWidget {
  final String collectionId;
  final ImageProject project;
  final int index;
  final ProjectProgress? progress;

  const _PuzzleTile({
    required this.collectionId,
    required this.project,
    required this.index,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final spec = project.puzzles[index];
    final completed = progress?.isPuzzleCompleted(index) ?? false;
    // Puzzles unlock in order so the image paints top-to-bottom.
    final locked =
        index > 0 && !(progress?.isPuzzleCompleted(index - 1) ?? false);
    final found = progress?.puzzles[index]?.foundWords.length ?? 0;

    return Card(
      child: ListTile(
        enabled: !locked,
        leading: CircleAvatar(
          child: completed
              ? const Icon(Icons.check)
              : locked
                  ? const Icon(Icons.lock, size: 18)
                  : Text('${index + 1}'),
        ),
        title: Text('Puzzle ${index + 1} · ${spec.difficulty.label}'),
        subtitle: Text(
            '${spec.difficulty.gridSize}x${spec.difficulty.gridSize} · $found/${spec.words.length} words found'),
        trailing: locked ? null : const Icon(Icons.chevron_right),
        onTap: locked
            ? null
            : () => context
                .go(Routes.puzzle(collectionId, project.id, index)),
      ),
    );
  }
}
