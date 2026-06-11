import 'difficulty.dart';
import 'cell.dart';
import 'placed_word.dart';

/// Input to the puzzle generation engine.
class PuzzleConfig {
  final int gridSize;
  final List<String> words;
  final Difficulty difficulty;

  const PuzzleConfig({
    required this.gridSize,
    required this.words,
    required this.difficulty,
  });
}

/// Output of the puzzle generation engine.
class GeneratedPuzzle {
  /// grid[row][col] is a single uppercase letter A-Z.
  final List<List<String>> grid;
  final List<PlacedWord> placedWords;

  const GeneratedPuzzle({required this.grid, required this.placedWords});

  int get gridSize => grid.length;

  String letterAt(Cell cell) => grid[cell.row][cell.col];

  int get totalCells => gridSize * gridSize;
}
