# Word Reveal: Hidden Masterpieces

A word-search puzzle game where every found word paints part of a hidden
picture, and the picture completes across multiple puzzles. Flutter,
iOS + Android + tablet, portrait.

**Status: Phase 1 — playable vertical slice (P0) complete.**

## Setup

```bash
flutter pub get
```

No code generation step: models and providers are hand-written (see
"Stack notes" below).

## Run

```bash
flutter run                      # attached device or simulator
flutter run -d ios               # iOS simulator
flutter run -d android           # Android emulator
```

## Test

```bash
flutter test                     # full suite
flutter test test/puzzle_engine  # engine stress tests only (6000 boards)
```

The engine and reveal-math algorithms were additionally verified outside
Flutter with a line-for-line port: 6,000 randomized boards across all six
difficulties plus 4,500 seeded generations of the shipped content, zero
failures; tile-edge math confirmed bitwise-exact.

## Release builds

```bash
flutter build apk --release          # Android APK
flutter build appbundle --release    # Play Store bundle
flutter build ipa --release          # iOS (requires Xcode + signing)
```

Note: `android/` and `ios/` platform folders are created by
`flutter create .` (run once in the project root) — they are
machine-generated and intentionally not part of this source delivery.

## What's in the slice

- Puzzle generation engine: 8 directions, overlap-friendly, seeded/
  deterministic, regenerate-on-failure, never drops a word.
- Word-search board: drag selection along the 8 directions, live highlight,
  invalid-selection shake, multi-touch safe, 60 FPS layering (selection
  repaints alone; the grid repaints only when a word is found).
- Progressive image reveal: each found word's cells fade/scale in image
  tiles; regions accumulate across puzzles; completing the last puzzle
  completes the masterpiece, with a celebration and a gallery entry.
- One complete sample collection (*Wildlife*): 3 pictures x 3 puzzles,
  vector master art, themed word lists.
- Persistence: Hive, auto-save after every meaningful change, mid-puzzle
  resume via stored seeds. Offline-first with a cloud-save interface.
- Economy: one wallet, word/puzzle/image/collection rewards, four hint
  types + smart hint, hard invariants (never negative, no double rewards).

## Stack notes (deviations stated per brief rule 5)

- **No codegen.** The brief pins `freezed`/`json_serializable`/
  `riverpod_annotation`. This delivery hand-writes the (small) immutable
  models and declares Riverpod providers explicitly, so the project
  compiles with `flutter pub get` alone and every line is auditable.
  The domain API is shaped exactly as freezed would shape it
  (`copyWith`/`toJson`/`fromJson`), so migrating to codegen later is
  mechanical and changes no call sites.
- **Audio** uses platform haptics/system feedback behind an `AudioService`
  interface (no licensed sound assets exist yet). Swap = one class.
- **`shared_preferences`** is omitted; the Hive `meta` box covers small
  flags, keeping one structured store everywhere.
- **Unlock policy** (assumption): pictures unlock sequentially within a
  collection, and puzzles sequentially within a picture, so the image
  paints in order.

## Layout

See the build brief's Section 3 — the folder structure matches it.
`lib/domain/` and `lib/services/puzzle_engine/` have zero Flutter imports.

Further docs:
- `docs/CONTENT_GUIDE.md` — JSON schema, art spec, how to add a collection.
- `docs/REAL_VS_INTERFACE.md` — what's fully built vs. interface, swap
  points, and the expansion roadmap.
