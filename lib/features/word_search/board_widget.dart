import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../../domain/models/cell.dart';
import '../../domain/models/puzzle.dart';
import '../../domain/models/region.dart';
import '../../services/economy/economy_service.dart';
import '../reveal/master_art.dart';
import 'puzzle_viewmodel.dart' show HintEffect, SelectionResult;

/// The word-search board: letter grid, drag selection along the 8 valid
/// directions, and the per-cell image reveal.
///
/// Performance model (60 FPS during drag):
///  - The base layer (letters + settled image tiles) sits behind a
///    RepaintBoundary and repaints only when a word is found.
///  - The drag selection is a separate overlay driven by a ValueNotifier,
///    so pointer moves repaint a single cheap painter - never the grid.
///  - Reveal animations run on their own layer and are removed when done.
class WordSearchBoard extends StatefulWidget {
  final GeneratedPuzzle puzzle;
  final RegionSpec region;
  final MasterImageSource imageSource;
  final Set<Cell> revealedCells;
  final HintEffect? hint;
  final SelectionResult Function(List<Cell> path) onSelection;

  const WordSearchBoard({
    super.key,
    required this.puzzle,
    required this.region,
    required this.imageSource,
    required this.revealedCells,
    required this.onSelection,
    this.hint,
  });

  @override
  State<WordSearchBoard> createState() => _WordSearchBoardState();
}

class _RevealBatch {
  final Set<Cell> cells;
  final AnimationController controller;
  _RevealBatch(this.cells, this.controller);
}

