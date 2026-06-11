# Content Guide

Collections are **data**, not code. The engine reads any number of
collections from `assets/content/`; scaling to 20 collections is an asset
task, not an engineering one.

## Adding a collection (walkthrough)

1. Create `assets/content/<id>.json` (schema below).
2. Add the filename to `assets/content/index.json`:
   ```json
   { "collections": ["wildlife.json", "landmarks.json"] }
   ```
3. Provide the master image for each project (see "Master images").
4. `flutter run`. Done — no engine code changes.

## Collection JSON schema

```json
{
  "id": "wildlife",                  // unique, stable; used as a save key
  "name": "Wildlife",
  "description": "Paint the wild, one word at a time.",
  "projects": [
    {
      "id": "fox",                   // unique across ALL collections (save key)
      "name": "Red Fox",
      "imageRef": "painter:fox",     // or "asset:assets/images/fox.webp"
      "puzzles": [
        { "difficulty": "beginner", "words": ["FOX", "DEN", "TAIL"] }
      ]
    }
  ]
}
```

- `difficulty` ∈ `beginner|easy|medium|hard|expert|master`
  → grids 8/10/12/16/20/24.
- `puzzles` are ordered; they unlock sequentially and each paints one
  region of the master image. Region layout is automatic: the most square
  factorization of the puzzle count (4 → 2x2 quadrants, 6 → 2x3, 9 → 3x3),
  horizontal bands for primes (3 → three bands, 5 → five bands).
  **3–5 puzzles per picture plays best.**

## Word-list rules (enforced by the engine — violations throw at load)

- Letters A–Z only after normalization (case and punctuation are stripped:
  `"t-rex"` → `TREX`).
- No word longer than the puzzle's grid size.
- Total letters ≤ ~50% of grid cells (engine hard-rejects > 60%).
  Comfortable budgets: 8x8 → ≤32 letters, 10x10 → ≤50, 12x12 → ≤72.
- Duplicates are deduped silently. Theme words to the picture: the reveal
  is the reward, and words that describe what's appearing feel magical.

## Master images

### Vector (`painter:<id>`) — what the slice ships
`MasterArt` subclasses in `lib/features/reveal/master_art.dart`, drawn in a
unit [0..1]² space. Register new art in `MasterArtRegistry._painters`.
Resolution-independent, zero licensing, crisp at any tile size.

### Raster (`asset:<path>`) — drop-in, already implemented
Bundle a PNG/WebP under `assets/`, declare it in `pubspec.yaml`, and use
`"imageRef": "asset:assets/images/fox.webp"`. `RasterImageSource` decodes
and slices it with the same tile math. **No code change.**

### Authoring requirements (both kinds)
- **Square (1:1).** Regions and tiles assume it.
- **Bold, high-contrast shapes.** A single cell shows ~1/100th of a region;
  large color fields read well, fine texture reads as noise.
- **No critical detail at region borders** — a region boundary may sit
  unrevealed next to a revealed neighbor for a long time.
- Recommended raster size: 1024–2048 px square, WebP.
- Keep contrast acceptable under the grey-out (unpainted tiles are
  near-opaque grey in the project thumbnail).
