import 'dart:convert';

import 'package:hive/hive.dart';

/// P2 interface. The game is offline-first: all progress lives in Hive and
/// snapshots are pushed through this interface after meaningful changes.
///
/// Swapping in a real backend = implement this interface in one class
/// (REST/Firebase/whatever) and change `cloudSaveProvider` in
/// lib/app/providers.dart. Nothing else in the app knows the difference.
abstract class CloudSaveService {
  Future<void> uploadSnapshot(Map<String, dynamic> snapshot);
  Future<Map<String, dynamic>?> downloadSnapshot();
}

/// Local implementation: persists the snapshot into the meta box. Gives the
/// full save/restore code path real exercise without a server.
class LocalCloudSaveService implements CloudSaveService {
  static const String _key = 'cloud_snapshot';
  final Box<String> _meta;

  LocalCloudSaveService(this._meta);

  @override
  Future<void> uploadSnapshot(Map<String, dynamic> snapshot) async {
    await _meta.put(_key, jsonEncode(snapshot));
  }

  @override
  Future<Map<String, dynamic>?> downloadSnapshot() async {
    final raw = _meta.get(_key);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }
}
