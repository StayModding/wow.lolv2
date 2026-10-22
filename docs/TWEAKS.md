# Tweaks: what each switch actually does

`TweakCatalog` (in `WowIos/Core/Tweak.swift`) is the single list. `AppSettings` persists the enabled set, and `AppSettings.theme` collapses it into a `Theme` value that the whole UI reads through the `\.theme` environment key. Flipping a switch re-resolves the theme, so chrome changes are live — no relaunch.

## Killing Liquid Glass in three layers

iOS 26+ draws Liquid Glass in system views the app does not own. You cannot "turn it off" with a runtime switch from inside a sandboxed app, so wow-ios attacks it in the three places an app legitimately can:

1. **Opt out of the redesign** — `UIDesignRequiresCompatibility = true` in `Info.plist`. The system renders the pre-26 chrome for this process, which is the closest thing to an official "no Liquid Glass" flag. Set it to `false` to compare.
2. **Fill in behind everything the app owns** — `ChromeSurface` stops asking for `.ultraThinMaterial` and paints `theme.surface` instead, with a hairline stroke standing in for the glass edge. `ChromeBars` does the same to the navigation bar and tab bar. Visually there is no glass left, and the hairlines keep the layering readable so flat chrome doesn't look unfinished.
3. **Everything else is SpringBoard's** — Dock, Control Center, notifications, system apps. Those views live in another process. wow-ios writes an injection profile rather than shipping a toggle that silently does nothing.

That is why three chrome tweaks are `scope: .injection`: they are honestly labelled, and you can see exactly which side of the line they fall on.

## The app-local tweaks

| Tweak | Effect in code |
|---|---|
| Neutralize Liquid Glass | `Theme.flatChrome` → `ChromeSurface` / `ChromeBars` fill with `Theme.surface`, plus the plist opt-out above |
| Kill bar blur | `Theme.killBarBlur` → solid `Theme.solidChrome` under nav/tab bars, scroll-edge fog included |
| High-contrast hairlines | `Theme.hairline` 10% → 55% white, width 0.5 → 1 |
| Square corners | `Theme.radius`/`cardRadius` → 2pt |
| No motion | `Theme.animation`/`spring` → `nil`; preset wallpapers render a still frame |
| Compact density | `Theme.rowSpacing`/`sectionSpacing` shrink ~40% |
| AMOLED black | `Theme.bg` → `.black`, surfaces drop to 3.5–6% white |
| Mint accent | `Theme.accent` ⇄ `accentSecondary` |
| Safe-area guides | `LockScreenGuides` overlays clock, status icons and a dashed content frame on previews |
| Loop by default | `AVPlayerLooper` instead of single playback |
| Pause loops in Low Power Mode | `ProcessInfo.isLowPowerModeEnabled` + `NSProcessInfoPowerStateDidChange` observer pauses/resumes the player layer |
| Auto-convert MP4 to Live Photo | Import path runs `LivePhotoBuilder` straight away instead of offering the raw clip |
| Auto-trim to 3 seconds | Trim window pre-set from `Settings → Burst length` |
| Keep source resolution | `LivePhotoOptions.maxDimension = nil` → `AVAssetImageGenerator.maximumSize` unlimited; transcode stays passthrough (bit-identical frames) |
| Strip metadata | Export rewrites the container with an empty metadata array — GPS/device tags gone, encoded frames untouched |
| Auto-connect on launch | `RootView.task` reconnects to the last host:port |

## The injection tweaks

`System-wide glass off` and `Dock glass off` are `scope: .injection`. Toggling them changes the exported profile, nothing on the device. Export from the Tweaks tab:

```json
{
  "app": "wow-ios",
  "profileVersion": 1,
  "generatedAt": "2026-10-22T17:40:00Z",
  "targets": [
    {
      "process": "SpringBoard",
      "tweaks": [
        { "id": "systemGlassOff", "enabled": true, "effect": "set UIChromeGlassEnabled=false" },
        { "id": "dockGlassOff", "enabled": true, "effect": "set DockBackgroundMaterial=none" }
      ]
    }
  ],
  "appTweaks": ["autoLivePhoto", "autoTrimThreeSeconds", "killBarBlur", "keepSourceResolution", "loopDefault", "neutralizeGlass", "pauseLoopOnLowPower"]
}
```

Your dev VPN / injection loader reads the profile, applies the system patches, and can use `appTweaks` to mirror the same look inside the app. wow-ios never patches SpringBoard itself and never claims to.

## Adding a tweak

1. Add a case to `TweakID`.
2. Add a `Tweak` row in `TweakCatalog.all` (group, scope, `defaultOn`).
3. Either map it into `AppSettings.theme` (visual) or branch on `settings.isOn(...)` where the pipeline runs.
4. If it is `scope: .injection`, add it to `AppSettings.injectionProfile()` so the loader sees it.

The Tweaks screen builds itself from the catalog, so there is no separate UI to wire.
