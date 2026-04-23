---
description: Walk through adding a new species class to the iOS app after an ML retrain
---

The human-readable playbook lives at [`docs/new-species-onboarding.md`](../../docs/new-species-onboarding.md) — read it before starting. This slash command is the execution wrapper.

Target species (from $ARGUMENTS, or ask the user if missing): **$ARGUMENTS**

## Step 0 — Confirm prerequisites before touching anything

Ask the user (or check if already stated):

1. Has the ML agent retrained and re-exported **both** `~/dev/MadThinkerML/models/ViTFishSpecies.mlpackage` **and** `~/dev/MadThinkerML/models/LengthRegressor.mlmodel`? The regressor retrain is not optional — `species_index` is a regressor input feature, and alphabetical insertion shifts every subsequent index.
2. What's the new label's position in Python `ImageFolder` alphabetical order? (This determines its array index. **Not** the end of the list.)
3. What was the val accuracy and training-image count for the new class? Flag as a weak class in the commit message if accuracy < 70% or image count < ~100.

If any of #1 is missing, **STOP.** Updating code against a half-baked model produces silent misclassification.

## Step 1 — Feature branch + copy artifacts

```bash
git checkout main && git pull
git checkout -b species-<new-class>-expansion
rm -rf SkeenaSystem/Models/ViTFishSpecies.mlpackage
cp -R  ~/dev/MadThinkerML/models/ViTFishSpecies.mlpackage SkeenaSystem/Models/
cp     ~/dev/MadThinkerML/models/LengthRegressor.mlmodel  SkeenaSystem/Models/
```

`.mlpackage` is a directory bundle — `cp -R` is required. The project uses Xcode 16 file-system-synchronized groups, so the artifacts auto-register with the app target.

## Step 2 — `speciesLabels` in [`SkeenaSystem/Managers/CatchPhotoAnalyzer.swift`](../../SkeenaSystem/Managers/CatchPhotoAnalyzer.swift)

Insert the new label in its alphabetical position. If the label uses the `<species>_<lifecycle>` pattern, confirm the lifecycle suffix is `holding` or `traveler` — `splitSpecies()` only recognizes those two. Any other suffix needs a parser update.

## Step 3 — `regressorBypassSpecies` (same file, **two occurrences**)

Use `replace_all` on the `Edit`. Add the new species to the bypass set — the LengthRegressor has no calibrated length data for it until real catches with measured lengths exist. Heuristic fallback applies until then.

## Step 4 — `speciesDisplayNames` in [`SkeenaSystem/ViewModels/CatchChatViewModel.swift`](../../SkeenaSystem/ViewModels/CatchChatViewModel.swift)

Key is the lowercased, **underscore-stripped** species prefix (no lifecycle stage). Value is the user-facing display name. Example: `"coho salmon": "Coho Salmon"`.

## Step 5 — `speciesLengthRanges` (usually leave alone)

Do **not** add the new species to `speciesLengthRanges` unless you have calibrated length data. Both lookup sites use `if let` — missing keys fall back to the default heuristic clamp, which is correct.

## Step 6 — Preprocessing sanity check (should already be correct)

Verify `runViT` in `CatchPhotoAnalyzer.swift` passes `mean: [0.5, 0.5, 0.5], std: [0.5, 0.5, 0.5]` (Inception-style, timm default for `vit_tiny_patch16_224`). If it's defaulting to ImageNet norms, the species model will silently misfire. This was fixed in commit `ad51607` — shouldn't regress, but worth a glance.

## Step 7 — Bi-catch UX preservation

The `other` class has custom UX: display name is `"Bi-catch"`, sex is suppressed to `"-"`, and the researcher flow has a tail-message branching (`identificationPrompt()` in `ResearcherCatchFlowManager.swift`) that asks the user to name the species when species is currently Bi-catch, or to optionally provide sex after they correct it. Don't break this when adding new classes.

## Step 8 — Build + sim verification

Run `/build` (or `xcodebuild` per `CLAUDE.md`). Then on the sim:

| Input | Expected |
|-------|----------|
| Known steelhead photo | `steelhead_*` with high confidence — regression sentinel |
| New class photo | New label, moderate-to-high confidence, heuristic length path |
| OOD / exotic fish | `other` → "Bi-catch" display |

Confirm the regressor bypass engaged by grepping Console for `Using species-scaled heuristic for <species> (regressor not yet calibrated)`.

## Step 9 — Sync check + commit

Read both `speciesLabels` and `speciesDisplayNames` and verify:

- Every `speciesLabels` entry has a corresponding key in `speciesDisplayNames` (or explicitly bypasses via lifecycle-stripping).
- No stale `speciesDisplayNames` keys that no longer exist in `speciesLabels`.

Then stage, commit, push the feature branch. Hold off on merging to main until the user confirms sim verification.

## Step 10 — Summarize

Give the user a one-paragraph summary including:

- Which classes shifted indices.
- New class's val accuracy + training image count (from Step 0).
- Whether the new species is in `regressorBypassSpecies` (yes until calibrated length data exists).
- Any gotchas you hit.
