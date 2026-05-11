---
description: Run the test suite (or a filtered subset) on the iPhone 17 Pro simulator
---

Run tests against the `SkeenaSystem` scheme. If the user passed arguments, treat them as a filter:
- A role name (`angler`, `guide`, `researcher`, `public`) → run only `SkeenaSystemTests/<Role>/` via `-only-testing:SkeenaSystemTests/<Role>`
- A class name (e.g. `DarkPageTemplateTests`) → use `-only-testing:SkeenaSystemTests/DarkPageTemplateTests`
- A specific test (e.g. `CatchFlowRegressionTests/testFooBar`) → pass it through `-only-testing:` unchanged
- `ui` or `UITests` → run the UI test plan: append `-testPlan UITests`
- A filter starting with `SkeenaSystemUITests/...` → pass it through `-only-testing:` unchanged (this is a UI test run)
- No arguments → run the full suite

Base command:

```bash
xcodebuild -workspace SkeenaSystem.xcworkspace \
  -scheme SkeenaSystem \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

Note: `SkeenaSystem` is the scheme, `DevTEST` is a build configuration that the scheme already selects for the Test action. Do NOT pass `-scheme DevTEST` — xcodebuild will fail.

Append `-only-testing:...` flags when a filter is given.

## UI test pre-flight

If the run is a UI test run (filter is `ui` / `UITests`, or starts with `SkeenaSystemUITests/`, or `-testPlan UITests` is being used), run this pre-flight **before** `xcodebuild test` so iOS doesn't pop the "Save Password?" sheet after the UI test logs in:

```bash
# Boot iPhone 17 Pro if not already booted (no-op if booted)
xcrun simctl bootstatus "iPhone 17 Pro" -b >/dev/null 2>&1 || xcrun simctl boot "iPhone 17 Pro"

# Disable AutoFill / Save Password prompt on the booted sim (per-UDID, idempotent)
xcrun simctl spawn booted defaults write com.apple.AutoFillSettings AutoFillCredentialsEnabled -bool false
```

The setting is per-simulator-UDID, so re-run it whenever a UI test run targets a fresh or erased sim. Skip this for unit-test-only runs — there's no login flow, no prompt to suppress.

After the run:
1. Report pass/fail counts.
2. For any failure, show the assertion message and the file:line — not the full xcodebuild stack.
3. If a test crashes with a malloc "pointer being freed was not allocated" error, suspect the `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + `swift_task_deinitOnExecutorMainActorBackDeploy` interaction on iOS 26.2 sim. See the CLAUDE.md rule about marking service classes `nonisolated`.
4. Do NOT automatically fix failures. Ask the user first unless they already told you to.

Arguments: $ARGUMENTS
