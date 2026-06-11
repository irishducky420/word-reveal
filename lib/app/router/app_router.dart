import 'package:go_router/go_router.dart';

import '../../features/collections/collection_screen.dart';
import '../../features/collections/collections_screen.dart';
import '../../features/collections/project_screen.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/word_search/puzzle_screen.dart';

/// Typed path builders - the only way routes are referenced in the app.
abstract final class Routes {
  static const String home = '/';
  static const String gallery = '/gallery';
  static String collection(String collectionId) => '/collection/$collectionId';
  static String project(String collectionId, String projectId) =>
      '/collection/$collectionId/project/$projectId';
  static String puzzle(String collectionId, String projectId, int index) =>
      '/collection/$collectionId/project/$projectId/puzzle/$index';
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const CollectionsScreen(),
    ),
    GoRoute(
      path: '/gallery',
      builder: (context, state) => const GalleryScreen(),
    ),
    GoRoute(
      path: '/collection/:cid',
      builder: (context, state) =>
          CollectionScreen(collectionId: state.pathParameters['cid']!),
    ),
    GoRoute(
      path: '/collection/:cid/project/:pid',
      builder: (context, state) => ProjectScreen(
        collectionId: state.pathParameters['cid']!,
        projectId: state.pathParameters['pid']!,
      ),
    ),
    GoRoute(
      path: '/collection/:cid/project/:pid/puzzle/:index',
      builder: (context, state) => PuzzleScreen(
        collectionId: state.pathParameters['cid']!,
        projectId: state.pathParameters['pid']!,
        puzzleIndex: int.parse(state.pathParameters['index']!),
      ),
    ),
  ],
);
