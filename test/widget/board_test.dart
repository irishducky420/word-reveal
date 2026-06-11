import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_reveal/domain/models/cell.dart';
import 'package:word_reveal/domain/models/difficulty.dart';
import 'package:word_reveal/domain/models/puzzle.dart';
import 'package:word_reveal/domain/models/region.dart';
import 'package:word_reveal/features/reveal/master_art.dart';
import 'package:word_reveal/features/word_search/board_widget.dart';
import 'package:word_reveal/features/word_search/puzzle_viewmodel.dart';
import 'package:word_reveal/services/puzzle_engine/path_match.dart';
import 'package:word_reveal/services/puzzle_engine/puzzle_generator.dart';

/// Trivial image source so board tests don't depend on artwork.
class _FlatColorSource implements MasterImageSource {
  @override
  void paintFull(Canvas canvas, Rect rect) =>
      canvas.drawRect(rect, Paint()..color = const Color(0xFF4488CC));
}

const double _boardSize = 400;

void main() {
  final generator = PuzzleGenerator();

  late GeneratedPuzzle puzzle;
  late List<List<Cell>> submitted;
  late Set<Cell> revealed;

  Widget harness() {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _boardSize,
            height: _boardSize,
            child: StatefulBuilder(
              builder: (context, setState) => WordSearchBoard(
                puzzle: puzzle,
                region: RegionSpec.forPuzzle(1, 0),
                imageSource: _FlatColorSource(),
                revealedCells: revealed,
                onSelection: (path) {
                  submitted.add(path);
                  final match = matchSelection(puzzle.placedWords, path);
                  if (match == null) return SelectionResult.invalid;
                  setState(() => revealed = {...revealed, ...match.cells});
                  return SelectionResult.found;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    puzzle = generator.generate(
      const PuzzleConfig(
        gridSize: 8,
        words: ['FOX', 'DEN', 'TAIL', 'PAWS'],
        difficulty: Difficulty.beginner,
      ),
      seed: 1234,
    );
    submitted = [];
    revealed = {};
  });

  Offset cellCenter(WidgetTester tester, Cell cell) {
    final topLeft = tester.getTopLeft(find.byType(WordSearchBoard));
    const cellSize = _boardSize / 8;
    return topLeft +
        Offset((cell.col + 0.5) * cellSize, (cell.row + 0.5) * cellSize);
  }

  Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
    final gesture = await tester.startGesture(from);
    // Several intermediate moves, like a real finger.
    for (var i = 1; i <= 6; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 6)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a forward drag along a placed word finds it', (tester) async {
    await tester.pumpWidget(harness());
    final word = puzzle.placedWords.first;

    await drag(tester, cellCenter(tester, word.cells.first),
        cellCenter(tester, word.cells.last));

    expect(submitted, hasLength(1));
    expect(pathsEqual(submitted.single, word.cells), isTrue);
    expect(revealed, containsAll(word.cells));
  });

  testWidgets('a reversed drag (end to start) also finds the word',
      (tester) async {
    await tester.pumpWidget(harness());
    final word = puzzle.placedWords.last;

    await drag(tester, cellCenter(tester, word.cells.last),
        cellCenter(tester, word.cells.first));

    expect(submitted, hasLength(1));
    expect(pathsEqual(submitted.single, word.cells), isTrue);
    expect(revealed, containsAll(word.cells));
  });

  testWidgets('an invalid straight drag submits and rejects cleanly',
      (tester) async {
    await tester.pumpWidget(harness());
    // Build a straight 3-cell path that is NOT any placed word's path.
    List<Cell>? candidate;
    for (var r = 0; r < 8 && candidate == null; r++) {
      for (var c = 0; c < 6 && candidate == null; c++) {
        final path = [Cell(r, c), Cell(r, c + 1), Cell(r, c + 2)];
        if (matchSelection(puzzle.placedWords, path) == null) {
          candidate = path;
        }
      }
    }
    expect(candidate, isNotNull, reason: 'an 8x8 board always has free rows');

    await drag(tester, cellCenter(tester, candidate!.first),
        cellCenter(tester, candidate.last));

    expect(submitted, hasLength(1));
    expect(revealed, isEmpty);
    // The board recovered: no selection overlay stuck, a new drag works.
    final word = puzzle.placedWords.first;
    await drag(tester, cellCenter(tester, word.cells.first),
        cellCenter(tester, word.cells.last));
    expect(revealed, containsAll(word.cells));
  });

  testWidgets('a non-straight (knight-move) endpoint keeps the last valid '
      'line instead of submitting a bent path', (tester) async {
    await tester.pumpWidget(harness());

    const start = Cell(4, 1);
    final gesture = await tester.startGesture(cellCenter(tester, start));
    await gesture.moveTo(cellCenter(tester, const Cell(4, 3))); // valid east
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(cellCenter(tester, const Cell(5, 4))); // not aligned
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(submitted, hasLength(1));
    expect(submitted.single,
        const [Cell(4, 1), Cell(4, 2), Cell(4, 3)],
        reason: 'diagonal-but-not-45-degree movement must not extend the path');
  });

  testWidgets('a tap (single cell) is ignored entirely', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tapAt(cellCenter(tester, const Cell(2, 2)));
    await tester.pumpAndSettle();
    expect(submitted, isEmpty);
  });
}
