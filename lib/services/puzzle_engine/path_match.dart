import '../../domain/models/cell.dart';
import '../../domain/models/placed_word.dart';

/// True if [a] and [b] are the same cell path, in either direction.
bool pathsEqual(List<Cell> a, List<Cell> b) {
  if (a.length != b.length) return false;
  var forward = true;
  var backward = true;
  final n = a.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) forward = false;
    if (a[i] != b[n - 1 - i]) backward = false;
    if (!forward && !backward) return false;
  }
  return forward || backward;
}

/// Matches a selected path against placed words by exact path (forward or
/// reversed). Letter content is irrelevant: two words sharing letters can
/// never be confused, and a coincidental duplicate spelling elsewhere on
/// the board does not count.
PlacedWord? matchSelection(List<PlacedWord> placedWords, List<Cell> path) {
  for (final pw in placedWords) {
    if (pathsEqual(pw.cells, path)) return pw;
  }
  return null;
}
