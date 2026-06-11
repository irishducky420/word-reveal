import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_reveal/domain/models/cell.dart';
import 'package:word_reveal/domain/models/difficulty.dart';
import 'package:word_reveal/domain/models/puzzle.dart';
import 'package:word_reveal/services/puzzle_engine/path_match.dart';
import 'package:word_reveal/services/puzzle_engine/puzzle_generator.dart';

const _dictionary = [
  'CAT', 'DOG', 'SUN', 'RUN', 'SKY', 'FOX', 'OWL', 'BEE', 'ANT', 'ELK', //
  'TREE', 'BIRD', 'FISH', 'WOLF', 'BEAR', 'LION', 'HAWK', 'DEER',
  'TIGER', 'EAGLE', 'SNAKE', 'MOUSE', 'HORSE', 'ZEBRA', 'RIVER', 'STONE',
  'CLOUD', 'RABBIT', 'FALCON', 'JAGUAR', 'BADGER', 'MONKEY', 'TURTLE',
  'SALMON', 'LEOPARD', 'PANTHER', 'GAZELLE', 'OCTOPUS', 'DOLPHIN',
  'PENGUIN', 'ELEPHANT', 'FLAMINGO', 'HEDGEHOG', 'SQUIRREL', 'BUTTERFLY',
  'PORCUPINE', 'WOLVERINE', 'CHIMPANZEE', 'RHINOCEROS',
];

const _wordCounts = {
  Difficulty.beginner: 7,
  Difficulty.easy: 9,
  Difficulty.medium: 12,
  Difficulty.hard: 18,
  Difficulty.expert: 26,
  Difficulty.master: 34,
};

List<String> _randomWordList(Difficulty difficulty, Random rng) {
  final size = difficulty.gridSize;
  final budget = (size * size * 0.5).floor();
  final pool = [for (final w in _dictionary) if (w.length <= size) w]
    ..shuffle(rng);
  final words = <String>[];
  var used = 0;
  for (final w in pool) {
    if (words.length >= _wordCounts[difficulty]!) break;
    if (used + w.length <= budget) {
      words.add(w);
      used += w.length;
    }
  }
  return words;
}

void _verifyBoard(GeneratedPuzzle puzzle, List<String> requestedWords) {
  // Grid is fully filled with A-Z.
  for (final row in puzzle.grid) {
    for (final letter in row) {
      expect(letter.length, 1);
      expect(letter.codeUnitAt(0), inInclusiveRange(65, 90));
    }
  }
  // Every requested word is placed - none silently dropped.
  final placedSet = {for (final pw in puzzle.placedWords) pw.word};
  expect(placedSet, requestedWords.toSet(),
      reason: 'a listed word was dropped from the board');
  // Every placed word's letters sit at its stored path.
  for (final pw in puzzle.placedWords) {
    final letters =
        [for (final cell in pw.cells) puzzle.letterAt(cell)].join();
    expect(letters, pw.word, reason: 'stored path does not spell the word');
    expect(pw.cells.length, pw.word.length);
  }
}