class _WordSearchBoardState extends State<WordSearchBoard>
    with TickerProviderStateMixin {
  static const Duration _revealDuration = Duration(milliseconds: 350);

  final ValueNotifier<List<Cell>> _selection = ValueNotifier(const []);
  int? _activePointer; // multi-touch safety: only this pointer drives drag
  Cell? _anchor;

  final List<_RevealBatch> _batches = [];
  late final AnimationController _invalidController;
  List<Cell> _invalidPath = const [];
  late final AnimationController _pulseController;

  // Letter glyphs are laid out once per (cellSize, color) and reused.
  final Map<String, TextPainter> _letterCache = {};
  double _cacheCellSize = -1;
  Color _cacheColor = const Color(0x00000000);

  @override
  void initState() {
    super.initState();
    _invalidController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _invalidController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _invalidPath = const [];
    });
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _syncHintPulse();
  }

  @override
  void didUpdateWidget(WordSearchBoard old) {
    super.didUpdateWidget(old);
    if (!identical(old.puzzle, widget.puzzle)) {
      for (final b in _batches) {
        b.controller.dispose();
      }
      _batches.clear();
      _selection.value = const [];
      _activePointer = null;
      _anchor = null;
      return;
    }
    final added = widget.revealedCells.difference(old.revealedCells);
    if (added.isNotEmpty) _startReveal(added);
    if (widget.hint?.type != old.hint?.type ||
        widget.hint?.word != old.hint?.word) {
      _syncHintPulse();
    }
  }

  void _syncHintPulse() {
    if (widget.hint?.type == HintType.highlight) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  void _startReveal(Set<Cell> cells) {
    if (MediaQuery.of(context).disableAnimations) {
      setState(() {}); // reduced motion: tiles settle instantly
      return;
    }
    final controller =
        AnimationController(vsync: this, duration: _revealDuration);
    final batch = _RevealBatch(cells, controller);
    setState(() => _batches.add(batch));
    controller.forward().whenComplete(() {
      if (mounted) setState(() => _batches.remove(batch));
      controller.dispose();
    });
  }

  @override
  void dispose() {
    for (final b in _batches) {
      b.controller.dispose();
    }
    _invalidController.dispose();
    _pulseController.dispose();
    _selection.dispose();
    super.dispose();
  }

  Cell _cellAt(Offset local, double cellSize) {
    final n = widget.puzzle.gridSize;
    final col = (local.dx / cellSize).floor().clamp(0, n - 1);
    final row = (local.dy / cellSize).floor().clamp(0, n - 1);
    return Cell(row, col);
  }

  void _onPointerDown(PointerDownEvent event, double cellSize) {
    if (_activePointer != null) return; // ignore secondary fingers
    _activePointer = event.pointer;
    _anchor = _cellAt(event.localPosition, cellSize);
    _selection.value = [_anchor!];
  }

  void _onPointerMove(PointerMoveEvent event, double cellSize) {
    if (event.pointer != _activePointer || _anchor == null) return;
    final cur = _cellAt(event.localPosition, cellSize);
    final dr = cur.row - _anchor!.row;
    final dc = cur.col - _anchor!.col;
    if (dr == 0 && dc == 0) {
      _selection.value = [_anchor!];
      return;
    }
    // Only clean orthogonal/45-degree lines are selectable. Anything else
    // keeps the last valid line (snap behavior, no error state).
    if (dr == 0 || dc == 0 || dr.abs() == dc.abs()) {
      final steps = math.max(dr.abs(), dc.abs());
      final sr = dr.sign;
      final sc = dc.sign;
      _selection.value = [
        for (var i = 0; i <= steps; i++)
          Cell(_anchor!.row + sr * i, _anchor!.col + sc * i),
      ];
    }
  }

  void _endDrag(int pointer) {
    if (pointer != _activePointer) return;
    final path = _selection.value;
    _activePointer = null;
    _anchor = null;
    _selection.value = const [];
    if (path.length < 2) return;
    final result = widget.onSelection(path);
    if (result == SelectionResult.invalid) {
      _invalidPath = path;
      _invalidController.forward(from: 0);
    }
  }

  Map<String, TextPainter> _letters(double cellSize, Color color) {
    if (cellSize != _cacheCellSize || color != _cacheColor) {
      _letterCache.clear();
      _cacheCellSize = cellSize;
      _cacheColor = color;
    }
    if (_letterCache.isEmpty) {
      for (var i = 0; i < 26; i++) {
        final letter = String.fromCharCode(65 + i);
        _letterCache[letter] = TextPainter(
          text: TextSpan(
            text: letter,
            style: TextStyle(
              fontSize: cellSize * 0.52,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      }
    }
    return _letterCache;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      final n = widget.puzzle.gridSize;
      final cellSize = size / n;
      final letters = _letters(cellSize, scheme.onSurface);

      final animating = <Cell>{for (final b in _batches) ...b.cells};
      final settled = widget.revealedCells.difference(animating);

      final board = SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: Size.square(size),
                painter: _BoardBasePainter(
                  puzzle: widget.puzzle,
                  settledCells: settled,
                  imageSource: widget.imageSource,
                  region: widget.region,
                  letters: letters,
                  cellColorA: scheme.surfaceContainerHighest,
                  cellColorB: scheme.surfaceContainerHigh,
                ),
              ),
            ),
            for (final batch in _batches)
              CustomPaint(
                size: Size.square(size),
                painter: _RevealAnimPainter(
                  batch: batch,
                  puzzle: widget.puzzle,
                  imageSource: widget.imageSource,
                  region: widget.region,
                  coverColor: scheme.surface,
                ),
              ),
            if (widget.hint != null &&
                widget.hint!.type != HintType.imagePreview)
              CustomPaint(
                size: Size.square(size),
                painter: _HintPainter(
                  hint: widget.hint!,
                  gridSize: n,
                  pulse: _pulseController,
                  color: scheme.tertiary,
                ),
              ),
            ValueListenableBuilder<List<Cell>>(
              valueListenable: _selection,
              builder: (context, path, _) => CustomPaint(
                size: Size.square(size),
                painter: _SelectionPainter(
                  path: path,
                  gridSize: n,
                  color: scheme.primary,
                ),
              ),
            ),
            CustomPaint(
              size: Size.square(size),
              painter: _InvalidPainter(
                pathProvider: () => _invalidPath,
                animation: _invalidController,
                gridSize: n,
                color: scheme.error,
              ),
            ),
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _onPointerDown(e, cellSize),
                onPointerMove: (e) => _onPointerMove(e, cellSize),
                onPointerUp: (e) => _endDrag(e.pointer),
                onPointerCancel: (e) => _endDrag(e.pointer),
                child: Semantics(
                  label:
                      'Word search board, ${n}x$n letters. Drag across letters to select a word.',
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      );

      // Invalid selections shake the whole board briefly.
      return AnimatedBuilder(
        animation: _invalidController,
        child: board,
        builder: (context, child) {
          final v = _invalidController.value;
          final dx = _invalidPath.isEmpty
              ? 0.0
              : math.sin(v * math.pi * 5) * 5 * (1 - v);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
      );
    });
  }
}

