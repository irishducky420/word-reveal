import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/providers.dart';
import '../../core/widgets.dart';
import '../../domain/models/direction.dart';
import '../../domain/models/region.dart';
import '../../domain/models/placed_word.dart';
import '../../services/economy/economy_service.dart';
import '../reveal/master_art.dart';
import '../reveal/project_thumbnail.dart';
import 'board_widget.dart';
import 'puzzle_viewmodel.dart';

class PuzzleScreen extends ConsumerStatefulWidget {
  final String collectionId;
  final String projectId;
  final int puzzleIndex;

  const PuzzleScreen({
    super.key,
    required this.collectionId,
    required this.projectId,
    required this.puzzleIndex,
  });

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  Timer? _hintTimer;

  PuzzleArgs get _args => (
        collectionId: widget.collectionId,
        projectId: widget.projectId,
        puzzleIndex: widget.puzzleIndex,
      );

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _scheduleHintClear() {
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) ref.read(puzzleVmProvider(_args).notifier).clearHint();
    });
  }

  Future<void> _useHint(HintType type) async {
    final outcome =
        await ref.read(puzzleVmProvider(_args).notifier).useHint(type);
    if (!mounted) return;
    if (outcome == HintOutcome.insufficientCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not enough coins (${type.cost} needed).')),
      );
    }
  }

  void _showPuzzleComplete(PuzzleState s) {
    unawaited(showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration, size: 40),
              const SizedBox(height: 8),
              Text('Puzzle complete!',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('+${s.lastRewardCoins} coins'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.go(
                          Routes.project(widget.collectionId, widget.projectId));
                    },
                    child: const Text('Back to picture'),
                  ),
                  if (!s.isLastPuzzle) ...[
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.go(Routes.puzzle(widget.collectionId,
                            widget.projectId, widget.puzzleIndex + 1));
                      },
                      child: const Text('Next puzzle'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ));
  }

  void _showProjectComplete(PuzzleState s) {
    unawaited(showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, _, __) => _CelebrationDialog(
        state: s,
        onGallery: () {
          Navigator.of(dialogContext).pop();
          context.go(Routes.gallery);
        },
        onDone: () {
          Navigator.of(dialogContext).pop();
          context.go(Routes.project(widget.collectionId, widget.projectId));
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = puzzleVmProvider(_args);
    ref.listen(provider, (prev, next) {
      final p = prev?.valueOrNull;
      final n = next.valueOrNull;
      if (p == null || n == null) return;
      if (!p.puzzleCompleted && n.puzzleCompleted) {
        if (n.projectCompleted && !p.projectCompleted) {
          _showProjectComplete(n);
        } else {
          _showPuzzleComplete(n);
        }
      } else if (n.activeHint != null && n.activeHint != p.activeHint) {
        _scheduleHintClear();
      }
    });

    final vmState = ref.watch(provider);
    return vmState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load puzzle:\n$error',
                textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (s) {
        final spec = s.project.puzzles[s.puzzleIndex];
        return Scaffold(
          appBar: AppBar(
            title: Text(
                '${s.project.name} · ${s.puzzleIndex + 1}/${s.project.puzzles.length}'),
            actions: const [CoinChip()],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _ProgressHeader(state: s, difficultyLabel: spec.difficulty.label),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            WordSearchBoard(
                              puzzle: s.puzzle,
                              region: s.region,
                              imageSource: s.imageSource,
                              revealedCells: s.revealedCells,
                              hint: s.activeHint,
                              onSelection: (path) => ref
                                  .read(provider.notifier)
                                  .submitSelection(path),
                            ),
                            // Image-preview hint: ghost of this puzzle's
                            // region over the board for a few seconds.
                            IgnorePointer(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: s.activeHint?.type ==
                                        HintType.imagePreview
                                    ? 0.45
                                    : 0,
                                child: CustomPaint(
                                  painter: _RegionPreviewPainter(
                                    source: s.imageSource,
                                    regionRect: s.region.regionRect,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _WordChips(state: s),
                _HintBar(
                  enabled: !s.puzzleCompleted,
                  onHint: _useHint,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressHeader extends ConsumerWidget {
  final PuzzleState state;
  final String difficultyLabel;

  const _ProgressHeader({required this.state, required this.difficultyLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress =
        ref.watch(progressProvider).valueOrNull?[state.project.id];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Whole-image progress, accumulated across all puzzles.
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: ProjectThumbnail(
                  project: state.project, progress: progress),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$difficultyLabel · ${state.foundWords.length}/${state.puzzle.placedWords.length} words',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: state.revealFraction, minHeight: 8),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(state.revealFraction * 100).round()}% of this section revealed',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WordChips extends StatelessWidget {
  final PuzzleState state;
  const _WordChips({required this.state});

  @override
  Widget build(BuildContext context) {
    final words = [...state.puzzle.placedWords]
      ..sort((a, b) => a.word.compareTo(b.word));
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          for (final pw in words) _chip(pw, scheme),
        ],
      ),
    );
  }

  Widget _chip(PlacedWord pw, ColorScheme scheme) {
    final found = state.foundWords.contains(pw.word);
    final isDirectionHint = state.activeHint?.type == HintType.direction &&
        state.activeHint?.word.word == pw.word;
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor:
          found ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow,
      avatar: found
          ? Icon(Icons.check, size: 16, color: scheme.primary)
          : isDirectionHint
              ? Transform.rotate(
                  angle: _angleFor(pw.direction),
                  child:
                      Icon(Icons.arrow_forward, size: 16, color: scheme.tertiary),
                )
              : null,
      label: Text(
        pw.word,
        style: TextStyle(
          decoration: found ? TextDecoration.lineThrough : null,
          color: found ? scheme.outline : scheme.onSurface,
          fontSize: 13,
        ),
      ),
    );
  }

  double _angleFor(Direction d) {
    const eighth = 3.14159265 / 4;
    return switch (d) {
      Direction.east => 0,
      Direction.southEast => eighth,
      Direction.south => 2 * eighth,
      Direction.southWest => 3 * eighth,
      Direction.west => 4 * eighth,
      Direction.northWest => -3 * eighth,
      Direction.north => -2 * eighth,
      Direction.northEast => -eighth,
    };
  }
}

class _HintBar extends ConsumerWidget {
  final bool enabled;
  final Future<void> Function(HintType) onHint;

  const _HintBar({required this.enabled, required this.onHint});

  static const _hints = [
    (type: HintType.letter, icon: Icons.text_fields, label: 'Letter'),
    (type: HintType.direction, icon: Icons.turn_slight_right, label: 'Direction'),
    (type: HintType.highlight, icon: Icons.highlight, label: 'Area'),
    (type: HintType.imagePreview, icon: Icons.image_search, label: 'Preview'),
    (type: HintType.smart, icon: Icons.auto_awesome, label: 'Smart'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(walletProvider).valueOrNull?.coins ?? 0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final h in _hints)
              _HintButton(
                icon: h.icon,
                label: h.label,
                cost: h.type.cost,
                enabled: enabled && coins >= h.type.cost,
                onPressed: () => onHint(h.type),
              ),
          ],
        ),
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int cost;
  final bool enabled;
  final VoidCallback onPressed;

  const _HintButton({
    required this.icon,
    required this.label,
    required this.cost,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$label hint, $cost coins',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onPressed : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: scheme.primary),
                Text(label, style: const TextStyle(fontSize: 11)),
                Text('$cost¢',
                    style: TextStyle(fontSize: 10, color: scheme.outline)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionPreviewPainter extends CustomPainter {
  final MasterImageSource source;
  final RegionRect regionRect;

  _RegionPreviewPainter({required this.source, required this.regionRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dest = Offset.zero & size;
    final fullW = dest.width / (regionRect.x1 - regionRect.x0);
    final fullH = dest.height / (regionRect.y1 - regionRect.y0);
    canvas.save();
    canvas.clipRect(dest);
    source.paintFull(
      canvas,
      Rect.fromLTWH(
          -regionRect.x0 * fullW, -regionRect.y0 * fullH, fullW, fullH),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RegionPreviewPainter old) =>
      !identical(old.source, source);
}

class _CelebrationDialog extends StatefulWidget {
  final PuzzleState state;
  final VoidCallback onGallery;
  final VoidCallback onDone;

  const _CelebrationDialog({
    required this.state,
    required this.onGallery,
    required this.onDone,
  });

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Masterpiece revealed!',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(widget.state.project.name,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            // The full image animates from grey to clarity.
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final v = Curves.easeOut.transform(_controller.value);
                return Transform.scale(
                  scale: 0.92 + 0.08 * v,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ArtView(imageRef: widget.state.project.imageRef),
                          ColoredBox(
                            color: const Color(0xFF888890)
                                .withValues(alpha: 1 - v),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text('+${widget.state.lastRewardCoins} coins · added to gallery'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                    onPressed: widget.onGallery,
                    child: const Text('View gallery')),
                const SizedBox(width: 12),
                FilledButton(
                    onPressed: widget.onDone, child: const Text('Done')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
