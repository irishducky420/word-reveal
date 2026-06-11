import 'cell.dart';

/// Saved state of a single puzzle. The board itself is not stored:
/// it is regenerated deterministically from [seed], which makes saves
/// tiny and guarantees a mid-puzzle resume shows the identical board.
class PuzzleProgress {
  final int seed;
  final List<String> foundWords;
  final List<Cell> revealedCells;
  final bool completed;
  final int hintsUsed;

  const PuzzleProgress({
    required this.seed,
    this.foundWords = const [],
    this.revealedCells = const [],
    this.completed = false,
    this.hintsUsed = 0,
  });

  PuzzleProgress copyWith({
    List<String>? foundWords,
    List<Cell>? revealedCells,
    bool? completed,
    int? hintsUsed,
  }) =>
      PuzzleProgress(
        seed: seed,
        foundWords: foundWords ?? this.foundWords,
        revealedCells: revealedCells ?? this.revealedCells,
        completed: completed ?? this.completed,
        hintsUsed: hintsUsed ?? this.hintsUsed,
      );

  Map<String, dynamic> toJson() => {
        'seed': seed,
        'foundWords': foundWords,
        'revealedCells': [for (final c in revealedCells) c.toJson()],
        'completed': completed,
        'hintsUsed': hintsUsed,
      };

  factory PuzzleProgress.fromJson(Map<String, dynamic> json) => PuzzleProgress(
        seed: json['seed'] as int,
        foundWords: [for (final w in json['foundWords'] as List) w as String],
        revealedCells: [
          for (final c in json['revealedCells'] as List)
            Cell.fromJson(c as Map<String, dynamic>)
        ],
        completed: json['completed'] as bool,
        hintsUsed: json['hintsUsed'] as int,
      );
}

/// Saved state of an image project (one master image, several puzzles).
class ProjectProgress {
  final String projectId;

  /// Keyed by puzzle index. Unstarted puzzles have no entry.
  final Map<int, PuzzleProgress> puzzles;
  final bool completed;

  const ProjectProgress({
    required this.projectId,
    this.puzzles = const {},
    this.completed = false,
  });

  factory ProjectProgress.initial(String projectId) =>
      ProjectProgress(projectId: projectId);

  ProjectProgress withPuzzle(int index, PuzzleProgress progress) =>
      ProjectProgress(
        projectId: projectId,
        puzzles: {...puzzles, index: progress},
        completed: completed,
      );

  ProjectProgress copyWith({bool? completed}) => ProjectProgress(
        projectId: projectId,
        puzzles: puzzles,
        completed: completed ?? this.completed,
      );

  bool isPuzzleCompleted(int index) => puzzles[index]?.completed ?? false;

  int completedPuzzleCount(int totalPuzzles) {
    var n = 0;
    for (var i = 0; i < totalPuzzles; i++) {
      if (isPuzzleCompleted(i)) n++;
    }
    return n;
  }

  bool allPuzzlesCompleted(int totalPuzzles) =>
      completedPuzzleCount(totalPuzzles) == totalPuzzles;

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'puzzles': {
          for (final e in puzzles.entries) e.key.toString(): e.value.toJson()
        },
        'completed': completed,
      };

  factory ProjectProgress.fromJson(Map<String, dynamic> json) =>
      ProjectProgress(
        projectId: json['projectId'] as String,
        puzzles: {
          for (final e in (json['puzzles'] as Map<String, dynamic>).entries)
            int.parse(e.key):
                PuzzleProgress.fromJson(e.value as Map<String, dynamic>)
        },
        completed: json['completed'] as bool,
      );
}

/// A completed artwork shown in the gallery.
class GalleryEntry {
  final String projectId;
  final String collectionId;
  final String name;
  final String imageRef;
  final int completedAtMillis;

  const GalleryEntry({
    required this.projectId,
    required this.collectionId,
    required this.name,
    required this.imageRef,
    required this.completedAtMillis,
  });

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'collectionId': collectionId,
        'name': name,
        'imageRef': imageRef,
        'completedAtMillis': completedAtMillis,
      };

  factory GalleryEntry.fromJson(Map<String, dynamic> json) => GalleryEntry(
        projectId: json['projectId'] as String,
        collectionId: json['collectionId'] as String,
        name: json['name'] as String,
        imageRef: json['imageRef'] as String,
        completedAtMillis: json['completedAtMillis'] as int,
      );
}