Rect _cellRect(int row, int col, double cellSize) =>
    Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize);

/// Letters + settled (fully revealed) image tiles. Behind a RepaintBoundary;
/// repaints only when the settled set changes.
class _BoardBasePainter extends CustomPainter {
  final GeneratedPuzzle puzzle;
  final Set<Cell> settledCells;
  final MasterImageSource imageSource;
  final RegionSpec region;
  final Map<String, TextPainter> letters;
  final Color cellColorA;
  final Color cellColorB;

  _BoardBasePainter({
    required this.puzzle,
    required this.settledCells,
    required this.imageSource,
    required this.region,
    required this.letters,
    required this.cellColorA,
    required this.cellColorB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = puzzle.gridSize;
    final cellSize = size.width / n;
    final bgPaint = Paint();
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final rect = _cellRect(r, c, cellSize);
        if (settledCells.contains(Cell(r, c))) {
          paintMasterTile(
              canvas, imageSource, rect, region.tileRect(n, r, c));
        } else {
          bgPaint.color = (r + c).isEven ? cellColorA : cellColorB;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                rect.deflate(cellSize * 0.04), Radius.circular(cellSize * 0.12)),
            bgPaint,
          );
          final tp = letters[puzzle.grid[r][c]]!;
          tp.paint(
            canvas,
            rect.center - Offset(tp.width / 2, tp.height / 2),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BoardBasePainter old) =>
      !identical(old.puzzle, puzzle) ||
      !setEquals(old.settledCells, settledCells) ||
      old.cellColorA != cellColorA ||
      !identical(old.letters, letters);
}

/// One found word's tiles fading/scaling in (letters covered as the image
/// fragment pops 0.8 -> 1.0 over ~350ms, ease-out).
class _RevealAnimPainter extends CustomPainter {
  final _RevealBatch batch;
  final GeneratedPuzzle puzzle;
  final MasterImageSource imageSource;
  final RegionSpec region;
  final Color coverColor;

  _RevealAnimPainter({
    required this.batch,
    required this.puzzle,
    required this.imageSource,
    required this.region,
    required this.coverColor,
  }) : super(repaint: batch.controller);

  @override
  void paint(Canvas canvas, Size size) {
    final v = Curves.easeOut.transform(batch.controller.value);
    final n = puzzle.gridSize;
    final cellSize = size.width / n;
    final scale = 0.8 + 0.2 * v;
    for (final cell in batch.cells) {
      final rect = _cellRect(cell.row, cell.col, cellSize);
      // Fade the letter out underneath.
      canvas.drawRect(
          rect, Paint()..color = coverColor.withValues(alpha: v * 0.9));
      // Pop the image fragment in.
      canvas.saveLayer(rect, Paint()..color = Colors.white.withValues(alpha: v));
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.scale(scale);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      paintMasterTile(canvas, imageSource, rect,
          region.tileRect(n, cell.row, cell.col));
      canvas.restore();
      // Brief glow at the peak of the reveal.
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.1)),
        Paint()
          ..color = Colors.white.withValues(alpha: (1 - v) * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSize * 0.06,
      );
    }
  }

  @override
  bool shouldRepaint(_RevealAnimPainter old) => old.batch != batch;
}

