/// Difficulty tiers. Grid-size mapping is fixed by the design brief.
enum Difficulty {
  beginner(8),
  easy(10),
  medium(12),
  hard(16),
  expert(20),
  master(24);

  final int gridSize;
  const Difficulty(this.gridSize);

  String get label => name[0].toUpperCase() + name.substring(1);

  static Difficulty fromId(String id) => Difficulty.values.byName(id);
}
