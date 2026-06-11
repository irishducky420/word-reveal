import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:word_reveal/data/repositories/hive_repositories.dart';
import 'package:word_reveal/data/sources/local/local_store.dart';
import 'package:word_reveal/data/sources/remote/cloud_save_service.dart';
import 'package:word_reveal/domain/models/cell.dart';
import 'package:word_reveal/domain/models/progress.dart';
import 'package:word_reveal/domain/models/wallet.dart';
import 'package:word_reveal/services/economy/economy_service.dart';

void main() {
  late Directory tempDir;
  late LocalStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('word_reveal_test');
    Hive.init(tempDir.path);
    store = await LocalStore.open();
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProjectProgress sampleProgress() => ProjectProgress(
        projectId: 'fox',
        puzzles: {
          0: const PuzzleProgress(
            seed: 12345,
            foundWords: ['FOX', 'TAIL'],
            revealedCells: [Cell(0, 1), Cell(0, 2), Cell(3, 4)],
            completed: false,
            hintsUsed: 2,
          ),
          1: const PuzzleProgress(seed: 999, completed: true),
        },
        completed: false,
      );

  test('project progress round-trips through Hive intact', () async {
    final repo = HiveProgressRepository(store.progress);
    await repo.save(sampleProgress());

    final loaded = await repo.load('fox');
    expect(loaded, isNotNull);
    expect(loaded!.projectId, 'fox');
    expect(loaded.puzzles[0]!.seed, 12345);
    expect(loaded.puzzles[0]!.foundWords, ['FOX', 'TAIL']);
    expect(loaded.puzzles[0]!.revealedCells,
        const [Cell(0, 1), Cell(0, 2), Cell(3, 4)]);
    expect(loaded.puzzles[0]!.hintsUsed, 2);
    expect(loaded.puzzles[1]!.completed, isTrue);
    expect(loaded.completed, isFalse);
  });

  test('mid-puzzle resume: seed + found words survive a "restart"', () async {
    // Simulates close/reopen: a second repository over the same box must
    // see exactly what the first one saved.
    final repo1 = HiveProgressRepository(store.progress);
    await repo1.save(sampleProgress());

    final repo2 = HiveProgressRepository(store.progress);
    final resumed = await repo2.load('fox');
    expect(resumed!.puzzles[0]!.seed, 12345,
        reason: 'the seed must regenerate the identical board on resume');
    expect(resumed.puzzles[0]!.foundWords.length, 2);
  });

  test('loadAll returns every saved project', () async {
    final repo = HiveProgressRepository(store.progress);
    await repo.save(sampleProgress());
    await repo.save(ProjectProgress.initial('owl'));
    final all = await repo.loadAll();
    expect(all.keys.toSet(), {'fox', 'owl'});
  });

  test('wallet round-trips and first load grants starting coins once',
      () async {
    final repo = HiveWalletRepository(store.wallet);
    final first = await repo.load();
    expect(first.coins, EconomyService.startingCoins);

    await repo.save(const Wallet(coins: 777, lifetimeEarned: 1000));
    final loaded = await repo.load();
    expect(loaded.coins, 777);
    expect(loaded.lifetimeEarned, 1000,
        reason: 'starting grant must not re-apply over a saved wallet');
  });

  test('gallery addOnce is exactly-once per project', () async {
    final repo = HiveGalleryRepository(store.gallery);
    final entry = GalleryEntry(
      projectId: 'fox',
      collectionId: 'wildlife',
      name: 'Red Fox',
      imageRef: 'painter:fox',
      completedAtMillis: 1700000000000,
    );
    expect(await repo.addOnce(entry), isTrue);
    expect(await repo.addOnce(entry), isFalse,
        reason: 'completing a project twice must not duplicate the artwork');
    final entries = await repo.load();
    expect(entries.length, 1);
    expect(entries.single.name, 'Red Fox');
  });

  test('cloud snapshot round-trips through the local implementation',
      () async {
    final cloud = LocalCloudSaveService(store.meta);
    expect(await cloud.downloadSnapshot(), isNull);
    final snapshot = {
      'savedAtMillis': 123,
      'wallet': const Wallet(coins: 5, lifetimeEarned: 9).toJson(),
      'progress': {'fox': sampleProgress().toJson()},
    };
    await cloud.uploadSnapshot(snapshot);
    final restored = await cloud.downloadSnapshot();
    expect(restored, isNotNull);
    expect(restored!['savedAtMillis'], 123);
    final wallet = Wallet.fromJson(
        (restored['wallet'] as Map).cast<String, dynamic>());
    expect(wallet.coins, 5);
    final progress = ProjectProgress.fromJson(
        ((restored['progress'] as Map)['fox'] as Map).cast<String, dynamic>());
    expect(progress.puzzles[0]!.seed, 12345);
  });
}
