# Real vs. Interface Map

## Fully real (P0 — no stubs, no TODOs)

| System | Where |
|---|---|
| Puzzle generation engine (seeded, 8-direction, regen-on-failure) | `lib/services/puzzle_engine/puzzle_generator.dart` |
| Path-based selection matching (forward + reversed) | `lib/services/puzzle_engine/path_match.dart` |
| Region partition + exact tile math | `lib/domain/models/region.dart` |
| Board, drag input, reveal/invalid/hint animations | `lib/features/word_search/board_widget.dart` |
| Cross-puzzle reveal accumulation + project thumbnail | `lib/features/reveal/project_thumbnail.dart` |
| Vector master art + raster image support | `lib/features/reveal/master_art.dart` |
| Gameplay orchestration (rewards, completion, gallery write) | `lib/features/word_search/puzzle_viewmodel.dart` |
| Coin economy + 5 hint types | `lib/services/economy/economy_service.dart` |
| Hive persistence, auto-save, mid-puzzle resume | `lib/data/` |
| Sample Wildlife collection (3 pictures x 3 puzzles) | `assets/content/wildlife.json` |
| Navigation (collections → picture → puzzle → gallery) | `lib/app/router/app_router.dart` |

## Interfaces with working local implementations

| Interface | Local impl today | Swap point |
|---|---|---|
| `CloudSaveService` | `LocalCloudSaveService` (Hive `meta` box; exercised on every save) | `cloudSaveProvider` in `lib/app/providers.dart` |
| `AudioService` | `SystemFeedbackAudioService` (haptics/system sounds) | `audioProvider` in `lib/app/providers.dart` |
| `ContentRepository` | `AssetContentRepository` (bundled JSON) | `contentRepositoryProvider` — a remote-content repo implements the same contract |

Each swap is: write one class implementing the interface, change one
provider line. Nothing else in the app knows.

## Not yet built (P1/P2, by design)

P1: profile/XP/levels, full gallery share, daily challenge (engine is
ready — seed from the date), achievements, settings screen, explicit
colorblind palette toggle. P2: `AdService` + no-op, `IapService` + mock,
`AnalyticsService` + console logger, l10n arb extraction.

## Expansion roadmap (realistic)

1. **Content scaling** — the big one, and it's an asset task: more
   collections are JSON + images per `docs/CONTENT_GUIDE.md`. Raster
   support already works, so commissioned/licensed art drops straight in.
2. **Phase 2 (product shell)** — profile/XP, daily challenge
   (`generate(config, seed: dateSeed)` exists), achievements, settings;
   all consume events the gameplay layer already emits (words found,
   puzzles/images completed, streaks from save timestamps).
3. **Phase 3 (commerce)** — implement the three P2 interfaces against real
   SDKs and a backend; flows are already routed through providers, so this
   is additive.
