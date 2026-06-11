import 'dart:math';

/// A rectangle expressed as fractions [0..1] of the full master image.
class RegionRect {
  final double x0, y0, x1, y1;
  const RegionRect(this.x0, this.y0, this.x1, this.y1);

  double get width => x1 - x0;
  double get height => y1 - y0;

  @override
  bool operator ==(Object other) =>
      other is RegionRect &&
      other.x0 == x0 &&
      other.y0 == y0 &&
      other.x1 == x1 &&
      other.y1 == y1;

  @override
  int get hashCode => Object.hash(x0, y0, x1, y1);

  @override
  String toString() => 'RegionRect($x0,$y0,$x1,$y1)';
}

/// Which slice of the master image a puzzle paints, expressed on an
/// integer lattice so all tile-edge math is exact (no half-pixel drift).
///
/// A project with N puzzles is partitioned into a `cols` x `rows` layout
/// (rectangular when N factors nicely, horizontal bands otherwise).
/// Puzzle i occupies layout cell (col, row), row-major.
///
/// Every fraction below is computed as `integer / integer` in a single
/// division. Equal rationals therefore produce bitwise-identical doubles,
/// which guarantees: adjacent tiles share edges exactly, region boundaries
/// match across puzzles even when their grid sizes differ, and total
/// coverage is exactly [0,1] x [0,1].
class RegionSpec {
  final int col, row, cols, rows;

  const RegionSpec({
    required this.col,
    required this.row,
    required this.cols,
    required this.rows,
  })  : assert(cols > 0 && rows > 0),
        assert(col >= 0 && col < cols),
        assert(row >= 0 && row < rows);

  /// The puzzle's whole region within the master image.
  RegionRect get regionRect =>
      RegionRect(col / cols, row / rows, (col + 1) / cols, (row + 1) / rows);

  /// The image slice behind board cell (r, c) for a `gridSize` board.
  RegionRect tileRect(int gridSize, int r, int c) {
    final tx = cols * gridSize;
    final ty = rows * gridSize;
    final bx = col * gridSize;
    final by = row * gridSize;
    return RegionRect(
      (bx + c) / tx,
      (by + r) / ty,
      (bx + c + 1) / tx,
      (by + r + 1) / ty,
    );
  }

  /// Layout for a project of [puzzleCount] puzzles: the most square
  /// factorization (4 -> 2x2, 6 -> 2x3, 9 -> 3x3), falling back to
  /// horizontal bands for primes (3 -> 1x3, 5 -> 1x5).
  static RegionSpec forPuzzle(int puzzleCount, int index) {
    assert(puzzleCount > 0 && index >= 0 && index < puzzleCount);
    var cols = 1;
    for (var c = sqrt(puzzleCount).floor(); c >= 1; c--) {
      if (puzzleCount % c == 0) {
        cols = c;
        break;
      }
    }
    final rows = puzzleCount ~/ cols;
    return RegionSpec(
      col: index % cols,
      row: index ~/ cols,
      cols: cols,
      rows: rows,
    );
  }
}
