import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/cell.dart';
import '../../domain/models/content.dart';
import '../../domain/models/placed_word.dart';
import '../../domain/models/progress.dart';
import '../../domain/models/puzzle.dart';
import '../../domain/models/region.dart';
import '../../services/economy/economy_service.dart';
import '../../services/puzzle_engine/path_match.dart';
import '../reveal/master_art.dart';

typedef PuzzleArgs = ({
  String collectionId,
  String projectId,
  int puzzleIndex,
});

enum SelectionResult { found, alreadyFound, invalid }

enum HintOutcome { applied, insufficientCoins, unavailable }

/// An active hint the board/screen should render. [type] is the effective
/// type (smart hints resolve to a concrete one before reaching the UI).
class HintEffect {
  final HintType type;
  final PlacedWord word;
  const HintEffect(this.type, this.word);
}

class PuzzleState {
  final String collectionId;
  final ImageProject project;
  final int puzzleIndex;
  final int seed;
  final GeneratedPuzzle puzzle;
  final RegionSpec region;
  final MasterImageSource imageSource;
  final Set<String> foundWords;
  final Set<Cell> revealedCells;
  final int hintsUsed;
  final bool puzzleCompleted;
  final bool projectCompleted;

  /// Coins credited by the most recent find (word + any bonuses), for the
  /// completion UI.
  final int lastRewardCoins;
  final HintEffect? activeHint;

  const PuzzleState({
    required this.collectionId,
    required this.project,
    required this.puzzleIndex,
    required this.seed,
    required this.puzzle,
    required this.region,
    required this.imageSource,
    required this.foundWords,
    required this.revealedCells,
    required this.hintsUsed,
    required this.puzzleCompleted,
    required this.projectCompleted,
    this.lastRewardCoins = 0,
    this.activeHint,
  });

  PuzzleState copyWith({
    Set<String>? foundWords,
    Set<Cell>? revealedCells,
    int? hintsUsed,
    bool? puzzleCompleted,
    bool? projectCompleted,
    int? lastRewardCoins,
    HintEffect? activeHint,
    bool clearHint = false,
  }) =>
      PuzzleState(
        collectionId: collectionId,
        project: project,
        puzzleIndex: puzzleIndex,
        seed: seed,
        puzzle: puzzle,
        region: region,
        imageSource: imageSource,
        foundWords: foundWords ?? this.foundWords,
        revealedCells: revealedCells ?? this.revealedCells,
        hintsUsed: hintsUsed ?? this.hintsUsed,
        puzzleCompleted: puzzleCompleted ?? this.puzzleCompleted,
        projectCompleted: projectCompleted ?? this.projectCompleted,
        lastRewardCoins: lastRewardCoins ?? this.lastRewardCoins,
        activeHint: clearHint ? null : (activeHint ?? this.activeHint),
      );

  double get revealFraction =>
      puzzle.totalCells == 0 ? 0 : revealedCells.length / puzzle.totalCells;

  bool get isLastPuzzle => puzzleIndex == project.puzzles.length - 1;

  List<PlacedWord> get unfoundWords =>
      [for (final pw in puzzle.placedWords) if (!foundWords.contains(pw.word)) pw];
}

class PuzzleVm extends AutoDisposeFamilyAsyncNotifier<PuzzleState, PuzzleArgs> {
  final _rng = Random();

  /// Serializes persistence so rapid finds never write out of order.
  /// Gameplay state updates synchronously; saving trails behind safely.
  Future<void> _saveChain = Future<void>.value();

  @override
  Future<PuzzleState> build(PuzzleArgs arg) async {
    final collections = await ref.watch(collectionsProvider.future);
    final collection =
        collections.firstWhere((c) => c.id == arg.collectionId);
    final project =
        collection.projects.firstWhere((p) => p.id == arg.projectId);
    final spec = project.puzzles[arg.puzzleIndex];

    final progressMap = await ref.read(progressProvider.future);
    var progress =
        progressMap[project.id] ?? ProjectProgress.initial(project.id);
    var pp = progress.puzzles[arg.puzzleIndex];
    if (pp == null) {
      // The seed is persisted BEFORE first play so a mid-puzzle resume
      // regenerates the identical board.
      pp = PuzzleProgress(seed: _rng.nextInt(1 << 31));
      progress = progress.withPuzzle(arg.puzzleIndex, pp);
      await ref.read(progressProvider.notifier).saveProject(progress);
    }

    final generated = ref.read(puzzleGeneratorProvider).generate(
          PuzzleConfig(
            gridSize: spec.difficulty.gridSize,
            words: spec.words,
            difficulty: spec.difficulty,
          ),
          seed: pp.seed,
        );

    final found = pp.foundWords.toSet();
    final revealed = <Cell>{
      for (final pw in generated.placedWords)
        if (found.contains(pw.word)) ...pw.cells,
    };

    return PuzzleState(
      collectionId: arg.collectionId,
      project: project,
      puzzleIndex: arg.puzzleIndex,
      seed: pp.seed,
      puzzle: generated,
      region: RegionSpec.forPuzzle(project.puzzles.length, arg.puzzleIndex),
      imageSource: await MasterArtRegistry.resolve(project.imageRef),
      foundWords: found,
      revealedCells: revealed,
      hintsUsed: pp.hintsUsed,
      puzzleCompleted: pp.completed,
      projectCompleted: progress.completed,
    );
  }

