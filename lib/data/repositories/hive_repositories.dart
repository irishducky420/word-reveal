import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/models/progress.dart';
import '../../domain/models/wallet.dart';
import '../../domain/repositories/repositories.dart';
import '../../services/economy/economy_service.dart';

class HiveProgressRepository implements ProgressRepository {
  final Box<String> _box;
  HiveProgressRepository(this._box);

  @override
  Future<ProjectProgress?> load(String projectId) async {
    final raw = _box.get(projectId);
    if (raw == null) return null;
    return ProjectProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<Map<String, ProjectProgress>> loadAll() async {
    final result = <String, ProjectProgress>{};
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw != null) {
        result[key as String] =
            ProjectProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    }
    return result;
  }

  @override
  Future<void> save(ProjectProgress progress) =>
      _box.put(progress.projectId, jsonEncode(progress.toJson()));
}

class HiveWalletRepository implements WalletRepository {
  static const String _key = 'wallet';
  final Box<String> _box;
  HiveWalletRepository(this._box);

  @override
  Future<Wallet> load() async {
    final raw = _box.get(_key);
    if (raw == null) {
      // First launch: grant starting coins exactly once, persisted
      // immediately so a crash cannot re-grant them.
      const wallet = Wallet(
        coins: EconomyService.startingCoins,
        lifetimeEarned: EconomyService.startingCoins,
      );
      await save(wallet);
      return wallet;
    }
    return Wallet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(Wallet wallet) => _box.put(_key, jsonEncode(wallet.toJson()));
}

class HiveGalleryRepository implements GalleryRepository {
  static const String _key = 'entries';
  final Box<String> _box;
  HiveGalleryRepository(this._box);

  @override
  Future<List<GalleryEntry>> load() async {
    final raw = _box.get(_key);
    if (raw == null) return const [];
    return [
      for (final e in jsonDecode(raw) as List)
        GalleryEntry.fromJson(e as Map<String, dynamic>)
    ];
  }

  @override
  Future<bool> addOnce(GalleryEntry entry) async {
    final entries = await load();
    if (entries.any((e) => e.projectId == entry.projectId)) return false;
    await _box.put(
        _key, jsonEncode([for (final e in [...entries, entry]) e.toJson()]));
    return true;
  }
}
