/// A single board coordinate. Pure Dart - no Flutter imports.
class Cell {
  final int row;
  final int col;
  const Cell(this.row, this.col);

  Map<String, dynamic> toJson() => {'r': row, 'c': col};

  factory Cell.fromJson(Map<String, dynamic> json) =>
      Cell(json['r'] as int, json['c'] as int);

  @override
  bool operator ==(Object other) =>
      other is Cell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'Cell($row,$col)';
}
