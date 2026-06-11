import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:word_reveal/app/app.dart';
import 'package:word_reveal/app/providers.dart';
import 'package:word_reveal/data/sources/local/local_store.dart';

/// App-level smoke test: boots the real widget tree on a fresh store and
/// checks the home screen renders the sample collection.
void main() {
  late Directory tempDir;
  late LocalStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('word_reveal_smoke');
    Hive.init(tempDir.path);
    store = await LocalStore.open();
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('home screen shows the Wildlife collection and the wallet',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(store)],
        child: const WordRevealApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Word Reveal'), findsOneWidget);
    expect(find.text('Wildlife'), findsOneWidget);
    expect(find.text('120'), findsOneWidget); // starting coins
  });
}
