import 'difficulty.dart';

/// One puzzle's spec inside an image project (content data, not state).
class PuzzleSpec {
  final Difficulty difficulty;
  final List<String> words;

  const PuzzleSpec({required this.difficulty, required this.words});

  factory PuzzleSpec.fromJson(Map<String, dynamic> json) => PuzzleSpec(
        difficulty: Difficulty.fromId(json['difficulty'] as String),
        words: [for (final w in json['words'] as List) w as String],
      );
}

/// One master image + the ordered puzzles that progressively paint it.
class ImageProject {
  final String id;
  final String name;

  /// `painter:<artId>` for built-in vector art, or `asset:<path>` for a
  /// raster image bundled in assets. See docs/CONTENT_GUIDE.md.
  final String imageRef;
  final List<PuzzleSpec> puzzles;

  const ImageProject({
    required this.id,
    required this.name,
    required this.imageRef,
    required this.puzzles,
  });

  factory ImageProject.fromJson(Map<String, dynamic> json) => ImageProject(
        id: json['id'] as String,
        name: json['name'] as String,
        imageRef: json['imageRef'] as String,
        puzzles: [
          for (final p in json['puzzles'] as List)
            PuzzleSpec.fromJson(p as Map<String, dynamic>)
        ],
      );
}

/// A themed set of image projects.
class GameCollection {
  final String id;
  final String name;
  final String description;
  final List<ImageProject> projects;

  const GameCollection({
    required this.id,
    required this.name,
    required this.description,
    required this.projects,
  });

  factory GameCollection.fromJson(Map<String, dynamic> json) => GameCollection(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        projects: [
          for (final p in json['projects'] as List)
            ImageProject.fromJson(p as Map<String, dynamic>)
        ],
      );
}
