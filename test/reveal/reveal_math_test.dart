import 'package:flutter_test/flutter_test.dart';
import 'package:word_reveal/domain/models/region.dart';

void main() {
  group('RegionSpec layout', () {
    test('factors counts into the most square layout', () {
      expect(RegionSpec.forPuzzle(1, 0), _layout(1, 1));
      expect(RegionSpec.forPuzzle(3, 0), _layout(1, 3)); // bands
      expect(RegionSpec.forPuzzle(4, 0), _layout(2, 2)); // quadrants
      expect(RegionSpec.forPuzzle(6, 0), _layout(2, 3));
      expect(RegionSpec.forPuzzle(9, 0), _layout(3, 3));
    });

    test('regions tile the image row-major with no gaps or overlap', () {
      for (var count = 1; count <= 12; count++) {
        final regions = [
          for (var i = 0; i < count; i++)
            RegionSpec.forPuzzle(count, i).regionRect
        ];
        // Pairwise disjoint interiors + total area exactly 1.
        var area = 0.0;
        for (final r in regions) {
          area += r.width * r.height;
        }
        expect(area, closeTo(1.0, 1e-12));
        for (var a = 0; a < regions.length; a++) {
          for (var b = a + 1; b < regions.length; b++) {
            final ra = regions[a];
            final rb = regions[b];
            final overlapX = ra.x0 < rb.x1 && rb.x0 < ra.x1;
            final overlapY = ra.y0 < rb.y1 && rb.y0 < ra.y1;
            expect(overlapX && overlapY, isFalse,
                reason: 'regions $a and $b overlap (count=$count)');
          }
        }
      }
    });
  });

  group('tile mapping exactness', () {
    test('adjacent tiles share edges bitwise-exactly', () {
      for (final count in [1, 2, 3, 4, 6, 9]) {
        for (final gridSize in [8, 9, 10, 12, 16, 24]) {
          for (var i = 0; i < count; i++) {
            final region = RegionSpec.forPuzzle(count, i);
            for (var r = 0; r < gridSize; r++) {
              for (var c = 0; c < gridSize - 1; c++) {
                expect(
                  region.tileRect(gridSize, r, c).x1,
                  region.tileRect(gridSize, r, c + 1).x0,
                  reason: 'horizontal seam at ($r,$c)',
                );
              }
            }
            for (var c = 0; c < gridSize; c++) {
              for (var r = 0; r < gridSize - 1; r++) {
                expect(
                  region.tileRect(gridSize, r, c).y1,
                  region.tileRect(gridSize, r + 1, c).y0,
                  reason: 'vertical seam at ($r,$c)',
                );
              }
            }
          }
        }
      }
    });

    test('region corner tiles land exactly on region boundaries', () {
      for (final count in [2, 3, 4, 6, 9]) {
        for (final gridSize in [8, 12, 24]) {
          for (var i = 0; i < count; i++) {
            final region = RegionSpec.forPuzzle(count, i);
            final rect = region.regionRect;
            final n = gridSize;
            expect(region.tileRect(n, 0, 0).x0, rect.x0);
            expect(region.tileRect(n, 0, 0).y0, rect.y0);
            expect(region.tileRect(n, n - 1, n - 1).x1, rect.x1);
            expect(region.tileRect(n, n - 1, n - 1).y1, rect.y1);
          }
        }
      }
    });

    test(
        'cross-region boundaries match bitwise even when the two puzzles '
        'use different grid sizes', () {
      // 2x2 quadrant layout; left puzzle 8x8, right puzzle 12x12.
      final left = RegionSpec.forPuzzle(4, 0);
      final right = RegionSpec.forPuzzle(4, 1);
      expect(left.tileRect(8, 0, 7).x1, right.tileRect(12, 0, 0).x0);
      // Top 10x10, bottom 24x24.
      final top = RegionSpec.forPuzzle(4, 0);
      final bottom = RegionSpec.forPuzzle(4, 2);
      expect(top.tileRect(10, 9, 0).y1, bottom.tileRect(24, 0, 0).y0);
    });

    test('full coverage: outermost edges are exactly 0.0 and 1.0', () {
      for (final count in [1, 3, 4, 9]) {
        final first = RegionSpec.forPuzzle(count, 0);
        final last = RegionSpec.forPuzzle(count, count - 1);
        expect(first.tileRect(8, 0, 0).x0, 0.0);
        expect(first.tileRect(8, 0, 0).y0, 0.0);
        expect(last.tileRect(8, 7, 7).x1, 1.0);
        expect(last.tileRect(8, 7, 7).y1, 1.0);
      }
    });

    test('a 9x9 grid over a quarter-region reconstructs every slice '
        'exactly (reference case from the brief)', () {
      final region = RegionSpec.forPuzzle(4, 0); // a quadrant
      const n = 9;
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          final t = region.tileRect(n, r, c);
          expect(t.x0, (region.col * n + c) / (region.cols * n));
          expect(t.x1, (region.col * n + c + 1) / (region.cols * n));
          expect(t.width, greaterThan(0));
          expect(t.height, greaterThan(0));
        }
      }
    });
  });
}

Matcher _layout(int cols, int rows) => predicate<RegionSpec>(
    (s) => s.cols == cols && s.rows == rows, 'layout ${cols}x$rows');