  /// Called by the board on drag release. Resolves the path against placed
  /// words (exact path, forward or reversed), updates state synchronously,
  /// then persists and credits coins on the save chain.
  SelectionResult submitSelection(List<Cell> path) {
    final s = state.valueOrNull;
    if (s == null) return SelectionResult.invalid;

    final match = matchSelection(s.puzzle.placedWords, path);
    if (match == null) {
      unawaited(ref.read(audioProvider).invalidSelection());
      return SelectionResult.invalid;
    }
    if (s.foundWords.contains(match.word)) {
      // No double reward, no error - just neutral feedback.
      return SelectionResult.alreadyFound;
    }

    final found = {...s.foundWords, match.word};
    final revealed = {...s.revealedCells, ...match.cells};
    final puzzleDone = found.length == s.puzzle.placedWords.length;

    final economy = ref.read(economyProvider);
    final spec = s.project.puzzles[s.puzzleIndex];
    var reward = economy.wordReward(match.word);
    if (puzzleDone && !s.puzzleCompleted) {
      reward += economy.puzzleCompletionBonus(spec.difficulty);
    }

    // Derive project completion from this VM's authoritative state plus the
    // other puzzles' saved flags (which this screen never mutates).
    final progressMap = ref.read(progressProvider).valueOrNull ?? const {};
    var progress = progressMap[s.project.id] ??
        ProjectProgress.initial(s.project.id);
    progress = progress.withPuzzle(
      s.puzzleIndex,
      PuzzleProgress(
        seed: s.seed,
        foundWords: found.toList(),
        revealedCells: revealed.toList(),
        completed: puzzleDone,
        hintsUsed: s.hintsUsed,
      ),
    );

    var projectJustCompleted = false;
    if (puzzleDone &&
        !progress.completed &&
        progress.allPuzzlesCompleted(s.project.puzzles.length)) {
      progress = progress.copyWith(completed: true);
      projectJustCompleted = true;
      reward += EconomyService.imageCompletionBonus;
    }

    final audio = ref.read(audioProvider);
    if (projectJustCompleted) {
      unawaited(audio.imageCompleted());
    } else if (puzzleDone) {
      unawaited(audio.puzzleCompleted());
    } else {
      unawaited(audio.wordFound());
    }

    state = AsyncData(s.copyWith(
      foundWords: found,
      revealedCells: revealed,
      puzzleCompleted: puzzleDone,
      projectCompleted: s.projectCompleted || projectJustCompleted,
      lastRewardCoins: reward,
      clearHint: true,
    ));

    final savedProgress = progress;
    final baseReward = reward;
    _saveChain = _saveChain.then((_) async {
      await ref.read(progressProvider.notifier).saveProject(savedProgress);
      var total = baseReward;
      if (projectJustCompleted) {
        final added = await ref.read(galleryProvider.notifier).addOnce(
              GalleryEntry(
                projectId: s.project.id,
                collectionId: s.collectionId,
                name: s.project.name,
                imageRef: s.project.imageRef,
                completedAtMillis: DateTime.now().millisecondsSinceEpoch,
              ),
            );
        if (added && await _isCollectionComplete(s.collectionId)) {
          total += EconomyService.collectionCompletionBonus;
        }
      }
      await ref.read(walletProvider.notifier).earn(total);
    });

    return SelectionResult.found;
  }

  Future<bool> _isCollectionComplete(String collectionId) async {
    final collections = await ref.read(collectionsProvider.future);
    final collection = collections.firstWhere((c) => c.id == collectionId);
    final progressMap = await ref.read(progressProvider.future);
    return collection.projects
        .every((p) => progressMap[p.id]?.completed ?? false);
  }

  /// Spends coins and activates a hint targeting a random unfound word.
  /// Smart hints pick the most useful concrete hint for the board state.
  Future<HintOutcome> useHint(HintType type) async {
    final s = state.valueOrNull;
    if (s == null || s.puzzleCompleted) return HintOutcome.unavailable;
    final unfound = s.unfoundWords;
    if (unfound.isEmpty) return HintOutcome.unavailable;

    var effective = type;
    if (type == HintType.smart) {
      // Few words left: the area pulse is most useful. Many left: knowing
      // a starting letter narrows the search best.
      effective =
          unfound.length <= 2 ? HintType.highlight : HintType.letter;
    }

    final paid = await ref.read(walletProvider.notifier).spend(type.cost);
    if (!paid) return HintOutcome.insufficientCoins;

    final current = state.valueOrNull;
    if (current == null) return HintOutcome.unavailable;
    final target = unfound[_rng.nextInt(unfound.length)];
    final hintsUsed = current.hintsUsed + 1;

    unawaited(ref.read(audioProvider).hintUsed());
    state = AsyncData(current.copyWith(
      hintsUsed: hintsUsed,
      activeHint: HintEffect(effective, target),
    ));

    // Persist the hint count.
    final progressMap = ref.read(progressProvider).valueOrNull ?? const {};
    var progress = progressMap[current.project.id] ??
        ProjectProgress.initial(current.project.id);
    progress = progress.withPuzzle(
      current.puzzleIndex,
      PuzzleProgress(
        seed: current.seed,
        foundWords: current.foundWords.toList(),
        revealedCells: current.revealedCells.toList(),
        completed: current.puzzleCompleted,
        hintsUsed: hintsUsed,
      ),
    );
    final savedProgress = progress;
    _saveChain = _saveChain.then(
        (_) => ref.read(progressProvider.notifier).saveProject(savedProgress));

    return HintOutcome.applied;
  }

  void clearHint() {
    final s = state.valueOrNull;
    if (s == null || s.activeHint == null) return;
    state = AsyncData(s.copyWith(clearHint: true));
  }
}

final puzzleVmProvider = AsyncNotifierProvider.autoDispose
    .family<PuzzleVm, PuzzleState, PuzzleArgs>(PuzzleVm.new);
