import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../core/widgets.dart';
import '../reveal/project_thumbnail.dart';

/// Projects inside a collection: locked silhouette -> partially painted ->
/// complete. Assumption: projects unlock sequentially (finish picture N to
/// unlock picture N+1); the first is always open.
class CollectionScreen extends ConsumerWidget {
  final String collectionId;
  const CollectionScreen({super.key, required this.collectionId});

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
        final collection = list.where((c) => c.id == collectionId).firstOrNull;
        if (collection == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Collection not found.')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(collection.name),
            actions: const [CoinChip()],
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              childAspectRatio: 0.82,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: collection.projects.length,
            itemBuilder: (context, i) {
              final project = collection.projects[i];
              final progress = progressMap[project.id];
              final locked = i > 0 &&
                  !(progressMap[collection.projects[i - 1].id]?.completed ??
                      false);
              final completed = progress?.completed ?? false;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: locked
                      ? null
                      : () => context
                          .go(Routes.project(collectionId, project.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ProjectThumbnail(
                          project: project,
                          progress: progress,
                          locked: locked,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(project.name,
                                  style:
                                      Theme.of(context).textTheme.titleSmall,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (completed)
                              Icon(Icons.check_circle,
                                  size: 18,
                                  color:
                                      Theme.of(context).colorScheme.primary)
                            else if (locked)
                              const Icon(Icons.lock, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