/// The live drag selection: a rounded capsule along the selected line.
class _SelectionPainter extends CustomPainter {
  final List<Cell> path;
  final int gridSize;
  final Color color;

  _SelectionPainter({
    required this.path,
    required this.gridSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (path.isEmpty) return;
    final cellSize = size.width / gridSize;
    final start = _cellRect(path.first.row, path.first.col, cellSize).center;
    final end = _cellRect(path.last.row, path.last.col, cellSize).center;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.38)
      ..strokeWidth = cellSize * 0.74
      ..strokeCap = StrokeCap.round;
    if (path.length == 1) {
      canvas.drawCircle(start, cellSize * 0.37, paint);
    } else {
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      old.path != path || old.color != color;
}

/// Red flash over the cells of a rejected selection, fading with the shake.
class _InvalidPainter extends CustomPainter {
  final List<Cell> Function() pathProvider;
  final Animation<double> animation;
  final int gridSize;
  final Color color;

  _InvalidPainter({
    required this.pathProvider,
    required this.animation,
    required this.gridSize,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final path = pathProvider();
    if (path.isEmpty || animation.status != AnimationStatus.forward) return;
    final cellSize = size.width / gridSize;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4 * (1 - animation.value));
    for (final cell in path) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _cellRect(cell.row, cell.col, cellSize).deflate(cellSize * 0.05),
          Radius.circular(cellSize * 0.12),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_InvalidPainter old) => true;
}

/// Letter / direction / highlight hints drawn over the board.
class _HintPainter extends CustomPainter {
  final HintEffect hint;
  final int gridSize;
  final Animation<double> pulse;
  final Color color;

  _HintPainter({
    required this.hint,
    required this.gridSize,
    required this.pulse,
    required this.color,
  }) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / gridSize;
    final first = hint.word.cells.first;
    final firstCenter = _cellRect(first.row, first.col, cellSize).center;

    switch (hint.type) {
      case HintType.letter:
        canvas.drawCircle(firstCenter, cellSize * 0.42,
            Paint()..color = color.withValues(alpha: 0.35));
        canvas.drawCircle(
          firstCenter,
          cellSize * 0.42,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = cellSize * 0.06,
        );
      case HintType.direction:
        final d = hint.word.direction;
        final end = firstCenter +
            Offset(d.dCol * cellSize * 1.6, d.dRow * cellSize * 1.6);
        final paint = Paint()
          ..color = color
          ..strokeWidth = cellSize * 0.12
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(firstCenter, end, paint);
        final angle = math.atan2(
            end.dy - firstCenter.dy, end.dx - firstCenter.dx);
        for (final side in [-1, 1]) {
          canvas.drawLine(
            end,
            end -
                Offset(math.cos(angle + side * 0.5), math.sin(angle + side * 0.5)) *
                    cellSize * 0.45,
            paint,
          );
        }
      case HintType.highlight:
        var minR = gridSize, minC = gridSize, maxR = 0, maxC = 0;
        for (final cell in hint.word.cells) {
          minR = math.min(minR, cell.row);
          minC = math.min(minC, cell.col);
          maxR = math.max(maxR, cell.row);
          maxC = math.max(maxC, cell.col);
        }
        final rect = Rect.fromLTRB(minC * cellSize, minR * cellSize,
            (maxC + 1) * cellSize, (maxR + 1) * cellSize);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(cellSize * 0.08),
              Radius.circular(cellSize * 0.2)),
          Paint()..color = color.withValues(alpha: 0.18 + 0.2 * pulse.value),
        );
      case HintType.imagePreview:
      case HintType.smart:
        break; // handled elsewhere / resolved before reaching the board
    }
  }

  @override
  bool shouldRepaint(_HintPainter old) =>
      old.hint != hint || old.color != color;
}
