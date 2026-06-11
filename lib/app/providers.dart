import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/asset_content_repository.dart';
import '../data/repositories/hive_repositories.dart';
import '../data/sources/local/local_store.dart';
import '../data/sources/remote/cloud_save_service.dart';
import '../domain/models/content.dart';
import '../domain/models/progress.dart';
import '../domain/models/wallet.dart';
import '../domain/repositories/repositories.dart';
import '../services/audio/audio_service.dart';
import '../services/economy/economy_service.dart';
import '../services/puzzle_engine/puzzle_generator.dart';

/// Overridden with the opened store in main(); throwing here makes a
/// missed override fail loudly at startup instead of silently.
final localStoreProvider = Provider<LocalStore>(
    (ref) => throw UnimplementedError('Override localStoreProvider in main()'));

final puzzleGeneratorProvider = Provider<PuzzleGenerator>((ref) => PuzzleGenerator());
final economyProvider = Provider<EconomyService>((ref) => EconomyService());
final audioProvider = Provider<AudioService>((ref) => SystemFeedbackAudioService());

final contentRepositoryProvider =
    Provider<ContentRepository>((ref) => AssetContentRepository());
final progressRepositoryProvider = Provider<ProgressRepository>(
    (ref) => HiveProgressRepository(ref.watch(localStoreProvider).progress));
final walletRepositoryProvider = Provider<WalletRepository>(
    (ref) => HiveWalletRepository(ref.watch(localStoreProvider).wallet));
final galleryRepositoryProvider = Provider<GalleryRepository>(
    (ref) => HiveGalleryRepository(ref.watch(localStoreProvider).gallery));
final cloudSaveProvider = Provider<CloudSaveService>(
    (ref) => LocalCloudSaveService(ref.watch(localStoreProvider).meta));

final collectionsProvider = FutureProvider<List<GameCollection>>(
    (ref) => ref.watch(contentRepositoryProvider).loadCollections());

/// ---- Wallet ----------------------------------------------------------

class WalletNotifier extends AsyncNotifier<Wallet> {
  @override
  Future<Wallet> build() => ref.watch(walletRepositoryProvider).load();

  Future<void> earn(int amount) async {
    if (amount == 0) return;
    final wallet = await future;
    final updated = ref.read(economyProvider).earn(wallet, amount);
    await ref.read(walletRepositoryProvider).save(updated);
    state = AsyncData(updated);
  }

  /// Returns false (and changes nothing) if the balance is insufficient.
  Future<bool> spend(int amount) async {
    final wallet = await future;
    final updated = ref.read(economyProvider).spend(wallet, amount);
    if (updated == null) return false;
    await ref.read(walletRepositoryProvider).save(updated);
    state = AsyncData(updated);
    return true;
  }
}

final walletProvider =
    AsyncNotifierProvider<WalletNotifier, Wallet>(WalletNotifier.new);

/// ---- Project progress (single source of truth) ------------------------

class ProgressNotifier extends AsyncNotifier<Map<String, ProjectProgress>> {
  @override
  Future<Map<String, ProjectProgress>> build() =>
      ref.watch(progressRepositoryProvider).loadAll();

  Future<void> saveProject(ProjectProgress progress) async {
    await ref.read(progressRepositoryProvider).save(progress);
    final current = await future;
    state = AsyncData({...current, progress.projectId: progress});
    await _pushCloudSnapshot();
  }

  /// Offline-first cloud sync: push a full snapshot after every save.
  /// LocalCloudSaveService makes this a real, exercised code path today.
  Future<void> _pushCloudSnapshot() async {
    final progress = await future;
    final wallet = await ref.read(walletProvider.future);
    await ref.read(cloudSaveProvider).uploadSnapshot({
      'savedAtMillis': DateTime.now().millisecondsSinceEpoch,
      'wallet': wallet.toJson(),
      'progress': {
        for (final e in progress.entries) e.key: e.value.toJson()
      },
    });
  }
}

final progressProvider =
    AsyncNotifierProvider<ProgressNotifier, Map<String, ProjectProgress>>(
        ProgressNotifier.new);

/// ---- Gallery -----------------------------------------------------------

class GalleryNotifier extends AsyncNotifier<List<GalleryEntry>> {
  @override
  Future<List<GalleryEntry>> build() =>
      ref.watch(galleryRepositoryProvider).load();

  /// Returns true if the entry was newly added (exactly-once semantics
  /// are enforced again at the repository level).
  Future<bool> addOnce(GalleryEntry entry) async {
    final added = await ref.read(galleryRepositoryProvider).addOnce(entry);
    if (added) {
      state = AsyncData(await ref.read(galleryRepositoryProvider).load());
    }
    return added;
  }
}

final galleryProvider =
    AsyncNotifierProvider<GalleryNotifier, List<GalleryEntry>>(
        GalleryNotifier.new);
