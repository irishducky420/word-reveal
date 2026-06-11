import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../domain/models/content.dart';
import '../../domain/repositories/repositories.dart';

/// Loads collections from bundled JSON. `assets/content/index.json` lists
/// the collection files, so adding a collection is an asset change only -
/// no engine code is touched (see docs/CONTENT_GUIDE.md).
class AssetContentRepository implements ContentRepository {
  final AssetBundle _bundle;
  List<GameCollection>? _cache;

  AssetContentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  @override
  Future<List<GameCollection>> loadCollections() async {
    if (_cache != null) return _cache!;
    final index = jsonDecode(
            await _bundle.loadString('assets/content/index.json'))
        as Map<String, dynamic>;
    final files = [for (final f in index['collections'] as List) f as String];
    final collections = <GameCollection>[];
    for (final file in files) {
      final raw = await _bundle.loadString('assets/content/$file');
      collections.add(
          GameCollection.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    }
    return _cache = collections;
  }
}