void main() {
  final generator = PuzzleGenerator();

  group('PuzzleGenerator stress', () {
    // The brief demands thousands of randomized generations per difficulty
    // with zero failures. 1000 x 6 difficulties = 6000 boards.
    for (final difficulty in Difficulty.values) {
      test('1000 randomized boards at ${difficulty.name}, zero failures', () {
        final rng = Random(difficulty.index * 99991 + 7);
        for (var i = 0; i < 1000; i++) {
          final words = _randomWordList(difficulty, rng);
          final puzzle = generator.generate(
            PuzzleConfig(
              gridSize: difficulty.gridSize,
              words: words,
              difficulty: difficulty,
            ),
            seed: rng.nextInt(1 << 31),
          );
          _verifyBoard(puzzle, words);
        }
      });
    }
  });

  group('determinism', () {
    test('same seed -> identical board and placements', () {
      const config = PuzzleConfig(
        gridSize: 10,
        words: ['FOREST', 'HUNTER', 'RUSSET', 'POUNCE', 'BURROW'],
        difficulty: Difficulty.easy,
      );
      for (var seed = 0; seed < 50; seed++) {
        final a = generator.generate(config, seed: seed);
        final b = generator.generate(config, seed: seed);
        expect(a.grid, b.grid);
        expect(
          [for (final pw in a.placedWords) pw.toJson()],
          [for (final pw in b.placedWords) pw.toJson()],
        );
      }
    });

    test('different seeds -> different boards (overwhelmingly)', () {
      const config = PuzzleConfig(
        gridSize: 10,
        words: ['FOREST', 'HUNTER', 'RUSSET', 'POUNCE', 'BURROW'],
        difficulty: Difficulty.easy,
      );
      final a = generator.generate(config, seed: 1);
      final b = generator.generate(config, seed: 2);
      expect(a.grid, isNot(equals(b.grid)));
    });
  });

  group('normalization and validation', () {
    test('rejects words longer than the grid', () {
      expect(
        () => generator.generate(const PuzzleConfig(
          gridSize: 8,
          words: ['IMPOSSIBLY'],
          difficulty: Difficulty.beginner,
        )),
        throwsArgumentError,
      );
    });

    test('rejects words that normalize to empty', () {
      expect(
        () => generator.generate(const PuzzleConfig(
          gridSize: 8,
          words: ['123', 'FOX'],
          difficulty: Difficulty.beginner,
        )),
        throwsArgumentError,
      );
    });

    test('rejects over-dense word lists instead of failing silently', () {
      expect(
        () => generator.generate(PuzzleConfig(
          gridSize: 8,
          words: List.generate(10, (i) => 'WORD${String.fromCharCode(65 + i)}'),
          difficulty: Difficulty.beginner,
        )),
        throwsArgumentError,
      );
    });

    test('strips punctuation and uppercases', () {
      final puzzle = generator.generate(
        const PuzzleConfig(
          gridSize: 8,
          words: ['t-rex', 'fox'],
          difficulty: Difficulty.beginner,
        ),
        seed: 5,
      );
      expect({for (final pw in puzzle.placedWords) pw.word}, {'TREX', 'FOX'});
    });

    test('dedupes repeated words', () {
      final puzzle = generator.generate(
        const PuzzleConfig(
          gridSize: 8,
          words: ['FOX', 'fox', 'FOX'],
          difficulty: Difficulty.beginner,
        ),
        seed: 5,
      );
      expect(puzzle.placedWords.length, 1);
    });
  });

  group('path matching (selection rules)', () {
    test('forward and reversed paths match; letters alone never do', () {
      final puzzle = generator.generate(
        const PuzzleConfig(
          gridSize: 10,
          words: ['FOREST', 'HUNTER', 'POUNCE'],
          difficulty: Difficulty.easy,
        ),
        seed: 42,
      );
      for (final pw in puzzle.placedWords) {
        expect(matchSelection(puzzle.placedWords, pw.cells), same(pw));
        expect(
          matchSelection(puzzle.placedWords, pw.cells.reversed.toList()),
          same(pw),
        );
        // Same length, shifted by one cell: must not match.
        final shifted = [
          for (final c in pw.cells) Cell(c.row, (c.col + 1) % 10)
        ];
        expect(matchSelection(puzzle.placedWords, shifted), isNot(same(pw)));
      }
    });

    test('partial and overlong paths do not match', () {
      final puzzle = generator.generate(
        const PuzzleConfig(
          gridSize: 10,
          words: ['FOREST'],
          difficulty: Difficulty.easy,
        ),
        seed: 7,
      );
      final pw = puzzle.placedWords.single;
      expect(matchSelection(puzzle.placedWords, pw.cells.sublist(1)), isNull);
      expect(
        matchSelection(
            puzzle.placedWords, [...pw.cells, const Cell(0, 0)]),
        isNull,
      );
    });
  });
}
