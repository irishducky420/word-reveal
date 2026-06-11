import 'cell.dart';
import 'direction.dart';

/// A word as actually placed on a generated board: the exact cell path.
/// Selection matching is done against this path (forward or reversed),
/// never against letters alone, so overlapping words are never confused.
class PlacedWord {
  final String word;
  final List<Cell> cells;
  final Direction direction;

  const PlacedWord({
    required this.word,
    required this.cells,
    required this.direction,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'cells': [for (final c in cells) c.toJson()],
        'direction': direction.name,
      };

  factory PlacedWord.fromJson(Map<String, dynamic> json) => PlacedWord(
        word: json['word'] as String,
        cells: [
          for (final c in json['cells'] as List)
            Cell.fromJson(c as Map<String, dynamic>)
        ],
        direction: Direction.values.byName(json['direction'] as String),
      );
}
