/// Abstract repository contracts. Pure Dart - no Flutter imports.
/// Concrete implementations live in lib/data/repositories/.
library;

import '../models/content.dart';
import '../models/progress.dart';
import '../models/wallet.dart';

abstract class ContentRepository {
  Future<List<GameCollection>> loadCollections();
}

abstract class ProgressRepository {
  Future<ProjectProgress?> load(String projectId);
  Future<Map<String, ProjectProgress>> loadAll();
  Future<void> save(ProjectProgress progress);
}

abstract class WalletRepository {
  Future<Wallet> load();
  Future<void> save(Wallet wallet);
}

abstract class GalleryRepository {
  Future<List<GalleryEntry>> load();

  /// Adds [entry] unless an entry for the same projectId already exists.
  /// Returns true if it was added (enforces "written exactly once").
  Future<bool> addOnce(GalleryEntry entry);
}
