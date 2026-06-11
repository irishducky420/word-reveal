/// The 8 valid word-search directions (orthogonal + diagonal, both ways).
enum Direction {
  east(0, 1),
  west(0, -1),
  south(1, 0),
  north(-1, 0),
  southEast(1, 1),
  southWest(1, -1),
  northEast(-1, 1),
  northWest(-1, -1);

  final int dRow;
  final int dCol;
  const Direction(this.dRow, this.dCol);

  /// Resolves a unit delta to a direction, or null if not one of the 8.
  static Direction? fromDelta(int dRow, int dCol) {
    for (final d in values) {
      if (d.dRow == dRow && d.dCol == dCol) return d;
    }
    return null;
  }
}
