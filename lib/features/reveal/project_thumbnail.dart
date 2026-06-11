import 'package:flutter/material.dart';

import '../../domain/models/cell.dart';
import '../../domain/models/content.dart';
import '../../domain/models/progress.dart';
import '../../domain/models/region.dart';
import 'master_art.dart';

/// The persistent "whole master image" view: painted tiles in full color,
/// everything else greyed. Accumulates across ALL of a project's puzzles -
/// completed regions stay painted, the in-progress region shows per-cell
/// reveals, untouched regions are grey.
class ProjectThumbnail extends StatelessWidget {
  final ImageProject project;
  final ProjectProgress? progress;
  final bool locked;

  const ProjectThumbnail({
    super.key,
    required this.project,
    required this.progress,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final greyColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3A3A42)
        : const Color(0xFFD8D8DE);
    return FutureBuilder<MasterImageSource>(
      future: MasterArtRegistry.resolve(project.imageRef),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ColoredBox(color: greyColor);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _ThumbnailPainter(
                source: snapshot.data!,
                project: project,
                progress: progress,
                greyColor: greyColor,
              ),
            ),
            if (locked)
              const ColoredBox(
                color: Color(0xA6000000),
                child: Icon(Icons.lock, color: Colors.white70, size: 32),
              ),
          ],
        );
      },
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  final MasterImageSource source;
  final ImageProject project;
  final ProjectProgress? progress;
  final Color greyColor;

  _ThumbnailPainter({
    required this.source,
    required this.project,
    required this.progress,
    required this.greyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    source.paintFull(canvas, full);

    final grey = Paint()..color = greyColor.withValues(alpha: 0.96);
    final count = project.puzzles.length;
    for (var i = 0; i < count; i++) {
      if (progress?.isPuzzleCompleted(i) ?? false) continue; // stays painted
      final region = RegionSpec.forPuzzle(count, i);
      final n = project.puzzles[i].difficulty.gridSize;
      final revealed =
          progress?.puzzles[i]?.revealedCells.toSet() ?? const <Cell>{};
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          if (revealed.contains(Cell(r, c))) continue;
          final t = region.tileRect(n, r, c);
          canvas.drawRect(
            Rect.fromLTRB(t.x0 * size.width, t.y0 * size.height,
                t.x1 * size.width, t.y1 * size.height),
            grey,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ThumbnailPainter old) =>
      old.progress != progress ||
      !identical(old.project, project) ||
      old.greyColor != greyColor;
}

/// Paints a master image at full clarity (gallery, celebration, covers).
class ArtView extends StatelessWidget {
  final String imageRef;
  const ArtView({super.key, required this.imageRef});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MasterImageSource>(
      future: MasterArtRegistry.resolve(imageRef),
      builder: (context, snapshot) => snapshot.hasData
          ? CustomPaint(painter: _FullArtPainter(snapshot.data!))
          : const SizedBox.expand(),
    );
  }
}

class _FullArtPainter extends CustomPainter {
  final MasterImageSource source;
  _FullArtPainter(this.source);

  @override
  void paint(Canvas canvas, Size size) =>
      source.paintFull(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(_FullArtPainter old) => !identical(old.source, source);
}
