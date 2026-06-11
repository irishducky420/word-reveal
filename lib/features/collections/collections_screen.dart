import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../core/widgets.dart';
import '../../domain/models/content.dart';
import '../../domain/models/progress.dart';
import '../reveal/project_thumbnail.dart';

/// Home: the collections grid.
class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    final progress = ref.watch(progressProvider).valueOrNull ?? const {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Reveal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Gallery',
            onPressed: () => context.go(Routes.gallery),
          ),
          const CoinChip(),
        ],
      ),
      body: collections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load content:\n$error')),
        data: (list) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            mainAxisExtent: 220,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) =>
              _CollectionCard(collection: list[i], progressMap: progress),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final GameCollection collection;
  final Map<String, ProjectProgress> progressMap;

  const _CollectionCard({required this.collection, required this.progressMap});

  @override
  Widget build(BuildContext context) {
    final done = collection.projects
        .where((p) => progressMap[p.id]?.completed ?? false)
        .length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(Routes.collection(collection.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                children: [
                  for (final project in collection.projects.take(3))
                    Expanded(
                      child: ProjectThumbnail(
                        project: project,
                        progress: progressMap[project.id],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(collection.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '$done of ${collection.projects.length} pictures complete · ${collection.description}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
