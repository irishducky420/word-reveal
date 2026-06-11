import 'dart:math';

import '../../domain/models/cell.dart';
import '../../domain/models/direction.dart';
import '../../domain/models/placed_word.dart';
import '../../domain/models/puzzle.dart';

/// Thrown when a board genuinely cannot be generated (content too dense).
/// The engine never silently drops a word.
class PuzzleGenerationException implements Exception {
  final String message;
  const PuzzleGenerationException(this.message);

  @override
  String toString() => 'PuzzleGenerationException: $message';
}

/// Pure-Dart word-search board generator. No Flutter imports.
///
/// Deterministic when [seed] is passed: the same (config, seed) pair always
/// produces an identical board, which powers save/resume and daily seeds.
class PuzzleGenerator {
  /// Placement attempts per word before the whole board is regenerated.
  static const int maxWordAttempts = 120;

  /// Whole-board regenerations before failing loudly.
  static const int maxBoardRegens = 60;

  /// Content guard: word letters above this fraction of cells is rejected
  /// up front (the brief targets <= ~50%; 0.6 leaves headroom but still
  /// fails loudly on genuinely broken content).
  static const double maxFillRatio = 0.6;

  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  GeneratedPuzzle generate(PuzzleConfig config, {int? seed}) {
    final words = _normalizeWords(config);
    final rng = Random(seed ?? Random().nextInt(1 << 31));
    for (var regen = 0; regen < maxBoardRegens; regen++) {
      final board = _tryBuildBoard(words, config.gridSize, rng);
      if (board != null) return board;
    }
    throw PuzzleGenerationException(
      'Could not place all words after $maxBoardRegens regenerations '
      '(gridSize=${config.gridSize}, words=$words).',
    );
  }

  /// Uppercases, strips non-letters, dedupes, rejects empty/too-long words
  /// and over-dense word lists. Returns words sorted longest-first.
  List<String> _normalizeWords(PuzzleConfig config) {
    final seen = <String>{};
    final words = <String>[];
    for (final raw in config.words) {
      final w = raw.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
      if (w.isEmpty) {
        throw ArgumentError('Word "$raw" is empty after normalization.');
      }
      if (w.length > config.gridSize) {
        throw ArgumentError(
            'Word "$w" (${w.length} letters) exceeds grid size '
            '${config.gridSize}.');
      }
      if (seen.add(w)) words.add(w);
    }
    if (words.isEmpty) throw ArgumentError('Word list is empty.');

    final totalLetters = words.fold<int>(0, (sum, w) => sum + w.length);
    final cells = config.gridSize * config.gridSize;
    if (totalLetters > cells * maxFillRatio) {
      throw ArgumentError(
          'Word letters ($totalLetters) exceed ${(maxFillRatio * 100).round()}% '
          'of $cells cells; this board is too dense to generate reliably.');
    }

    words.sort((a, b) => b.length.compareTo(a.length));
    return words;
  }

  GeneratedPuzzle? _tryBuildBoard(List<String> words, int size, Random rng) {
    final grid =
        List.generate(size, (_) => List<String?>.filled(size, null));
    final placed = <PlacedWord>[];
    for (final word in words) {
      final pw = _tryPlaceWord(word, grid, size, rng);
      if (pw == null) return null; // regenerate the whole board
      placed.add(pw);
    }
    _fillEmptyCells(grid, words, rng);
    return GeneratedPuzzle(
      grid: [
        for (final row in grid) [for (final letter in row) letter!]
      ],
      placedWords: placed,
    );
  }

  PlacedWord? _tryPlaceWord(
      String word, List<List<String?>> grid, int size, Random rng) {
    for (var attempt = 0; attempt < maxWordAttempts; attempt++) {
      final dir = Direction.values[rng.nextInt(Direction.values.length)];
      final row = rng.nextInt(size);
      final col = rng.nextInt(size);
      final endRow = row + dir.dRow * (word.length - 1);
      final endCol = col + dir.dCol * (word.length - 1);
      if (endRow < 0 || endRow >= size || endCol < 0 || endCol >= size) {
        continue;
      }

      var fits = true;
      for (var i = 0; i < word.length; i++) {
        final existing = grid[row + dir.dRow * i][col + dir.dCol * i];
        if (existing != null && existing != word[i]) {
          fits = false;
          break;
        }
      }
      if (!fits) continue;

      final cells = <Cell>[];
      for (var i = 0; i < word.length; i++) {
        final r = row + dir.dRow * i;
        final c = col + dir.dCol * i;
        grid[r][c] = word[i];
        cells.add(Cell(r, c));
      }
      return PlacedWord(word: word, cells: cells, direction: dir);
    }
    return null;
  }

  /// Fills empty cells with random letters, biased ~50% toward letters that
  /// appear in the word list so filler looks natural.
  void _fillEmptyCells(List<List<String?>> grid, List<String> words, Random rng) {
    final pool = words.join();
    for (final row in grid) {
      for (var c = 0; c < row.length; c++) {
        row[c] ??= rng.nextBool()
            ? pool[rng.nextInt(pool.length)]
            : _alphabet[rng.nextInt(_alphabet.length)];
      }
    }
  }
}
