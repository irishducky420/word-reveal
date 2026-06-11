import 'package:hive/hive.dart';

/// Thin wrapper around the Hive boxes used by the game. All structured
/// state is stored as JSON strings, so no TypeAdapters/codegen are needed
/// and models stay plain Dart.
///
/// In the app, call `Hive.initFlutter()` (hive_flutter) before [open].
/// In tests, call `Hive.init(tempDir)` instead.
class LocalStore {
  static const String progressBoxName = 'progress';
  static const String walletBoxName = 'wallet';
  static const String galleryBoxName = 'gallery';
  static const String metaBoxName = 'meta';

  final Box<String> progress;
  final Box<String> wallet;
  final Box<String> gallery;
  final Box<String> meta;

  const LocalStore._({
    required this.progress,
    required this.wallet,
    required this.gallery,
    required this.meta,
  });

  static Future<LocalStore> open() async {
    return LocalStore._(
      progress: await Hive.openBox<String>(progressBoxName),
      wallet: await Hive.openBox<String>(walletBoxName),
      gallery: await Hive.openBox<String>(galleryBoxName),
      meta: await Hive.openBox<String>(metaBoxName),
    );
  }
}
